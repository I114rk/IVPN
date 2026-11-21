import 'dart:convert';

import '../models/proxy_profile.dart';
import '../utils/base64_utils.dart';

class ShareLinkParser {
  static List<ProxyProfile> parseLines(
    String text, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    final profiles = <ProxyProfile>[];
    for (final line in const LineSplitter().convert(text)) {
      final value = line.trim();
      if (value.isEmpty || !value.contains('://')) continue;
      final profile = parseLink(
        value,
        subscriptionId: subscriptionId,
        subscriptionName: subscriptionName,
      );
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  static ProxyProfile? parseLink(
    String link, {
    String? subscriptionId,
    String? subscriptionName,
  }) {
    try {
      final scheme = link.split('://').first.toLowerCase();
      return switch (scheme) {
        'vless' => _vless(link, subscriptionId, subscriptionName),
        'vmess' => _vmess(link, subscriptionId, subscriptionName),
        'trojan' => _trojan(link, subscriptionId, subscriptionName),
        'ss' => _shadowsocks(link, subscriptionId, subscriptionName),
        'hysteria2' || 'hy2' =>
          _hysteria2(link, subscriptionId, subscriptionName),
        'tuic' => _tuic(link, subscriptionId, subscriptionName),
        'socks' || 'socks5' => _socks(link, subscriptionId, subscriptionName),
        'http' || 'https' => _http(link, subscriptionId, subscriptionName),
        'ssh' => _ssh(link, subscriptionId, subscriptionName),
        'wireguard' || 'wg' =>
          _wireguard(link, subscriptionId, subscriptionName),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  static ProxyProfile? _vless(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final security = (query['security'] ?? 'none').toLowerCase();
    final transport = proxyTransportFromKey(query['type']);
    final uuid = uri.userInfo;
    final name = _name(uri, '${uri.host}:${uri.port}');

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.vless,
        server: uri.host,
        port: _port(uri, 443),
        credential: uuid,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.vless,
      server: uri.host,
      port: _port(uri, 443),
      uuid: uuid,
      flow: query['flow'],
      transport: transport,
      path: _transportPath(query),
      host: _transportHost(query),
      sni: query['sni'] ?? query['serverName'],
      alpn: query['alpn'],
      fingerprint: query['fp'] ?? query['fingerprint'],
      tls: security == 'tls' || security == 'reality' || security == 'xtls',
      reality: security == 'reality',
      realityPublicKey: query['pbk'] ?? query['publicKey'],
      realityShortId: query['sid'] ?? query['shortId'],
      allowInsecure: _bool(query['allowInsecure']) || _bool(query['insecure']),
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _vmess(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    var payload = link.substring('vmess://'.length).trim();
    String? fragmentName;
    final hashIndex = payload.indexOf('#');
    if (hashIndex >= 0) {
      fragmentName = Uri.decodeComponent(payload.substring(hashIndex + 1));
      payload = payload.substring(0, hashIndex);
    }
    final decoded = tryBase64DecodeUtf8(payload);
    if (decoded == null) return null;
    final map = jsonDecode(decoded);
    if (map is! Map) return null;
    final json = map.cast<String, dynamic>();

    final server = (json['add'] ?? '').toString();
    if (server.isEmpty) return null;
    final port = _toInt(json['port'], 443);
    final uuid = (json['id'] ?? '').toString();
    final network = (json['net'] ?? 'tcp').toString();
    final tls = (json['tls'] ?? '').toString().toLowerCase() == 'tls';
    final name = (json['ps'] ?? fragmentName ?? server).toString();

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.vmess,
        server: server,
        port: port,
        credential: uuid,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.vmess,
      server: server,
      port: port,
      uuid: uuid,
      method: (json['scy'] ?? 'auto').toString(),
      alterId: _toInt(json['aid'], 0),
      transport: proxyTransportFromKey(network),
      path: (json['path'] ?? '').toString(),
      host: (json['host'] ?? '').toString(),
      sni: (json['sni'] ?? json['host'] ?? '').toString(),
      alpn: (json['alpn'] ?? '').toString(),
      fingerprint: (json['fp'] ?? '').toString(),
      tls: tls,
      allowInsecure: _bool(json['verify_cert']) == false && tls,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _trojan(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final name = _name(uri, '${uri.host}:${uri.port}');
    final password = uri.userInfo;
    final security = (query['security'] ?? 'tls').toLowerCase();

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.trojan,
        server: uri.host,
        port: _port(uri, 443),
        credential: password,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.trojan,
      server: uri.host,
      port: _port(uri, 443),
      password: password,
      transport: proxyTransportFromKey(query['type']),
      path: _transportPath(query),
      host: _transportHost(query),
      sni: query['sni'] ?? query['peer'],
      alpn: query['alpn'],
      fingerprint: query['fp'],
      tls: security != 'none',
      reality: security == 'reality',
      realityPublicKey: query['pbk'],
      realityShortId: query['sid'],
      allowInsecure: _bool(query['allowInsecure']) || _bool(query['insecure']),
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _shadowsocks(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    var body = link.substring('ss://'.length);
    String? fragmentName;
    final hashIndex = body.indexOf('#');
    if (hashIndex >= 0) {
      fragmentName = Uri.decodeComponent(body.substring(hashIndex + 1));
      body = body.substring(0, hashIndex);
    }

    String? method;
    String? password;
    String host;
    int port;
    String? plugin;
    String? pluginOpts;

    final atIndex = body.indexOf('@');
    if (atIndex >= 0) {
      final userInfo = body.substring(0, atIndex);
      var rest = body.substring(atIndex + 1);
      final queryIndex = rest.indexOf('?');
      if (queryIndex >= 0) {
        final query = Uri.splitQueryString(rest.substring(queryIndex + 1));
        final pluginRaw = query['plugin'];
        if (pluginRaw != null && pluginRaw.isNotEmpty) {
          final parts = pluginRaw.split(';');
          plugin = parts.first;
          if (parts.length > 1) pluginOpts = parts.skip(1).join(';');
        }
        rest = rest.substring(0, queryIndex);
      }
      final decodedUser = tryBase64DecodeUtf8(userInfo) ?? Uri.decodeComponent(userInfo);
      final split = decodedUser.indexOf(':');
      if (split < 0) return null;
      method = decodedUser.substring(0, split);
      password = decodedUser.substring(split + 1);
      final hostPort = _splitHostPort(rest);
      if (hostPort == null) return null;
      host = hostPort.$1;
      port = hostPort.$2;
    } else {
      final decoded = tryBase64DecodeUtf8(body);
      if (decoded == null) return null;
      final split = decoded.indexOf(':');
      final at = decoded.indexOf('@');
      if (split < 0 || at < 0) return null;
      method = decoded.substring(0, split);
      password = decoded.substring(split + 1, at);
      final hostPort = _splitHostPort(decoded.substring(at + 1));
      if (hostPort == null) return null;
      host = hostPort.$1;
      port = hostPort.$2;
    }

    final name = fragmentName ?? '$host:$port';
    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.shadowsocks,
        server: host,
        port: port,
        credential: password,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.shadowsocks,
      server: host,
      port: port,
      method: method,
      password: password,
      plugin: plugin,
      pluginOpts: pluginOpts,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _hysteria2(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final name = _name(uri, '${uri.host}:${uri.port}');
    final password = uri.userInfo;

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.hysteria2,
        server: uri.host,
        port: _port(uri, 443),
        credential: password,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.hysteria2,
      server: uri.host,
      port: _port(uri, 443),
      password: password,
      transport: ProxyTransport.quic,
      sni: query['sni'],
      alpn: query['alpn'],
      fingerprint: query['pinSHA256'],
      tls: true,
      allowInsecure: _bool(query['insecure']),
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {
        'link': link,
        if (query['obfs'] != null) 'obfs': query['obfs'],
        if (query['obfs-password'] != null)
          'obfs_password': query['obfs-password'],
      },
    );
  }

  static ProxyProfile? _tuic(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final userInfo = uri.userInfo;
    final split = userInfo.indexOf(':');
    final uuid = split >= 0 ? userInfo.substring(0, split) : userInfo;
    final password = split >= 0 ? userInfo.substring(split + 1) : '';
    final name = _name(uri, '${uri.host}:${uri.port}');

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.tuic,
        server: uri.host,
        port: _port(uri, 443),
        credential: uuid,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.tuic,
      server: uri.host,
      port: _port(uri, 443),
      uuid: uuid,
      password: password,
      transport: ProxyTransport.quic,
      sni: query['sni'],
      alpn: query['alpn'],
      tls: true,
      allowInsecure: _bool(query['allow_insecure']) || _bool(query['insecure']),
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {
        'link': link,
        if (query['congestion_control'] != null)
          'congestion_control': query['congestion_control'],
        if (query['udp_relay_mode'] != null)
          'udp_relay_mode': query['udp_relay_mode'],
      },
    );
  }

  static ProxyProfile? _socks(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final userInfo = uri.userInfo;
    final split = userInfo.indexOf(':');
    final name = _name(uri, '${uri.host}:${uri.port}');
    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.socks,
        server: uri.host,
        port: _port(uri, 1080),
        credential: userInfo,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.socks,
      server: uri.host,
      port: _port(uri, 1080),
      uuid: split >= 0 ? userInfo.substring(0, split) : null,
      password: split >= 0 ? userInfo.substring(split + 1) : null,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _http(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final userInfo = uri.userInfo;
    final split = userInfo.indexOf(':');
    final name = _name(uri, '${uri.host}:${uri.port}');
    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.http,
        server: uri.host,
        port: _port(uri, 8080),
        credential: userInfo,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.http,
      server: uri.host,
      port: _port(uri, 8080),
      uuid: split >= 0 ? userInfo.substring(0, split) : null,
      password: split >= 0 ? userInfo.substring(split + 1) : null,
      tls: uri.scheme.toLowerCase() == 'https',
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _ssh(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final userInfo = uri.userInfo;
    final split = userInfo.indexOf(':');
    final name = _name(uri, '${uri.host}:${uri.port}');
    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.ssh,
        server: uri.host,
        port: _port(uri, 22),
        credential: userInfo,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.ssh,
      server: uri.host,
      port: _port(uri, 22),
      uuid: split >= 0 ? userInfo.substring(0, split) : userInfo,
      password: split >= 0 ? userInfo.substring(split + 1) : null,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {'link': link},
    );
  }

  static ProxyProfile? _wireguard(
    String link,
    String? subscriptionId,
    String? subscriptionName,
  ) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    final query = uri.queryParameters;
    final privateKey = uri.userInfo;
    final name = _name(uri, '${uri.host}:${uri.port}');
    final address = query['address'] ?? query['ip'] ?? '10.0.0.2/32';
    final reservedRaw = query['reserved'];

    return ProxyProfile(
      id: ProxyProfile.buildId(
        protocol: ProxyProtocol.wireguard,
        server: uri.host,
        port: _port(uri, 51820),
        credential: privateKey,
        name: name,
      ),
      name: name,
      protocol: ProxyProtocol.wireguard,
      server: uri.host,
      port: _port(uri, 51820),
      password: privateKey,
      subscriptionId: subscriptionId,
      subscriptionName: subscriptionName,
      extra: {
        'link': link,
        'private_key': privateKey,
        'peer_public_key': query['publickey'] ?? query['public_key'] ?? '',
        'pre_shared_key':
            query['presharedkey'] ?? query['preshared_key'] ?? '',
        'address': address.split(',').map((e) => e.trim()).toList(),
        if (reservedRaw != null)
          'reserved': reservedRaw
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .toList(),
        if (query['mtu'] != null) 'mtu': int.tryParse(query['mtu']!) ?? 1420,
        if (query['dns'] != null)
          'dns': query['dns']!.split(',').map((e) => e.trim()).toList(),
      },
    );
  }

  static int _port(Uri uri, int fallback) =>
      uri.hasPort && uri.port > 0 ? uri.port : fallback;

  static String _name(Uri uri, String fallback) {
    final fragment = uri.fragment;
    if (fragment.isEmpty) return fallback;
    try {
      return Uri.decodeComponent(fragment);
    } catch (_) {
      return fragment;
    }
  }

  static int _toInt(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _bool(Object? value) {
    final text = value?.toString().toLowerCase();
    return text == '1' || text == 'true';
  }

  static (String, int)? _splitHostPort(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[')) {
      final end = trimmed.indexOf(']');
      if (end < 0) return null;
      final host = trimmed.substring(1, end);
      final rest = trimmed.substring(end + 1);
      final port = int.tryParse(rest.replaceFirst(':', '')) ?? 0;
      if (port == 0) return null;
      return (host, port);
    }
    final index = trimmed.lastIndexOf(':');
    if (index < 0) return null;
    final host = trimmed.substring(0, index);
    final port = int.tryParse(trimmed.substring(index + 1));
    if (port == null) return null;
    return (host, port);
  }

  static String? _transportPath(Map<String, String> query) {
    final value = query['path'] ?? query['serviceName'] ?? query['service_name'];
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? _transportHost(Map<String, String> query) {
    final value = query['host'] ?? query['authority'];
    return (value == null || value.isEmpty) ? null : value;
  }
}
