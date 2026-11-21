import '../models/proxy_profile.dart';

class XrayParser {
  static const _supported = {'vless', 'vmess', 'trojan', 'shadowsocks'};

  static List<ProxyProfile> parse(
    dynamic decoded, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final configs = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) configs.add(item.cast<String, dynamic>());
      }
    } else if (decoded is Map) {
      configs.add(decoded.cast<String, dynamic>());
    }

    final profiles = <ProxyProfile>[];
    for (final config in configs) {
      profiles.addAll(
        parseConfig(
          config,
          subscriptionId: subscriptionId,
          subscriptionName: subscriptionName,
        ),
      );
    }
    return profiles;
  }

  static List<ProxyProfile> parseConfig(
    Map<String, dynamic> config, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final remarks = (config['remarks'] ?? config['name'] ?? '').toString();
    final outbounds = (config['outbounds'] as List?) ?? const [];
    final profiles = <ProxyProfile>[];

    for (final item in outbounds) {
      if (item is! Map) continue;
      final outbound = item.cast<String, dynamic>();
      final protocol = (outbound['protocol'] ?? '').toString().toLowerCase();
      if (!_supported.contains(protocol)) continue;
      final tag = (outbound['tag'] ?? '').toString().toLowerCase();
      if (tag == 'direct' || tag == 'block' || tag == 'bypass') continue;

      final profile = _fromOutbound(
        outbound,
        remarks.isNotEmpty ? remarks : tag,
        subscriptionId: subscriptionId,
        subscriptionName: subscriptionName,
      );
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  static ProxyProfile? _fromOutbound(
    Map<String, dynamic> outbound,
    String fallbackName, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final protocolKey = (outbound['protocol'] ?? '').toString().toLowerCase();
    final protocol = proxyProtocolFromKey(protocolKey);
    final settings =
        (outbound['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stream =
        (outbound['streamSettings'] as Map?)?.cast<String, dynamic>() ??
        const {};

    String server = '';
    int port = 0;
    String? uuid;
    String? password;
    String? method;
    int alterId = 0;
    String? flow;

    if (protocol == ProxyProtocol.vless || protocol == ProxyProtocol.vmess) {
      final vnext = (settings['vnext'] as List?) ?? const [];
      if (vnext.isEmpty || vnext.first is! Map) return null;
      final node = (vnext.first as Map).cast<String, dynamic>();
      server = (node['address'] ?? '').toString();
      port = _int(node['port'], 443);
      final users = (node['users'] as List?) ?? const [];
      if (users.isNotEmpty && users.first is Map) {
        final user = (users.first as Map).cast<String, dynamic>();
        uuid = (user['id'] ?? '').toString();
        flow = (user['flow'] ?? '').toString();
        alterId = _int(user['alterId'], 0);
      }
    } else if (protocol == ProxyProtocol.trojan) {
      final servers = (settings['servers'] as List?) ?? const [];
      if (servers.isEmpty || servers.first is! Map) return null;
      final node = (servers.first as Map).cast<String, dynamic>();
      server = (node['address'] ?? '').toString();
      port = _int(node['port'], 443);
      password = (node['password'] ?? '').toString();
    } else if (protocol == ProxyProtocol.shadowsocks) {
      final servers = (settings['servers'] as List?) ?? const [];
      if (servers.isEmpty || servers.first is! Map) return null;
      final node = (servers.first as Map).cast<String, dynamic>();
      server = (node['address'] ?? '').toString();
      port = _int(node['port'], 8388);
      method = (node['method'] ?? '').toString();
      password = (node['password'] ?? '').toString();
    }

    if (server.isEmpty) return null;

    final network = (stream['network'] ?? 'tcp').toString();
    final security = (stream['security'] ?? 'none').toString().toLowerCase();
    final tlsSettings =
        (stream['tlsSettings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final realitySettings =
        (stream['realitySettings'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final wsSettings =
        (stream['wsSettings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final grpcSettings =
        (stream['grpcSettings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final httpSettings =
        (stream['httpSettings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final httpUpgradeSettings =
        (stream['httpupgradeSettings'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final xhttpSettings =
        (stream['xhttpSettings'] as Map?)?.cast<String, dynamic>() ?? const {};

    final isReality = security == 'reality';
    final isTls = security == 'tls' || isReality;
    final sni = isReality
        ? (realitySettings['serverName'] ?? '').toString()
        : (tlsSettings['serverName'] ?? '').toString();
    final fingerprint = isReality
        ? (realitySettings['fingerprint'] ?? '').toString()
        : (tlsSettings['fingerprint'] ?? '').toString();

    String? path;
    String? host;
    switch (network) {
      case 'ws':
        path = (wsSettings['path'] ?? '').toString();
        host = _hostFromHeaders(wsSettings);
        break;
      case 'grpc':
        path = (grpcSettings['serviceName'] ?? '').toString();
        break;
      case 'http':
        path = (httpSettings['path'] ?? '').toString();
        host = _firstString(httpSettings['host']);
        break;
      case 'httpupgrade':
        path = (httpUpgradeSettings['path'] ?? '').toString();
        host = (httpUpgradeSettings['host'] ?? '').toString();
        break;
      case 'xhttp':
        path = (xhttpSettings['path'] ?? '').toString();
        host = (xhttpSettings['host'] ?? '').toString();
        break;
    }

    final name = fallbackName.isEmpty ? '$server:$port' : fallbackName;

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: protocol,
        server: server,
        port: port,
        credential: uuid ?? password,
        name: name,
      ),
      name: name,
      protocol: protocol,
      server: server,
      port: port,
      uuid: (uuid == null || uuid.isEmpty) ? null : uuid,
      password: (password == null || password.isEmpty) ? null : password,
      method: (method == null || method.isEmpty) ? null : method,
      alterId: alterId,
      flow: (flow == null || flow.isEmpty) ? null : flow,
      transport: proxyTransportFromKey(network),
      path: (path == null || path.isEmpty) ? null : path,
      host: (host == null || host.isEmpty) ? null : host,
      sni: sni.isEmpty ? null : sni,
      alpn: _firstString(tlsSettings['alpn']),
      fingerprint: fingerprint.isEmpty ? null : fingerprint,
      tls: isTls,
      reality: isReality,
      realityPublicKey: isReality
          ? (realitySettings['publicKey'] ?? '').toString()
          : null,
      realityShortId: isReality
          ? (realitySettings['shortId'] ?? '').toString()
          : null,
      allowInsecure: tlsSettings['allowInsecure'] == true,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'xray_outbound': outbound, 'xray_stream': stream},
    );
  }

  static int _int(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _firstString(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static String? _hostFromHeaders(Map<String, dynamic> settings) {
    final headers = (settings['headers'] as Map?)?.cast<String, dynamic>();
    if (headers == null) return null;
    final host = headers['Host'] ?? headers['host'];
    return _firstString(host);
  }
}
