import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:path/path.dart' as p;

import '../services/log_service.dart';

typedef AndroidVpnStateCallback = void Function(ProxyState state);
typedef AndroidVpnStatusCallback = void Function(ClientStatus status);
typedef AndroidVpnLogCallback = void Function(String message, int level);

class AndroidVpnException implements Exception {
  final String message;

  const AndroidVpnException(this.message);

  @override
  String toString() => message;
}

class AndroidVpnEngine {
  AndroidVpnEngine(this._logs);

  final LogService _logs;
  final FlutterSingBox _client = FlutterSingBox();

  bool _initialized = false;
  StreamSubscription<ProxyState>? _stateSubscription;
  StreamSubscription<ClientStatus>? _statusSubscription;
  StreamSubscription<List<ClientLog>>? _logSubscription;
  Completer<void>? _startCompleter;

  AndroidVpnStateCallback? onStateChanged;
  AndroidVpnStatusCallback? onStatus;
  AndroidVpnLogCallback? onLog;

  static bool get isSupported => Platform.isAndroid;

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    await _client.init();
    _stateSubscription = _client.proxyStateStream.listen(_handleState);
    _statusSubscription = _client.connectedStatusStream.listen((status) {
      onStatus?.call(status);
    });
    _logSubscription = _client.logStream.listen((entries) {
      for (final entry in entries) {
        onLog?.call(entry.message, entry.level);
      }
    });
    _initialized = true;
  }

  Future<void> start({
    required Map<String, dynamic> config,
    required String name,
  }) async {
    await init();
    final directory = await ProfileStorage.instance.getStorageDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'using_config.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );

    final profile = Profile(
      id: 1,
      order: 0,
      name: name,
      outboundsCount: 1,
      typed: TypedProfile(
        type: ProfileType.local,
        path: file.path,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        subscribeUrl: file.uri.toString(),
      ),
    );
    final storage = ProfileStorage.storage;
    storage.setString('profile_1', jsonEncode(profile.toJson()));
    storage.setInt('max_id', 1);
    ProfileStorage.instance.setSelectedProfile(1);
    ProfileStorage.instance.setUsingConfig(directory.path);

    final completer = Completer<void>();
    _startCompleter = completer;
    try {
      await _client.startVpn();
    } catch (error) {
      _startCompleter = null;
      throw AndroidVpnException(error.toString());
    }
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw const AndroidVpnException('VPN не запустился за 20 секунд');
      },
    );
  }

  Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _client.stopVpn();
    } catch (error) {
      _logs.warn('conn', 'Не удалось остановить VPN: $error');
    }
  }

  Future<String?> version() async {
    try {
      return await _client.getSingBoxVersion();
    } catch (_) {
      return null;
    }
  }

  void _handleState(ProxyState state) {
    if (state is ProxyStarted) {
      final completer = _startCompleter;
      _startCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    } else if (state is ProxyStopped) {
      final completer = _startCompleter;
      _startCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          AndroidVpnException(state.errMessage ?? 'VPN остановлен'),
        );
      }
    }
    onStateChanged?.call(state);
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _logSubscription?.cancel();
  }
}
