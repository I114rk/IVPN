import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
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

/// Обёртка над нативным плагином `flutter_sing_box` (Android / Windows).
///
/// Инициализация ленивая и повторяемая: на Android нативный метод `init`
/// требует уже привязанную Activity, поэтому вызов повторяется, пока движок
/// возвращает `NO_ACTIVITY` (т.е. пока не отрисован первый кадр).
class AndroidVpnEngine {
  AndroidVpnEngine(this._logs);

  final LogService _logs;
  final FlutterSingBox _client = FlutterSingBox();

  static const int _initAttempts = 15;
  static const Duration _initRetryDelay = Duration(milliseconds: 400);

  bool _initialized = false;
  Future<void>? _initializing;
  StreamSubscription<ProxyState>? _stateSubscription;
  StreamSubscription<ClientStatus>? _statusSubscription;
  StreamSubscription<List<ClientLog>>? _logSubscription;
  Completer<void>? _startCompleter;

  AndroidVpnStateCallback? onStateChanged;
  AndroidVpnStatusCallback? onStatus;
  AndroidVpnLogCallback? onLog;

  static bool get isSupported => Platform.isAndroid || Platform.isWindows;

  Future<void> init() {
    if (!isSupported || _initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      Object? lastError;
      for (var attempt = 0; attempt < _initAttempts; attempt++) {
        try {
          await _client.init();
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          if (!_isNoActivity(error)) rethrow;
          await Future<void>.delayed(_initRetryDelay);
        }
      }
      if (lastError != null) {
        throw AndroidVpnException(
          'Плагин VPN не смог подключиться к приложению: ${_describe(lastError)}',
        );
      }
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
    } catch (error) {
      _initializing = null;
      if (error is AndroidVpnException) rethrow;
      throw AndroidVpnException(_describe(error));
    }
  }

  Future<void> start({
    required Map<String, dynamic> config,
    required String name,
  }) async {
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

    await init();

    if (Platform.isWindows) {
      final installed = await _client.installService(
        serviceName: 'clash_sing_service',
        displayName: 'IVPN VPN Service',
        description: 'IVPN secure tunnel service',
      );
      if (!installed) {
        throw const AndroidVpnException(
          'Не удалось установить службу IVPN. Разрешите запрос Windows для запуска TUN.',
        );
      }
    }

    final completer = Completer<void>();
    _startCompleter = completer;
    try {
      await _client.startVpn();
    } catch (error) {
      _startCompleter = null;
      throw AndroidVpnException(_describe(error));
    }

    // Статус может прийти раньше, чем завершится startVpn, —
    // проверяем completer ещё раз, чтобы не ждать таймаута впустую.
    if (completer.isCompleted) return completer.future;
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _startCompleter = null;
        throw const AndroidVpnException(
          'VPN не запустился за 30 секунд. Проверьте журнал ядра.',
        );
      },
    );
  }

  Future<void> stop() async {
    if (!isSupported) return;
    try {
      await init();
      await _client.stopVpn();
    } catch (error) {
      _logs.warn('conn', 'Не удалось остановить VPN: ${_describe(error)}');
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

  static bool _isNoActivity(Object error) {
    if (error is PlatformException) return error.code == 'NO_ACTIVITY';
    return error.toString().contains('NO_ACTIVITY');
  }

  static String _describe(Object error) {
    if (error is PlatformException) {
      return error.message?.isNotEmpty == true
          ? error.message!
          : '${error.code}: ${error.details ?? ''}';
    }
    return error.toString();
  }
}
