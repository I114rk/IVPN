import '../utils/ids.dart';

enum ProxyProtocol {
  vless,
  vmess,
  trojan,
  shadowsocks,
  hysteria2,
  tuic,
  wireguard,
  socks,
  http,
  ssh,
  openvpn,
  unknown,
}

enum ProxyTransport { tcp, ws, grpc, http, httpUpgrade, quic, kcp }

extension ProxyProtocolX on ProxyProtocol {
  String get label => switch (this) {
    ProxyProtocol.vless => 'VLESS',
    ProxyProtocol.vmess => 'VMess',
    ProxyProtocol.trojan => 'Trojan',
    ProxyProtocol.shadowsocks => 'Shadowsocks',
    ProxyProtocol.hysteria2 => 'Hysteria2',
    ProxyProtocol.tuic => 'TUIC',
    ProxyProtocol.wireguard => 'WireGuard',
    ProxyProtocol.socks => 'SOCKS',
    ProxyProtocol.http => 'HTTP',
    ProxyProtocol.ssh => 'SSH',
    ProxyProtocol.openvpn => 'OpenVPN',
    ProxyProtocol.unknown => 'Unknown',
  };

  String get shortLabel => switch (this) {
    ProxyProtocol.vless => 'VLESS',
    ProxyProtocol.vmess => 'VMess',
    ProxyProtocol.trojan => 'Trojan',
    ProxyProtocol.shadowsocks => 'SS',
    ProxyProtocol.hysteria2 => 'HY2',
    ProxyProtocol.tuic => 'TUIC',
    ProxyProtocol.wireguard => 'WG',
    ProxyProtocol.socks => 'SOCKS',
    ProxyProtocol.http => 'HTTP',
    ProxyProtocol.ssh => 'SSH',
    ProxyProtocol.openvpn => 'OVPN',
    ProxyProtocol.unknown => '?',
  };
}

extension ProxyTransportX on ProxyTransport {
  String get key => switch (this) {
    ProxyTransport.tcp => 'tcp',
    ProxyTransport.ws => 'ws',
    ProxyTransport.grpc => 'grpc',
    ProxyTransport.http => 'http',
    ProxyTransport.httpUpgrade => 'httpupgrade',
    ProxyTransport.quic => 'quic',
    ProxyTransport.kcp => 'kcp',
  };
}

ProxyProtocol proxyProtocolFromKey(String? key) {
  switch ((key ?? '').toLowerCase()) {
    case 'vless':
      return ProxyProtocol.vless;
    case 'vmess':
      return ProxyProtocol.vmess;
    case 'trojan':
      return ProxyProtocol.trojan;
    case 'ss':
    case 'shadowsocks':
      return ProxyProtocol.shadowsocks;
    case 'hysteria2':
    case 'hy2':
      return ProxyProtocol.hysteria2;
    case 'tuic':
      return ProxyProtocol.tuic;
    case 'wireguard':
    case 'wg':
      return ProxyProtocol.wireguard;
    case 'socks':
    case 'socks5':
      return ProxyProtocol.socks;
    case 'http':
    case 'https':
      return ProxyProtocol.http;
    case 'ssh':
      return ProxyProtocol.ssh;
    case 'openvpn':
    case 'ovpn':
      return ProxyProtocol.openvpn;
    default:
      return ProxyProtocol.unknown;
  }
}

ProxyTransport proxyTransportFromKey(String? key) {
  switch ((key ?? '').toLowerCase()) {
    case 'ws':
    case 'websocket':
      return ProxyTransport.ws;
    case 'grpc':
      return ProxyTransport.grpc;
    case 'http':
    case 'h2':
      return ProxyTransport.http;
    case 'httpupgrade':
    case 'http-upgrade':
      return ProxyTransport.httpUpgrade;
    case 'quic':
      return ProxyTransport.quic;
    case 'kcp':
    case 'mkcp':
      return ProxyTransport.kcp;
    default:
      return ProxyTransport.tcp;
  }
}

class ProxyProfile {
  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String server;
  final int port;

  final String? uuid;
  final String? password;
  final String? method;
  final int alterId;
  final String? flow;

  final ProxyTransport transport;
  final String? path;
  final String? host;
  final String? sni;
  final String? alpn;
  final String? fingerprint;

  final bool tls;
  final bool reality;
  final String? realityPublicKey;
  final String? realityShortId;
  final bool allowInsecure;

  final String? plugin;
  final String? pluginOpts;

  final String? subscriptionId;
  final String? subscriptionName;

  /// Raw engine data (native sing-box outbound, xray outbound, ovpn body...).
  final Map<String, dynamic> extra;

  const ProxyProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    this.uuid,
    this.password,
    this.method,
    this.alterId = 0,
    this.flow,
    this.transport = ProxyTransport.tcp,
    this.path,
    this.host,
    this.sni,
    this.alpn,
    this.fingerprint,
    this.tls = false,
    this.reality = false,
    this.realityPublicKey,
    this.realityShortId,
    this.allowInsecure = false,
    this.plugin,
    this.pluginOpts,
    this.subscriptionId,
    this.subscriptionName,
    this.extra = const {},
  });

  String get endpoint => '$server:$port';

  String? get countryCode {
    const firstRegionalIndicator = 0x1F1E6;
    const lastRegionalIndicator = 0x1F1FF;
    final codePoints = name.runes.toList();
    String? result;
    for (var index = 0; index + 1 < codePoints.length; index++) {
      final first = codePoints[index];
      final second = codePoints[index + 1];
      if (first < firstRegionalIndicator ||
          first > lastRegionalIndicator ||
          second < firstRegionalIndicator ||
          second > lastRegionalIndicator) {
        continue;
      }
      result = String.fromCharCodes([
        0x41 + first - firstRegionalIndicator,
        0x41 + second - firstRegionalIndicator,
      ]);
      index++;
    }
    return result;
  }

  String get displayName {
    const firstRegionalIndicator = 0x1F1E6;
    const lastRegionalIndicator = 0x1F1FF;
    final codePoints = name.runes.toList();
    final output = StringBuffer();
    for (var index = 0; index < codePoints.length; index++) {
      final first = codePoints[index];
      final hasFlag =
          index + 1 < codePoints.length &&
          first >= firstRegionalIndicator &&
          first <= lastRegionalIndicator &&
          codePoints[index + 1] >= firstRegionalIndicator &&
          codePoints[index + 1] <= lastRegionalIndicator;
      if (hasFlag) {
        index++;
        continue;
      }
      output.writeCharCode(first);
    }
    final cleaned = output.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? name : cleaned;
  }

  List<String> get alpnList => (alpn ?? '')
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  String get securityLabel {
    if (reality) return 'Reality';
    if (tls) return 'TLS';
    return 'None';
  }

  bool get supportsXray => switch (protocol) {
    ProxyProtocol.vless ||
    ProxyProtocol.vmess ||
    ProxyProtocol.trojan ||
    ProxyProtocol.shadowsocks ||
    ProxyProtocol.socks ||
    ProxyProtocol.http => true,
    _ => false,
  };

  ProxyProfile copyWith({
    String? id,
    String? name,
    ProxyProtocol? protocol,
    String? server,
    int? port,
    String? uuid,
    String? password,
    String? method,
    int? alterId,
    String? flow,
    ProxyTransport? transport,
    String? path,
    String? host,
    String? sni,
    String? alpn,
    String? fingerprint,
    bool? tls,
    bool? reality,
    String? realityPublicKey,
    String? realityShortId,
    bool? allowInsecure,
    String? plugin,
    String? pluginOpts,
    String? subscriptionId,
    String? subscriptionName,
    Map<String, dynamic>? extra,
  }) {
    return ProxyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      password: password ?? this.password,
      method: method ?? this.method,
      alterId: alterId ?? this.alterId,
      flow: flow ?? this.flow,
      transport: transport ?? this.transport,
      path: path ?? this.path,
      host: host ?? this.host,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      fingerprint: fingerprint ?? this.fingerprint,
      tls: tls ?? this.tls,
      reality: reality ?? this.reality,
      realityPublicKey: realityPublicKey ?? this.realityPublicKey,
      realityShortId: realityShortId ?? this.realityShortId,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      plugin: plugin ?? this.plugin,
      pluginOpts: pluginOpts ?? this.pluginOpts,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      subscriptionName: subscriptionName ?? this.subscriptionName,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'server': server,
    'port': port,
    'uuid': uuid,
    'password': password,
    'method': method,
    'alterId': alterId,
    'flow': flow,
    'transport': transport.name,
    'path': path,
    'host': host,
    'sni': sni,
    'alpn': alpn,
    'fingerprint': fingerprint,
    'tls': tls,
    'reality': reality,
    'realityPublicKey': realityPublicKey,
    'realityShortId': realityShortId,
    'allowInsecure': allowInsecure,
    'plugin': plugin,
    'pluginOpts': pluginOpts,
    'subscriptionId': subscriptionId,
    'subscriptionName': subscriptionName,
    'extra': extra,
  };

  factory ProxyProfile.fromJson(Map<String, dynamic> json) {
    return ProxyProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed',
      protocol: proxyProtocolFromKey(json['protocol']?.toString()),
      server: json['server']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      uuid: json['uuid']?.toString(),
      password: json['password']?.toString(),
      method: json['method']?.toString(),
      alterId: (json['alterId'] as num?)?.toInt() ?? 0,
      flow: json['flow']?.toString(),
      transport: proxyTransportFromKey(json['transport']?.toString()),
      path: json['path']?.toString(),
      host: json['host']?.toString(),
      sni: json['sni']?.toString(),
      alpn: json['alpn']?.toString(),
      fingerprint: json['fingerprint']?.toString(),
      tls: json['tls'] == true,
      reality: json['reality'] == true,
      realityPublicKey: json['realityPublicKey']?.toString(),
      realityShortId: json['realityShortId']?.toString(),
      allowInsecure: json['allowInsecure'] == true,
      plugin: json['plugin']?.toString(),
      pluginOpts: json['pluginOpts']?.toString(),
      subscriptionId: json['subscriptionId']?.toString(),
      subscriptionName: json['subscriptionName']?.toString(),
      extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  static String buildId({
    required ProxyProtocol protocol,
    required String server,
    required int port,
    String? credential,
    String? name,
  }) {
    return shortHash(
      '${protocol.name}|$server|$port|${credential ?? ''}|${name ?? ''}',
      20,
    );
  }
}
