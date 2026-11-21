import '../models/proxy_profile.dart';

class WireguardConfigBuilder {
  static String build(ProxyProfile profile) {
    final extra = profile.extra;
    final addresses = (extra['address'] as List?)?.cast<String>() ?? const [];
    final dns = (extra['dns'] as List?)?.cast<String>() ?? const [];
    final mtu = (extra['mtu'] as num?)?.toInt() ?? 0;
    final privateKey =
        extra['private_key']?.toString() ?? profile.password ?? '';
    final publicKey = extra['peer_public_key']?.toString() ?? '';
    final preSharedKey = extra['pre_shared_key']?.toString() ?? '';

    final buffer = StringBuffer()
      ..writeln('[Interface]')
      ..writeln('PrivateKey = $privateKey');
    if (addresses.isNotEmpty) {
      buffer.writeln('Address = ${addresses.join(', ')}');
    }
    if (dns.isNotEmpty) {
      buffer.writeln('DNS = ${dns.join(', ')}');
    }
    if (mtu > 0) {
      buffer.writeln('MTU = $mtu');
    }
    buffer
      ..writeln()
      ..writeln('[Peer]')
      ..writeln('PublicKey = $publicKey');
    if (preSharedKey.isNotEmpty) {
      buffer.writeln('PresharedKey = $preSharedKey');
    }
    buffer
      ..writeln('Endpoint = ${profile.server}:${profile.port}')
      ..writeln('AllowedIPs = 0.0.0.0/0, ::/0')
      ..writeln('PersistentKeepalive = 25');
    return buffer.toString();
  }

  static ProxyProfile? parseConf(
    String source, {
    String name = 'WireGuard',
    String? subscriptionId,
    String? subscriptionName,
  }) {
    String? privateKey;
    String? publicKey;
    String? preSharedKey;
    String? endpoint;
    var port = 51820;
    final addresses = <String>[];
    final dns = <String>[];
    var mtu = 0;

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('[')) {
        continue;
      }
      final split = line.indexOf('=');
      if (split < 0) continue;
      final key = line.substring(0, split).trim().toLowerCase();
      final value = line.substring(split + 1).trim();
      switch (key) {
        case 'privatekey':
          privateKey = value;
          break;
        case 'publickey':
          publicKey = value;
          break;
        case 'presharedkey':
          preSharedKey = value;
          break;
        case 'address':
          addresses.addAll(value.split(',').map((e) => e.trim()));
          break;
        case 'dns':
          dns.addAll(value.split(',').map((e) => e.trim()));
          break;
        case 'mtu':
          mtu = int.tryParse(value) ?? 0;
          break;
        case 'endpoint':
          endpoint = value;
          break;
      }
    }

    if (privateKey == null || endpoint == null) return null;
    final endpointSplit = endpoint.lastIndexOf(':');
    final host = endpointSplit >= 0
        ? endpoint.substring(0, endpointSplit)
        : endpoint;
    if (endpointSplit >= 0) {
      port = int.tryParse(endpoint.substring(endpointSplit + 1)) ?? port;
    }

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.wireguard,
        server: host,
        port: port,
        credential: privateKey,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.wireguard,
      server: host,
      port: port,
      password: privateKey,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {
        'private_key': privateKey,
        'peer_public_key': publicKey ?? '',
        'pre_shared_key': preSharedKey ?? '',
        'address': addresses,
        'dns': dns,
        'mtu': mtu,
        'ovpn_wg': source,
      },
    );
  }
}
