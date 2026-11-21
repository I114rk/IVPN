import 'package:yaml/yaml.dart';

import '../models/proxy_profile.dart';

class MihomoParser {
  static List<ProxyProfile> parse(
    String source, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final decoded = loadYaml(source);
    if (decoded is! Map) return const [];
    final proxies = decoded['proxies'];
    if (proxies is! List) return const [];

    final profiles = <ProxyProfile>[];
    for (final item in proxies) {
      if (item is! Map) continue;
      final map = item.cast<Object?, Object?>();
      final profile = _fromProxy(
        map,
        subscriptionId: subscriptionId,
        subscriptionName: subscriptionName,
      );
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  static ProxyProfile? _fromProxy(
    Map<Object?, Object?> map, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final type = (map['type'] ?? '').toString().toLowerCase();
    final protocol = switch (type) {
      'ss' => ProxyProtocol.shadowsocks,
      'socks5' => ProxyProtocol.socks,
      'hysteria2' || 'hy2' => ProxyProtocol.hysteria2,
      'wireguard' || 'wg' => ProxyProtocol.wireguard,
      _ => proxyProtocolFromKey(type),
    };
    if (protocol == ProxyProtocol.unknown) return null;

    final server = (map['server'] ?? '').toString();
    if (server.isEmpty) return null;
    final port = _int(map['port'], _defaultPort(protocol));
    final name = (map['name'] ?? '$server:$port').toString();

    final wsOpts = (map['ws-opts'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final grpcOpts =
        (map['grpc-opts'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final realityOpts =
        (map['reality-opts'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final wsHeaders =
        (wsOpts['headers'] as Map?)?.cast<Object?, Object?>() ?? const {};

    final network = (map['network'] ?? '').toString();
    final tls = map['tls'] == true;
    final uuid = (map['uuid'] ?? '').toString();
    final password = (map['password'] ?? '').toString();

    final extra = <String, dynamic>{'mihomo': map};
    if (protocol == ProxyProtocol.hysteria2) {
      extra['obfs'] = map['obfs']?.toString();
      extra['obfs_password'] = map['obfs-password']?.toString();
    }
    if (protocol == ProxyProtocol.wireguard) {
      extra.addAll({
        'private_key': (map['private-key'] ?? '').toString(),
        'peer_public_key': (map['public-key'] ?? '').toString(),
        'pre_shared_key': (map['pre-shared-key'] ?? '').toString(),
        'address': [
          if (map['ip'] != null) '${map['ip']}/32',
          if (map['ipv6'] != null) '${map['ipv6']}/128',
        ],
        'reserved': _intList(map['reserved']),
        'mtu': _int(map['mtu'], 0),
      });
    }

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: protocol,
        server: server,
        port: port,
        credential: uuid.isNotEmpty ? uuid : password,
        name: name,
      ),
      name: name,
      protocol: protocol,
      server: server,
      port: port,
      uuid: uuid.isEmpty ? null : uuid,
      password: password.isEmpty ? null : password,
      method: (map['cipher'] ?? '').toString(),
      alterId: _int(map['alterId'], 0),
      flow: (map['flow'] ?? '').toString(),
      transport: proxyTransportFromKey(network),
      path: (wsOpts['path'] ?? grpcOpts['grpc-service-name'] ?? '').toString(),
      host: (wsHeaders['Host'] ?? wsHeaders['host'] ?? '').toString(),
      sni: (map['servername'] ?? map['sni'] ?? '').toString(),
      alpn: _stringList(map['alpn']).join(','),
      fingerprint: (map['client-fingerprint'] ?? '').toString(),
      tls: tls || protocol == ProxyProtocol.hysteria2 ||
          protocol == ProxyProtocol.tuic,
      reality: realityOpts.isNotEmpty,
      realityPublicKey: (realityOpts['public-key'] ?? '').toString(),
      realityShortId: (realityOpts['short-id'] ?? '').toString(),
      allowInsecure: map['skip-cert-verify'] == true,
      plugin: (map['plugin'] ?? '').toString(),
      pluginOpts: (map['plugin-opts'] is Map)
          ? (map['plugin-opts'] as Map)
              .entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(';')
          : null,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: extra,
    );
  }

  static int _defaultPort(ProxyProtocol protocol) => switch (protocol) {
        ProxyProtocol.hysteria2 => 443,
        ProxyProtocol.tuic => 443,
        ProxyProtocol.wireguard => 51820,
        ProxyProtocol.socks => 1080,
        ProxyProtocol.http => 8080,
        ProxyProtocol.shadowsocks => 8388,
        _ => 443,
      };

  static int _int(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  static List<int> _intList(Object? value) {
    if (value is List) return value.map((item) => _int(item, 0)).toList();
    return const [];
  }
}
