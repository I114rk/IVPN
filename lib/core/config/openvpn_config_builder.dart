import '../models/proxy_profile.dart';

class OpenVpnConfigBuilder {
  static bool isSupported(ProxyProfile profile) =>
      profile.protocol == ProxyProtocol.openvpn;

  static String build(ProxyProfile profile) {
    final raw = profile.extra['ovpn'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw;
    }
    final buffer = StringBuffer()
      ..writeln('client')
      ..writeln('dev tun')
      ..writeln('proto ${(profile.method ?? 'udp').toLowerCase()}')
      ..writeln('remote ${profile.server} ${profile.port}')
      ..writeln('resolv-retry infinite')
      ..writeln('nobind')
      ..writeln('persist-key')
      ..writeln('persist-tun')
      ..writeln('remote-cert-tls server')
      ..writeln('verb 3');
    return buffer.toString();
  }

  static ProxyProfile? parseConf(
    String source, {
    String name = 'OpenVPN',
    String? subscriptionId,
    String? subscriptionName,
  }) {
    String? remote;
    var port = 1194;
    var proto = 'udp';

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      switch (parts.first.toLowerCase()) {
        case 'remote':
          if (parts.length > 1) remote = parts[1];
          if (parts.length > 2) port = int.tryParse(parts[2]) ?? port;
          break;
        case 'proto':
          if (parts.length > 1) proto = parts[1];
          break;
      }
    }

    if (remote == null) return null;

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.openvpn,
        server: remote,
        port: port,
        credential: source.length.toString(),
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.openvpn,
      server: remote,
      port: port,
      method: proto,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'ovpn': source},
    );
  }
}
