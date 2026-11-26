import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart' as singbox_plugin;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/config/openvpn_config_builder.dart';
import '../core/config/singbox_config_builder.dart';
import '../core/config/xray_config_builder.dart';
import '../core/models/app_settings.dart';
import '../core/models/engine.dart';
import '../core/models/lan_client.dart';
import '../core/models/proxy_profile.dart';
import '../platform/android_vpn.dart';
import '../platform/elevation.dart';
import '../platform/system_proxy.dart';
import 'core_manager.dart';
import 'engine_manager.dart';
import 'log_service.dart';
import 'settings_controller.dart';
import 'storage_service.dart';
import 'subscription_controller.dart';

class ConnectionException implements Exception {
  final String message;
  final bool needsElevation;

  const ConnectionException(this.message, {this.needsElevation = false});

  @override
  String toString() => message;
}

class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required CoreManager cores,
    required EngineManager engine,
    required StorageService storage,
    required LogService logs,
    required SettingsController settings,
    required SubscriptionController subscriptions,
    required SystemProxyService proxy,
    AndroidVpnEngine? androidVpn,
  }) : _cores = cores,
       _engine = engine,
       _storage = storage,
       _logs = logs,
       _settings = settings,
       _subscriptions = subscriptions,
       _proxy = proxy,
       _android = androidVpn ?? AndroidVpnEngine(logs),
       _engineState = engine.state {
    _engineSubscription = _engine.states.listen(_onEngineState);
    // Windows идёт через свой path (sing-box.exe), плагин — только Android.
    if (_usesVpnPlugin) {
      _android.onStateChanged = _onAndroidState;
      _android.onStatus = _onAndroidStatus;
      _android.onLog = _onAndroidLog;
    }
  }

  final CoreManager _cores;
  final EngineManager _engine;
  final StorageService _storage;
  final LogService _logs;
  final SettingsController _settings;
  final SubscriptionController _subscriptions;
  final SystemProxyService _proxy;
  final AndroidVpnEngine _android;
  final http.Client _http = http.Client();

  late final StreamSubscription<EngineState> _engineSubscription;
  EngineState _engineState;

  ProxyProfile? _activeProfile;
  DateTime? _connectedAt;
  int _upload = 0;
  int _download = 0;
  bool _connecting = false;
  String? _lastError;
  bool _needsElevation = false;
  Timer? _trafficTimer;
  final Map<String, LanClient> _lanClients = {};

  EngineState get engineState => _engineState;
  ProxyProfile? get activeProfile => _activeProfile;
  bool get isConnecting => _connecting;
  bool get isConnected => _activeProfile != null && _engineState.isRunning;
  bool get isBusy => _connecting || _engineState.isBusy;
  int get upload => _upload;
  int get download => _download;
  String? get lastError => _lastError;
  bool get needsElevation => _needsElevation;

  /// Плагин `flutter_sing_box` используется только на Android.
  static bool get _usesVpnPlugin => Platform.isAndroid;

  List<LanClient> get lanClients {
    final clients = _lanClients.values.toList();
    clients.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    return clients;
  }

  Duration get sessionDuration => _connectedAt == null
      ? Duration.zero
      : DateTime.now().difference(_connectedAt!);

  ProxyProfile? get selectedProfile =>
      _subscriptions.profileById(_settings.value.selectedProfileId);

  Future<void> autoConnect() async {
    if (!_settings.value.autoConnect) return;
    final profile = selectedProfile;
    if (profile == null || isConnected) return;
    try {
      await connect(profile);
    } catch (error) {
      _logs.warn('conn', 'Автоподключение не удалось: $error');
    }
  }

  Future<void> toggle(ProxyProfile? profile) async {
    if (isConnected || _connecting) {
      await disconnect();
    } else if (profile != null) {
      await connect(profile);
    }
  }

  Future<void> connect(ProxyProfile profile) async {
    if (_engineState.isBusy || _connecting) {
      throw const ConnectionException(
        'Ядро уже запускается или останавливается',
      );
    }

    if (_usesVpnPlugin) {
      await _connectAndroid(profile);
      return;
    }

    final settings = _settings.value;
    var engineType = settings.engine;
    if (profile.protocol == ProxyProtocol.openvpn) {
      engineType = CoreEngine.openvpn;
    }
    if (engineType == CoreEngine.xray && !XrayConfigBuilder.supports(profile)) {
      engineType = CoreEngine.singbox;
    }
    if (engineType == CoreEngine.openvpn &&
        profile.protocol != ProxyProtocol.openvpn) {
      engineType = CoreEngine.singbox;
    }
    if (engineType == CoreEngine.xray && settings.mode == ConnectionMode.tun) {
      throw const ConnectionException(
        'Ядро Xray работает только в режиме Proxy. Переключите режим подключения.',
      );
    }
    if (engineType != CoreEngine.openvpn &&
        settings.mode == ConnectionMode.tun &&
        !ElevationService.isAdmin()) {
      throw const ConnectionException(
        'TUN-режим требует прав администратора. Перезапустите IVPN с повышенными правами.',
        needsElevation: true,
      );
    }

    final workingDirectory = _storage.configsDir.path;
    String executable;
    List<String> arguments;

    switch (engineType) {
      case CoreEngine.singbox:
        if (!_cores.hasSingbox) {
          throw const ConnectionException(
            'Ядро sing-box не установлено. Откройте Настройки → Ядра.',
          );
        }
        if (settings.mode == ConnectionMode.tun && !_cores.hasWintun) {
          throw const ConnectionException(
            'Для TUN-режима нужен wintun.dll. Установите его в Настройках → Ядра.',
          );
        }
        final config = SingboxConfigBuilder.build(
          profile: profile,
          settings: settings,
        );
        final file = File(p.join(workingDirectory, 'singbox.json'));
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(config),
        );
        executable = _cores.singboxPath;
        arguments = ['run', '-c', file.path];
        break;
      case CoreEngine.xray:
        if (!_cores.hasXray) {
          throw const ConnectionException(
            'Ядро Xray не установлено. Откройте Настройки → Ядра.',
          );
        }
        final config = XrayConfigBuilder.build(
          profile: profile,
          settings: settings,
        );
        final file = File(p.join(workingDirectory, 'xray.json'));
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(config),
        );
        executable = _cores.xrayPath;
        arguments = ['run', '-c', file.path];
        break;
      case CoreEngine.openvpn:
        if (!ElevationService.isAdmin()) {
          throw const ConnectionException(
            'OpenVPN требует прав администратора.',
            needsElevation: true,
          );
        }
        final openvpn = await _cores.findOpenVpn(settings.openvpnPath);
        if (openvpn == null) {
          throw const ConnectionException(
            'OpenVPN не найден. Укажите путь к openvpn.exe в настройках.',
          );
        }
        final content = OpenVpnConfigBuilder.build(profile);
        if (content.trim().isEmpty) {
          throw const ConnectionException(
            'Не удалось собрать конфигурацию OpenVPN',
          );
        }
        final file = File(p.join(workingDirectory, 'client.ovpn'));
        await file.writeAsString(content);
        executable = openvpn;
        arguments = ['--config', file.path, '--verb', '3'];
        break;
    }

    _connecting = true;
    _lastError = null;
    _needsElevation = false;
    _upload = 0;
    _download = 0;
    _connectedAt = null;
    _activeProfile = profile;
    _lanClients.clear();
    notifyListeners();

    try {
      final type = switch (engineType) {
        CoreEngine.singbox => EngineType.singbox,
        CoreEngine.xray => EngineType.xray,
        CoreEngine.openvpn => EngineType.openvpn,
      };
      await _engine.start(
        type: type,
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      );
      if (!_engine.state.isRunning) {
        throw ConnectionException(
          _engine.state.message ?? 'Ядро не запустилось',
        );
      }

      if (engineType != CoreEngine.openvpn &&
          settings.mode == ConnectionMode.proxy &&
          settings.setSystemProxy) {
        final port = engineType == CoreEngine.xray
            ? settings.mixedPort + 1
            : settings.mixedPort;
        await _proxy.enable('127.0.0.1', port);
      }

      _connectedAt = DateTime.now();
      _startTrafficPolling(engineType);
      _logs.info(
        'conn',
        'Подключено: ${profile.name} · ${profile.endpoint} · ${engineType.label}',
      );
    } catch (error) {
      _lastError = error.toString();
      if (error is ConnectionException) _needsElevation = error.needsElevation;
      await _safeCleanup();
      _activeProfile = null;
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    if (_usesVpnPlugin) {
      await _android.stop();
    } else {
      try {
        await _proxy.disable();
      } catch (_) {}
      await _engine.stop();
    }
    if (_activeProfile != null) {
      _logs.info('conn', 'Отключено');
    }
    _activeProfile = null;
    _connectedAt = null;
    _upload = 0;
    _download = 0;
    _lanClients.clear();
    notifyListeners();
  }

  Future<void> _connectAndroid(ProxyProfile profile) async {
    if (profile.protocol == ProxyProtocol.openvpn ||
        profile.protocol == ProxyProtocol.unknown) {
      throw const ConnectionException(
        'Этот протокол не поддерживается на Android. '
        'Выберите VLESS, VMess, Trojan или Shadowsocks.',
      );
    }

    final settings = _settings.value;
    final config = SingboxConfigBuilder.build(
      profile: profile,
      settings: settings,
      android: true,
    );

    _connecting = true;
    _lastError = null;
    _needsElevation = false;
    _upload = 0;
    _download = 0;
    _connectedAt = null;
    _activeProfile = profile;
    _lanClients.clear();
    notifyListeners();

    try {
      await _android.start(config: config, name: profile.name);
      _connectedAt = DateTime.now();
      _logs.info(
        'conn',
        'Подключено: ${profile.name} · ${profile.endpoint} · sing-box',
      );
    } catch (error) {
      _lastError = error.toString();
      await _safeCleanup();
      _activeProfile = null;
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  void _onAndroidState(singbox_plugin.ProxyState state) {
    if (state is singbox_plugin.ProxyStarting) {
      _engineState = const EngineState(
        type: EngineType.singbox,
        status: EngineStatus.starting,
      );
    } else if (state is singbox_plugin.ProxyStarted) {
      _engineState = EngineState(
        type: EngineType.singbox,
        status: EngineStatus.running,
        startedAt: DateTime.now(),
      );
    } else if (state is singbox_plugin.ProxyStopping) {
      _engineState = const EngineState(
        type: EngineType.singbox,
        status: EngineStatus.stopping,
      );
    } else if (state is singbox_plugin.ProxyStopped) {
      final error = state.errMessage;
      _engineState = EngineState(
        type: EngineType.singbox,
        status: error == null ? EngineStatus.stopped : EngineStatus.error,
        message: error,
      );
      _activeProfile = null;
      _connectedAt = null;
      _upload = 0;
      _download = 0;
      _lanClients.clear();
      if (error != null) _lastError = error;
    }
    notifyListeners();
  }

  void _onAndroidStatus(singbox_plugin.ClientStatus status) {
    _upload = status.uplinkTotal;
    _download = status.downlinkTotal;
    notifyListeners();
  }

  void _onAndroidLog(String message, int level) {
    if (level <= 2) {
      _logs.error('core', message);
    } else if (level == 3) {
      _logs.warn('core', message);
    } else {
      _logs.info('core', message);
    }
  }

  void _onEngineState(EngineState state) {
    _engineState = state;
    if (state.status == EngineStatus.error) {
      _lastError = state.message;
      _activeProfile = null;
      _connectedAt = null;
      _lanClients.clear();
      _trafficTimer?.cancel();
      _trafficTimer = null;
      unawaited(_proxy.disable());
    }
    notifyListeners();
  }

  Future<void> _safeCleanup() async {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    _lanClients.clear();
    if (_usesVpnPlugin) {
      await _android.stop();
      return;
    }
    try {
      await _proxy.disable();
    } catch (_) {}
    try {
      await _engine.stop(silent: true);
    } catch (_) {}
  }

  void _startTrafficPolling(CoreEngine engineType) {
    _trafficTimer?.cancel();
    if (engineType != CoreEngine.singbox) return;
    _trafficTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final response = await _http
            .get(
              Uri.parse(
                'http://127.0.0.1:${SingboxConfigBuilder.clashApiPort}/connections',
              ),
            )
            .timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) return;
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final down = (decoded['downloadTotal'] as num?)?.toInt();
          final up = (decoded['uploadTotal'] as num?)?.toInt();
          if (down != null) _download = down;
          if (up != null) _upload = up;
          final connections = decoded['connections'];
          if (connections is List) _updateLanClients(connections);
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  static bool _isLoopback(String ip) =>
      ip == '::1' || ip == 'localhost' || ip.startsWith('127.');

  void _updateLanClients(List<dynamic> connections) {
    final now = DateTime.now();
    final aggregates = <String, _LanAggregate>{};

    for (final item in connections) {
      if (item is! Map) continue;
      final metadata = item['metadata'];
      if (metadata is! Map) continue;
      final source = (metadata['sourceIP'] ?? '').toString();
      if (source.isEmpty || _isLoopback(source)) continue;

      final aggregate = aggregates.putIfAbsent(source, _LanAggregate.new);
      aggregate.activeConnections += 1;
      aggregate.upload += (item['upload'] as num?)?.toInt() ?? 0;
      aggregate.download += (item['download'] as num?)?.toInt() ?? 0;

      final host =
          (metadata['host'] ??
                  metadata['sniffHost'] ??
                  metadata['destinationIP'] ??
                  '')
              .toString();
      if (host.isNotEmpty && !aggregate.hosts.contains(host)) {
        aggregate.hosts.add(host);
      }
    }

    for (final entry in aggregates.entries) {
      _lanClients[entry.key] = LanClient(
        ip: entry.key,
        activeConnections: entry.value.activeConnections,
        upload: entry.value.upload,
        download: entry.value.download,
        lastSeen: now,
        hosts: entry.value.hosts.take(6).toList(),
      );
    }

    final expired = <String>[];
    for (final entry in _lanClients.entries.toList()) {
      if (aggregates.containsKey(entry.key)) continue;
      if (now.difference(entry.value.lastSeen) > const Duration(minutes: 2)) {
        expired.add(entry.key);
      } else if (entry.value.activeConnections != 0) {
        _lanClients[entry.key] = entry.value.copyWith(activeConnections: 0);
      }
    }
    for (final ip in expired) {
      _lanClients.remove(ip);
    }
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    _engineSubscription.cancel();
    unawaited(_android.dispose());
    _http.close();
    super.dispose();
  }
}

class _LanAggregate {
  int activeConnections = 0;
  int upload = 0;
  int download = 0;
  final List<String> hosts = [];
}
