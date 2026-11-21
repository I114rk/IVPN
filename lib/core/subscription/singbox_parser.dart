import '../models/proxy_profile.dart';

class SingboxParser {
  static const _supported = {
    'vless',
    'vmess',
    'trojan',
    'shadowsocks',
    'hysteria2',
    'tuic',
    'wireguard',
    'socks',
    'http',
    'ssh',
  };

  static List<ProxyProfile> parseConfig(
    Map<String, dynamic> config, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final outbounds = (config['outbounds'] as List?) ?? const [];
    final profiles = <ProxyProfile>[];
    for (final item in outbounds) {
      if (item is! Map) continue;
      final outbound = item.cast<String, dynamic>();
      final profile = fromOutbound(
        outbound,
        subscriptionId: subscriptionId,
        subscriptionName: subscriptionName,
      );
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  static ProxyProfile? fromOutbound(
    Map<String, dynamic> outbound, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final type = (outbound['type'] ?? '').toString().toLowerCase();
    if (!_supported.contains(type)) return null;

    final protocol = proxyProtocolFromKey(type);
    final tag = (outbound['tag'] ?? '').toString();
    final server = (outbound['server'] ?? '').toString();

    final tls = (outbound['tls'] as Map?)?.cast<String, dynamic>() ?? const {};
    final transport =
        (outbound['transport'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reality =
        (tls['reality'] as Map?)?.cast<String, dynamic>() ?? const {};
    final utls = (tls['utls'] as Map?)?.cast<String, dynamic>() ?? const {};

    final transportType = (transport['type'] ?? '').toString();
    final transportPath = (transport['path'] ?? transport['service_name'] ?? '')
        .toString();
    final transportHost = _hostValue(transport);

    var profileServer = server;
    var profilePort = _int(outbound['server_port'], 0);
    var privateKey = '';
    var peerPublicKey = '';
    var preSharedKey = '';
    var addresses = <String>[];
    var reserved = <int>[];
    var mtu = 0;

    if (type == 'wireguard') {
      privateKey = (outbound['private_key'] ?? '').toString();
      peerPublicKey = (outbound['peer_public_key'] ?? '').toString();
      preSharedKey = (outbound['pre_shared_key'] ?? '').toString();
      addresses = _stringList(outbound['local_address']);
      reserved = _intList(outbound['reserved']);
      mtu = _int(outbound['mtu'], 0);
      final peers = (outbound['peers'] as List?) ?? const [];
      if (peers.isNotEmpty && peers.first is Map) {
        final peer = (peers.first as Map).cast<String, dynamic>();
        profileServer = (peer['server'] ?? profileServer).toString();
        profilePort = _int(peer['server_port'], profilePort);
        peerPublicKey = (peer['public_key'] ?? peerPublicKey).toString();
        preSharedKey = (peer['pre_shared_key'] ?? preSharedKey).toString();
        final peerReserved = _intList(peer['reserved']);
        if (peerReserved.isNotEmpty) reserved = peerReserved;
      }
    }

    if (profileServer.isEmpty) return null;
    if (profilePort == 0) {
      profilePort = switch (protocol) {
        ProxyProtocol.hysteria2 => 443,
        ProxyProtocol.tuic => 443,
        ProxyProtocol.wireguard => 51820,
        ProxyProtocol.socks => 1080,
        ProxyProtocol.http => 8080,
        ProxyProtocol.ssh => 22,
        _ => 443,
      };
    }

    final name = tag.isNotEmpty ? tag : '$profileServer:$profilePort';
    final uuid = switch (type) {
      'vless' || 'vmess' || 'tuic' => (outbound['uuid'] ?? '').toString(),
      'ssh' => (outbound['user'] ?? '').toString(),
      _ => null,
    };

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: protocol,
        server: profileServer,
        port: profilePort,
        credential: uuid ?? (outbound['password']?.toString()),
        name: name,
      ),
      name: name,
      protocol: protocol,
      server: profileServer,
      port: profilePort,
      uuid: (uuid == null || uuid.isEmpty) ? null : uuid,
      password: (outbound['password'] ?? '').toString().isEmpty
          ? null
          : outbound['password'].toString(),
      method: (outbound['method'] ?? outbound['security'] ?? '').toString(),
      alterId: _int(outbound['alter_id'], 0),
      flow: (outbound['flow'] ?? '').toString().isEmpty
          ? null
          : outbound['flow'].toString(),
      transport: proxyTransportFromKey(transportType),
      path: transportPath.isEmpty ? null : transportPath,
      host: transportHost,
      sni: (tls['server_name'] ?? '').toString().isEmpty
          ? null
          : tls['server_name'].toString(),
      alpn: _stringList(tls['alpn']).isEmpty
          ? null
          : _stringList(tls['alpn']).join(','),
      fingerprint: (utls['fingerprint'] ?? '').toString().isEmpty
          ? null
          : utls['fingerprint'].toString(),
      tls: tls['enabled'] == true,
      reality: reality['enabled'] == true,
      realityPublicKey: (reality['public_key'] ?? '').toString().isEmpty
          ? null
          : reality['public_key'].toString(),
      realityShortId: (reality['short_id'] ?? '').toString().isEmpty
          ? null
          : reality['short_id'].toString(),
      allowInsecure: tls['insecure'] == true,
      plugin: (outbound['plugin'] ?? '').toString().isEmpty
          ? null
          : outbound['plugin'].toString(),
      pluginOpts: (outbound['plugin_opts'] ?? '').toString().isEmpty
          ? null
          : outbound['plugin_opts'].toString(),
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {
        'outbound': outbound,
        if (type == 'wireguard') ...{
          'private_key': privateKey,
          'peer_public_key': peerPublicKey,
          'pre_shared_key': preSharedKey,
          'address': addresses,
          'reserved': reserved,
          'mtu': mtu,
        },
        if (type == 'hysteria2') ...{
          if (outbound['obfs'] is Map)
            'obfs': (outbound['obfs'] as Map)['type']?.toString(),
          if (outbound['obfs'] is Map)
            'obfs_password': (outbound['obfs'] as Map)['password']?.toString(),
        },
        if (type == 'tuic') ...{
          'congestion_control': outbound['congestion_control']?.toString(),
          'udp_relay_mode': outbound['udp_relay_mode']?.toString(),
        },
      },
    );
  }

  static int _int(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  static List<int> _intList(Object? value) {
    if (value is List) {
      return value.map((item) => _int(item, 0)).toList();
    }
    return const [];
  }

  static String? _hostValue(Map<String, dynamic> transport) {
    final headers = (transport['headers'] as Map?)?.cast<String, dynamic>();
    if (headers != null) {
      final host = headers['Host'] ?? headers['host'];
      if (host is List && host.isNotEmpty) return host.first.toString();
      if (host != null && host.toString().isNotEmpty) return host.toString();
    }
    final host = transport['host'];
    if (host is List && host.isNotEmpty) return host.first.toString();
    if (host is String && host.isNotEmpty) return host;
    return null;
  }
}
