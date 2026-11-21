import 'client_emulation.dart';

enum ConnectionMode { tun, proxy }

enum CoreEngine { singbox, xray, openvpn }

enum ThemePreference { system, light, dark }

enum AppLanguage { system, ru, en, de }

enum UserAgentPreset { singbox, xray, base64, custom }

extension ConnectionModeX on ConnectionMode {
  String get label => this == ConnectionMode.tun ? 'TUN' : 'Proxy';
}

extension CoreEngineX on CoreEngine {
  String get label => switch (this) {
    CoreEngine.singbox => 'Sing-box',
    CoreEngine.xray => 'Xray',
    CoreEngine.openvpn => 'OpenVPN',
  };
}

extension ThemePreferenceX on ThemePreference {
  String get label => switch (this) {
    ThemePreference.system => 'Системная',
    ThemePreference.light => 'Светлая',
    ThemePreference.dark => 'Тёмная',
  };
}

extension UserAgentPresetX on UserAgentPreset {
  String get label => switch (this) {
    UserAgentPreset.singbox => 'Sing-box JSON',
    UserAgentPreset.xray => 'Xray JSON (Happ)',
    UserAgentPreset.base64 => 'Base64 / авто',
    UserAgentPreset.custom => 'Свой',
  };

  String get userAgent => switch (this) {
    UserAgentPreset.singbox => 'sing-box/1.12.0 (singbox; IVPN)',
    UserAgentPreset.xray => 'Happ/1.0 (IVPN; v2rayN)',
    UserAgentPreset.base64 => 'IVPN/1.0',
    UserAgentPreset.custom => 'IVPN/1.0',
  };
}

class AppSettings {
  final ConnectionMode mode;
  final CoreEngine engine;
  final int mixedPort;
  final String tunStack;
  final bool setSystemProxy;
  final bool allowLan;
  final bool autoRefreshSubscriptions;
  final ThemePreference theme;
  final AppLanguage language;
  final bool dynamicColor;
  final int? seedColor;
  final bool sendHwid;
  final UserAgentPreset userAgentPreset;
  final String? customUserAgent;
  final String? emulatedClientId;
  final String? openvpnPath;
  final String? selectedProfileId;
  final bool autoConnect;
  final bool launchAtStartup;

  const AppSettings({
    this.mode = ConnectionMode.tun,
    this.engine = CoreEngine.singbox,
    this.mixedPort = 2080,
    this.tunStack = 'system',
    this.setSystemProxy = true,
    this.allowLan = false,
    this.autoRefreshSubscriptions = true,
    this.theme = ThemePreference.system,
    this.language = AppLanguage.system,
    this.dynamicColor = true,
    this.seedColor,
    this.sendHwid = true,
    this.userAgentPreset = UserAgentPreset.singbox,
    this.customUserAgent,
    this.emulatedClientId,
    this.openvpnPath,
    this.selectedProfileId,
    this.autoConnect = false,
    this.launchAtStartup = false,
  });

  ClientEmulation? get emulation => ClientEmulation.byId(emulatedClientId);

  String get effectiveUserAgent {
    final emulated = emulation;
    if (emulated != null) return emulated.userAgent;
    if (userAgentPreset == UserAgentPreset.custom &&
        (customUserAgent ?? '').trim().isNotEmpty) {
      return customUserAgent!.trim();
    }
    return userAgentPreset.userAgent;
  }

  AppSettings copyWith({
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
    bool? launchAtStartup,
  }) {
    return AppSettings(
      mode: mode ?? this.mode,
      engine: engine ?? this.engine,
      mixedPort: mixedPort ?? this.mixedPort,
      tunStack: tunStack ?? this.tunStack,
      setSystemProxy: setSystemProxy ?? this.setSystemProxy,
      allowLan: allowLan ?? this.allowLan,
      autoRefreshSubscriptions:
          autoRefreshSubscriptions ?? this.autoRefreshSubscriptions,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      seedColor: clearSeedColor ? null : (seedColor ?? this.seedColor),
      sendHwid: sendHwid ?? this.sendHwid,
      userAgentPreset: userAgentPreset ?? this.userAgentPreset,
      customUserAgent: customUserAgent ?? this.customUserAgent,
      emulatedClientId: clearEmulation
          ? null
          : (emulatedClientId ?? this.emulatedClientId),
      openvpnPath: openvpnPath ?? this.openvpnPath,
      selectedProfileId: clearSelectedProfile
          ? null
          : (selectedProfileId ?? this.selectedProfileId),
      autoConnect: autoConnect ?? this.autoConnect,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'engine': engine.name,
    'mixedPort': mixedPort,
    'tunStack': tunStack,
    'setSystemProxy': setSystemProxy,
    'allowLan': allowLan,
    'autoRefreshSubscriptions': autoRefreshSubscriptions,
    'theme': theme.name,
    'language': language.name,
    'dynamicColor': dynamicColor,
    'seedColor': seedColor,
    'sendHwid': sendHwid,
    'userAgentPreset': userAgentPreset.name,
    'customUserAgent': customUserAgent,
    'emulatedClientId': emulatedClientId,
    'openvpnPath': openvpnPath,
    'selectedProfileId': selectedProfileId,
    'autoConnect': autoConnect,
    'launchAtStartup': launchAtStartup,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw == null) return fallback;
      final name = raw.toString();
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    return AppSettings(
      mode: enumValue(ConnectionMode.values, json['mode'], ConnectionMode.tun),
      engine: enumValue(CoreEngine.values, json['engine'], CoreEngine.singbox),
      mixedPort: (json['mixedPort'] as num?)?.toInt() ?? 2080,
      tunStack: json['tunStack']?.toString() ?? 'system',
      setSystemProxy: json['setSystemProxy'] != false,
      allowLan: json['allowLan'] == true,
      autoRefreshSubscriptions: json['autoRefreshSubscriptions'] != false,
      theme: enumValue(
        ThemePreference.values,
        json['theme'],
        ThemePreference.system,
      ),
      language: enumValue(
        AppLanguage.values,
        json['language'],
        AppLanguage.system,
      ),
      dynamicColor: json['dynamicColor'] != false,
      seedColor: (json['seedColor'] as num?)?.toInt(),
      sendHwid: json['sendHwid'] != false,
      userAgentPreset: enumValue(
        UserAgentPreset.values,
        json['userAgentPreset'],
        UserAgentPreset.singbox,
      ),
      customUserAgent: json['customUserAgent']?.toString(),
      emulatedClientId: json['emulatedClientId']?.toString(),
      openvpnPath: json['openvpnPath']?.toString(),
      selectedProfileId: json['selectedProfileId']?.toString(),
      autoConnect: json['autoConnect'] == true,
      launchAtStartup: json['launchAtStartup'] == true,
    );
  }
}
