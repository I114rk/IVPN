import 'dart:convert';

import '../models/app_settings.dart';
import '../models/proxy_profile.dart';

class SingboxConfigBuilder {
  static const int clashApiPort = 19090;

  static Map<String, dynamic> build({
    required ProxyProfile profile,
    required AppSettings settings,
    bool android = false,
  }) {
    return {
      'log': {'level': 'info', 'timestamp': true},
      'dns': _dns(),
      'inbounds': [
        if (settings.mode == ConnectionMode.tun || android)
          _tunInbound(settings, android: android)
        else
          _mixedInbound(settings),
      ],
      'outbounds': [
        proxyOutbound(profile),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'auto_detect_interface': true,
        'default_domain_resolver': {
          'server': 'local',
          'strategy': 'prefer_ipv4',
        },
        'final': 'proxy',
        'rules': [
          {'action': 'sniff'},
          {'ip_is_private': true, 'action': 'route', 'outbound': 'direct'},
          {
            'domain_suffix': ['local'],
            'action': 'route',
            'outbound': 'direct',
          },
        ],
      },
      'experimental': {
        'clash_api': {'external_controller': '127.0.0.1:$clashApiPort'},
      },
    };
  }

  static Map<String, dynamic> proxyOutbound(ProxyProfile profile) {
    final raw = profile.extra['outbound'];
    if (raw is Map) {
      final copy = _deepCopy(raw.cast<String, dynamic>());
      copy['tag'] = 'proxy';
      return copy;
    }

    final outbound = <String, dynamic>{'tag': 'proxy'};

    switch (profile.protocol) {
      case ProxyProtocol.vless:
        outbound.addAll({
          'type': 'vless',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': profile.uuid ?? '',
          'packet_encoding': 'xudp',
          if ((profile.flow ?? '').isNotEmpty) 'flow': profile.flow,
        });
        break;
      case ProxyProtocol.vmess:
        outbound.addAll({
          'type': 'vmess',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': profile.uuid ?? '',
          'security': (profile.method ?? '').isNotEmpty
              ? profile.method
              : 'auto',
          if (profile.alterId > 0) 'alter_id': profile.alterId,
        });
        break;
      case ProxyProtocol.trojan:
        outbound.addAll({
          'type': 'trojan',
          'server': profile.server,
          'server_port': profile.port,
          'password': profile.password ?? '',
        });
        break;
      case ProxyProtocol.shadowsocks:
        outbound.addAll({
          'type': 'shadowsocks',
          'server': profile.server,
          'server_port': profile.port,
          'method': profile.method ?? 'aes-128-gcm',
          'password': profile.password ?? '',
          if ((profile.plugin ?? '').isNotEmpty) 'plugin': profile.plugin,
          if ((profile.pluginOpts ?? '').isNotEmpty)
            'plugin_opts': profile.pluginOpts,
        });
        break;
      case ProxyProtocol.hysteria2:
        outbound.addAll({
          'type': 'hysteria2',
          'server': profile.server,
          'server_port': profile.port,
          'password': profile.password ?? '',
          if ((profile.extra['obfs'] ?? '').toString().isNotEmpty)
            'obfs': {
              'type': profile.extra['obfs'],
              'password': profile.extra['obfs_password'] ?? '',
            },
        });
        break;
      case ProxyProtocol.tuic:
        outbound.addAll({
          'type': 'tuic',
          'server': profile.server,
          'server_port': profile.port,
          'uuid': profile.uuid ?? '',
          'password': profile.password ?? '',
          'congestion_control':
              profile.extra['congestion_control']?.toString() ?? 'bbr',
          'udp_relay_mode':
              profile.extra['udp_relay_mode']?.toString() ?? 'native',
        });
        break;
      case ProxyProtocol.wireguard:
        final extra = profile.extra;
        outbound.addAll({
          'type': 'wireguard',
          'server': profile.server,
          'server_port': profile.port,
          'local_address':
              (extra['address'] as List?)?.cast<String>() ?? ['10.0.0.2/32'],
          'private_key':
              extra['private_key']?.toString() ?? profile.password ?? '',
          'peer_public_key': extra['peer_public_key']?.toString() ?? '',
          if ((extra['pre_shared_key'] ?? '').toString().isNotEmpty)
            'pre_shared_key': extra['pre_shared_key'],
          if ((extra['reserved'] as List?)?.isNotEmpty == true)
            'reserved': extra['reserved'],
          if ((extra['mtu'] as num?)?.toInt() != null)
            'mtu': (extra['mtu'] as num).toInt(),
        });
        break;
      case ProxyProtocol.socks:
        outbound.addAll({
          'type': 'socks',
          'server': profile.server,
          'server_port': profile.port,
          'version': '5',
          if ((profile.uuid ?? '').isNotEmpty) 'username': profile.uuid,
          if ((profile.password ?? '').isNotEmpty) 'password': profile.password,
        });
        break;
      case ProxyProtocol.http:
        outbound.addAll({
          'type': 'http',
          'server': profile.server,
          'server_port': profile.port,
          if ((profile.uuid ?? '').isNotEmpty) 'username': profile.uuid,
          if ((profile.password ?? '').isNotEmpty) 'password': profile.password,
        });
        break;
      case ProxyProtocol.ssh:
        outbound.addAll({
          'type': 'ssh',
          'server': profile.server,
          'server_port': profile.port,
          'user': profile.uuid ?? '',
          if ((profile.password ?? '').isNotEmpty) 'password': profile.password,
          if ((profile.extra['private_key'] ?? '').toString().isNotEmpty)
            'private_key': profile.extra['private_key'],
        });
        break;
      case ProxyProtocol.openvpn:
      case ProxyProtocol.unknown:
        throw UnsupportedError(
          'Sing-box не поддерживает протокол ${profile.protocol.label}',
        );
    }

    final tls = _tls(profile);
    if (tls != null) outbound['tls'] = tls;
    final transport = _transport(profile);
    if (transport != null) outbound['transport'] = transport;

    return outbound;
  }

  static Map<String, dynamic> _dns() {
    return {
      'servers': [
        {'type': 'udp', 'tag': 'local', 'server': '223.5.5.5'},
        {
          'type': 'https',
          'tag': 'remote',
          'server': '1.1.1.1',
          'detour': 'proxy',
        },
      ],
      'rules': [
        {
          'domain_suffix': ['local', 'lan'],
          'action': 'route',
          'server': 'local',
        },
      ],
      'final': 'remote',
      'strategy': 'prefer_ipv4',
    };
  }

  static Map<String, dynamic> _tunInbound(
    AppSettings settings, {
    bool android = false,
  }) {
    if (android) {
      // Android: файловый дескриптор TUN выдаёт нативная VpnService,
      // поэтому путь интерфейса и strict_route задаются платформой.
      return {
        'type': 'tun',
        'tag': 'tun-in',
        'address': ['172.19.0.1/30'],
        'mtu': 9000,
        'auto_route': true,
        'stack': 'gvisor',
      };
    }
    return {
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': 'IVPN',
      'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      'mtu': 9000,
      'auto_route': true,
      'strict_route': true,
      'stack': settings.tunStack,
    };
  }

  static Map<String, dynamic> _mixedInbound(AppSettings settings) {
    return {
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': settings.allowLan ? '0.0.0.0' : '127.0.0.1',
      'listen_port': settings.mixedPort,
    };
  }

  static Map<String, dynamic>? _tls(ProxyProfile profile) {
    if (!profile.tls && !profile.reality) return null;
    final tls = <String, dynamic>{'enabled': true};
    final sni = (profile.sni ?? '').isNotEmpty
        ? profile.sni
        : ((profile.host ?? '').isNotEmpty ? profile.host : profile.server);
    if (sni != null && sni.isNotEmpty) tls['server_name'] = sni;
    if (profile.allowInsecure) tls['insecure'] = true;
    final alpn = profile.alpnList;
    if (alpn.isNotEmpty) tls['alpn'] = alpn;

    final fingerprint = (profile.fingerprint ?? '').isNotEmpty
        ? profile.fingerprint
        : (profile.reality ? 'chrome' : null);
    if (fingerprint != null && fingerprint.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
    }
    if (profile.reality && (profile.realityPublicKey ?? '').isNotEmpty) {
      tls['reality'] = {
        'enabled': true,
        'public_key': profile.realityPublicKey,
        'short_id': profile.realityShortId ?? '',
      };
    }
    return tls;
  }

  static Map<String, dynamic>? _transport(ProxyProfile profile) {
    final host = profile.host ?? '';
    switch (profile.transport) {
      case ProxyTransport.ws:
        return {
          'type': 'ws',
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if (host.isNotEmpty) 'headers': {'Host': host},
        };
      case ProxyTransport.grpc:
        return {'type': 'grpc', 'service_name': profile.path ?? ''};
      case ProxyTransport.http:
        return {
          'type': 'http',
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if (host.isNotEmpty) 'host': [host],
        };
      case ProxyTransport.httpUpgrade:
        return {
          'type': 'httpupgrade',
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if (host.isNotEmpty) 'host': host,
        };
      case ProxyTransport.quic:
        return {'type': 'quic'};
      case ProxyTransport.tcp:
      case ProxyTransport.kcp:
        return null;
    }
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }
}
