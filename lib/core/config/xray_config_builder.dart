import 'dart:convert';

import '../models/app_settings.dart';
import '../models/proxy_profile.dart';

class XrayConfigBuilder {
  static const privateCidrs = [
    '10.0.0.0/8',
    '127.0.0.0/8',
    '169.254.0.0/16',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '::1/128',
    'fc00::/7',
    'fe80::/10',
  ];

  static bool supports(ProxyProfile profile) => profile.supportsXray;

  static Map<String, dynamic> build({
    required ProxyProfile profile,
    required AppSettings settings,
  }) {
    final socksPort = settings.mixedPort;
    final httpPort = settings.mixedPort + 1;
    final listen = settings.allowLan ? '0.0.0.0' : '127.0.0.1';

    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks-in',
          'listen': listen,
          'port': socksPort,
          'protocol': 'socks',
          'settings': {'udp': true, 'auth': 'noauth'},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
        },
        {
          'tag': 'http-in',
          'listen': listen,
          'port': httpPort,
          'protocol': 'http',
          'settings': {},
        },
      ],
      'outbounds': [
        _outbound(profile),
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {'type': 'field', 'ip': privateCidrs, 'outboundTag': 'direct'},
        ],
      },
    };
  }

  static Map<String, dynamic> _outbound(ProxyProfile profile) {
    final raw = profile.extra['xray_outbound'];
    if (raw is Map) {
      final copy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      copy['tag'] = 'proxy';
      return copy;
    }

    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': profile.protocol.name,
    };

    switch (profile.protocol) {
      case ProxyProtocol.vless:
        outbound['settings'] = {
          'vnext': [
            {
              'address': profile.server,
              'port': profile.port,
              'users': [
                {
                  'id': profile.uuid ?? '',
                  'encryption': 'none',
                  if ((profile.flow ?? '').isNotEmpty) 'flow': profile.flow,
                },
              ],
            },
          ],
        };
        break;
      case ProxyProtocol.vmess:
        outbound['settings'] = {
          'vnext': [
            {
              'address': profile.server,
              'port': profile.port,
              'users': [
                {
                  'id': profile.uuid ?? '',
                  'alterId': profile.alterId,
                  'security': (profile.method ?? '').isNotEmpty
                      ? profile.method
                      : 'auto',
                },
              ],
            },
          ],
        };
        break;
      case ProxyProtocol.trojan:
        outbound['settings'] = {
          'servers': [
            {
              'address': profile.server,
              'port': profile.port,
              'password': profile.password ?? '',
            },
          ],
        };
        break;
      case ProxyProtocol.shadowsocks:
        outbound['settings'] = {
          'servers': [
            {
              'address': profile.server,
              'port': profile.port,
              'method': profile.method ?? 'aes-128-gcm',
              'password': profile.password ?? '',
            },
          ],
        };
        break;
      case ProxyProtocol.socks:
        outbound['protocol'] = 'socks';
        outbound['settings'] = {
          'servers': [
            {
              'address': profile.server,
              'port': profile.port,
              if ((profile.uuid ?? '').isNotEmpty ||
                  (profile.password ?? '').isNotEmpty)
                'users': [
                  {'user': profile.uuid ?? '', 'pass': profile.password ?? ''},
                ],
            },
          ],
        };
        break;
      case ProxyProtocol.http:
        outbound['protocol'] = 'http';
        outbound['settings'] = {
          'servers': [
            {
              'address': profile.server,
              'port': profile.port,
              if ((profile.uuid ?? '').isNotEmpty ||
                  (profile.password ?? '').isNotEmpty)
                'users': [
                  {'user': profile.uuid ?? '', 'pass': profile.password ?? ''},
                ],
            },
          ],
        };
        break;
      default:
        throw UnsupportedError(
          'Xray не поддерживает протокол ${profile.protocol.label}',
        );
    }

    final stream = _streamSettings(profile);
    if (stream.isNotEmpty) outbound['streamSettings'] = stream;
    return outbound;
  }

  static Map<String, dynamic> _streamSettings(ProxyProfile profile) {
    final stream = <String, dynamic>{
      'network': switch (profile.transport) {
        ProxyTransport.ws => 'ws',
        ProxyTransport.grpc => 'grpc',
        ProxyTransport.http => 'http',
        ProxyTransport.httpUpgrade => 'httpupgrade',
        ProxyTransport.quic => 'quic',
        _ => 'tcp',
      },
    };

    final sni = (profile.sni ?? '').isNotEmpty
        ? profile.sni!
        : ((profile.host ?? '').isNotEmpty ? profile.host! : profile.server);
    final fingerprint = (profile.fingerprint ?? '').isNotEmpty
        ? profile.fingerprint
        : (profile.reality ? 'chrome' : null);

    if (profile.reality) {
      stream['security'] = 'reality';
      stream['realitySettings'] = {
        'serverName': sni,
        'fingerprint': fingerprint ?? 'chrome',
        if ((profile.realityPublicKey ?? '').isNotEmpty)
          'publicKey': profile.realityPublicKey,
        if ((profile.realityShortId ?? '').isNotEmpty)
          'shortId': profile.realityShortId,
        'show': false,
      };
    } else if (profile.tls) {
      stream['security'] = 'tls';
      stream['tlsSettings'] = {
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': profile.allowInsecure,
        if (profile.alpnList.isNotEmpty) 'alpn': profile.alpnList,
        if (fingerprint != null && fingerprint.isNotEmpty)
          'fingerprint': fingerprint,
      };
    }

    switch (profile.transport) {
      case ProxyTransport.ws:
        stream['wsSettings'] = {
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if ((profile.host ?? '').isNotEmpty)
            'headers': {'Host': profile.host},
        };
        break;
      case ProxyTransport.grpc:
        stream['grpcSettings'] = {'serviceName': profile.path ?? ''};
        break;
      case ProxyTransport.http:
        stream['httpSettings'] = {
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if ((profile.host ?? '').isNotEmpty) 'host': [profile.host],
        };
        break;
      case ProxyTransport.httpUpgrade:
        stream['httpupgradeSettings'] = {
          'path': (profile.path ?? '').isNotEmpty ? profile.path : '/',
          if ((profile.host ?? '').isNotEmpty) 'host': profile.host,
        };
        break;
      default:
        break;
    }

    return stream;
  }
}
