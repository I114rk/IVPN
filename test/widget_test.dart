import 'package:flutter_test/flutter_test.dart';
import 'package:ivpn/core/config/singbox_config_builder.dart';
import 'package:ivpn/core/config/xray_config_builder.dart';
import 'package:ivpn/core/models/app_settings.dart';
import 'package:ivpn/core/models/proxy_profile.dart';
import 'package:ivpn/core/models/subscription.dart';
import 'package:ivpn/core/utils/byte_format.dart';

const _profile = ProxyProfile(
  id: 'test',
  name: 'Test',
  protocol: ProxyProtocol.vless,
  server: 'example.com',
  port: 443,
  uuid: '00000000-0000-0000-0000-000000000000',
);

void main() {
  test('proxy listens on loopback by default', () {
    final config = SingboxConfigBuilder.build(
      profile: _profile,
      settings: const AppSettings(mode: ConnectionMode.proxy),
    );
    final inbound = (config['inbounds'] as List).first as Map;
    expect(inbound['listen'], '127.0.0.1');
  });

  test('allowLan binds sing-box and Xray to all interfaces', () {
    const settings = AppSettings(mode: ConnectionMode.proxy, allowLan: true);
    final singbox = SingboxConfigBuilder.build(
      profile: _profile,
      settings: settings,
    );
    final singboxInbound = (singbox['inbounds'] as List).first as Map;
    expect(singboxInbound['listen'], '0.0.0.0');

    final xray = XrayConfigBuilder.build(profile: _profile, settings: settings);
    final inbounds = (xray['inbounds'] as List).cast<Map>();
    expect(inbounds, hasLength(2));
    expect(inbounds.every((inbound) => inbound['listen'] == '0.0.0.0'), isTrue);
  });

  test('sing-box config uses the current DNS server schema', () {
    final config = SingboxConfigBuilder.build(
      profile: _profile,
      settings: const AppSettings(mode: ConnectionMode.proxy),
    );
    final dns = config['dns'] as Map;
    final servers = (dns['servers'] as List).cast<Map>();
    expect(servers.map((server) => server['type']), ['udp', 'https']);
    expect(servers.every((server) => !server.containsKey('address')), isTrue);
    expect(servers.first.containsKey('detour'), isFalse);
    final route = config['route'] as Map;
    final resolver = route['default_domain_resolver'] as Map;
    expect(resolver['server'], 'local');
  });

  test('Xray private routing does not require geoip.dat', () {
    final config = XrayConfigBuilder.build(
      profile: _profile,
      settings: const AppSettings(mode: ConnectionMode.proxy),
    );
    final routing = config['routing'] as Map;
    final rule = (routing['rules'] as List).first as Map;
    final addresses = (rule['ip'] as List).cast<String>();
    expect(addresses, contains('192.168.0.0/16'));
    expect(addresses.any((address) => address.startsWith('geoip:')), isFalse);
  });

  test('profile extracts the final country flag for Windows rendering', () {
    const profile = ProxyProfile(
      id: 'flag',
      name: '\u{1F1F7}\u{1F1FA} -> \u{1F1EA}\u{1F1EA} Estonia',
      protocol: ProxyProtocol.vless,
      server: 'example.com',
      port: 443,
    );
    expect(profile.countryCode, 'EE');
    expect(profile.displayName, '-> Estonia');
  });

  test('formatBytes renders readable units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('SubscriptionUsage parses Remnawave header', () {
    final usage = SubscriptionUsage.parseHeader(
      'upload=1024; download=2048; total=10485760; expire=1900000000',
    );
    expect(usage, isNotNull);
    expect(usage!.upload, 1024);
    expect(usage.download, 2048);
    expect(usage.used, 3072);
    expect(usage.hasTotal, isTrue);
    expect(usage.ratio, closeTo(3072 / 10485760, 1e-9));
  });
}
