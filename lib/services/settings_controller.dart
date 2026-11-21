import 'package:flutter/foundation.dart';

import '../core/models/app_settings.dart';
import '../platform/device_info.dart';
import 'state_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store, this._device);

  final StateStore _store;
  final DeviceInfoService _device;

  AppSettings _value = const AppSettings();
  int? _accentSeed;

  AppSettings get value => _value;

  int get effectiveSeedColor {
    final raw = _value.seedColor ?? _accentSeed ?? 0xFF6750A4;
    return 0xFF000000 | (raw & 0x00FFFFFF);
  }

  Future<void> init() async {
    _value = _store.settings;
    if (_value.dynamicColor) {
      _accentSeed = await _device.accentColor();
    }
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _value = next;
    if (next.dynamicColor) {
      _accentSeed = await _device.accentColor();
    }
    notifyListeners();
    await _store.saveSettings(next);
  }

  Future<void> patch({
    ConnectionMode? mode,
    CoreEngine? engine,
    int? mixedPort,
    String? tunStack,
    bool? setSystemProxy,
    bool? allowLan,
    bool? autoRefreshSubscriptions,
    ThemePreference? theme,
    AppLanguage? language,
    bool? dynamicColor,
    int? seedColor,
    bool clearSeedColor = false,
    bool? sendHwid,
    UserAgentPreset? userAgentPreset,
    String? customUserAgent,
    String? emulatedClientId,
    bool clearEmulation = false,
    String? openvpnPath,
    String? selectedProfileId,
    bool clearSelectedProfile = false,
    bool? autoConnect,
  }) {
    return update(
      _value.copyWith(
        mode: mode,
        engine: engine,
        mixedPort: mixedPort,
        tunStack: tunStack,
        setSystemProxy: setSystemProxy,
        allowLan: allowLan,
        autoRefreshSubscriptions: autoRefreshSubscriptions,
        theme: theme,
        language: language,
        dynamicColor: dynamicColor,
        seedColor: seedColor,
        clearSeedColor: clearSeedColor,
        sendHwid: sendHwid,
        userAgentPreset: userAgentPreset,
        customUserAgent: customUserAgent,
        emulatedClientId: emulatedClientId,
        clearEmulation: clearEmulation,
        openvpnPath: openvpnPath,
        selectedProfileId: selectedProfileId,
        clearSelectedProfile: clearSelectedProfile,
        autoConnect: autoConnect,
      ),
    );
  }
}
