import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'app.dart';
import 'core/subscription/subscription_client.dart';
import 'platform/device_info.dart';
import 'platform/system_proxy.dart';
import 'services/connection_controller.dart';
import 'services/core_manager.dart';
import 'services/engine_manager.dart';
import 'services/hwid_service.dart';
import 'services/log_service.dart';
import 'services/settings_controller.dart';
import 'services/state_store.dart';
import 'services/storage_service.dart';
import 'services/subscription_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1160, 760),
    minimumSize: Size(900, 620),
    center: true,
    title: 'IVPN',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final storage = StorageService();
  await storage.init();

  final stateStore = StateStore(storage);
  await stateStore.load();

  final logs = LogService(storage);
  final device = DeviceInfo.create();

  final settings = SettingsController(stateStore, device);
  await settings.init();

  final hwid = HwidService(device);
  final subscriptionClient = SubscriptionClient();
  final subscriptions = SubscriptionController(
    stateStore,
    logs,
    hwid,
    settings,
    subscriptionClient,
  );
  await subscriptions.init();

  final cores = CoreManager(storage, logs);
  final engine = EngineManager(logs);
  final proxy = SystemProxyService();
  final connection = ConnectionController(
    cores: cores,
    engine: engine,
    storage: storage,
    logs: logs,
    settings: settings,
    subscriptions: subscriptions,
    proxy: proxy,
  );

  await proxy.cleanupIfOurs({
    settings.value.mixedPort,
    settings.value.mixedPort + 1,
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<LogService>.value(value: logs),
        Provider<HwidService>.value(value: hwid),
        Provider<CoreManager>.value(value: cores),
        Provider<EngineManager>.value(value: engine),
        Provider<SystemProxyService>.value(value: proxy),
        Provider<SubscriptionClient>.value(value: subscriptionClient),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<SubscriptionController>.value(
          value: subscriptions,
        ),
        ChangeNotifierProvider<ConnectionController>.value(value: connection),
      ],
      child: const IvpnApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (settings.value.autoRefreshSubscriptions) {
      subscriptions.refreshAll();
    }
    connection.autoConnect();
  });
}
