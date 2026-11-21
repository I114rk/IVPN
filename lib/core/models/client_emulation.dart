class ClientEmulation {
  final String id;
  final String name;
  final String userAgent;
  final String core;
  final String description;
  final String? deviceOs;
  final String? deviceOsVersion;
  final String? deviceModel;

  const ClientEmulation({
    required this.id,
    required this.name,
    required this.userAgent,
    required this.core,
    required this.description,
    this.deviceOs,
    this.deviceOsVersion,
    this.deviceModel,
  });

  static const List<ClientEmulation> catalog = [
    ClientEmulation(
      id: 'happ',
      name: 'Happ',
      userAgent: 'Happ/1.6.0',
      core: 'Xray',
      description: 'Xray JSON, популярный клиент с HWID',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Pixel 8 Pro',
    ),
    ClientEmulation(
      id: 'hiddify',
      name: 'Hiddify',
      userAgent: 'Hiddify/2.5.7',
      core: 'Sing-box',
      description: 'Sing-box, кроссплатформенный клиент',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Pixel 8',
    ),
    ClientEmulation(
      id: 'incy',
      name: 'Incy',
      userAgent: 'INCY/1.0',
      core: 'Xray',
      description: 'Xray JSON, клиент с HWID',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Samsung Galaxy S24',
    ),
    ClientEmulation(
      id: 'v2raytun',
      name: 'v2RayTun',
      userAgent: 'v2RayTun/1.0',
      core: 'Xray',
      description: 'Xray JSON, iOS/Android клиент',
      deviceOs: 'iOS',
      deviceOsVersion: '17.5',
      deviceModel: 'iPhone 15 Pro',
    ),
    ClientEmulation(
      id: 'v2rayn',
      name: 'v2rayN',
      userAgent: 'v2rayN/6.42',
      core: 'Xray',
      description: 'Xray JSON, классический Windows-клиент',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
    ClientEmulation(
      id: 'nekobox',
      name: 'NekoBox',
      userAgent: 'NekoBox/1.3.4',
      core: 'Sing-box',
      description: 'Sing-box, Android-клиент',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Pixel 7',
    ),
    ClientEmulation(
      id: 'karing',
      name: 'Karing',
      userAgent: 'Karing/1.0',
      core: 'Sing-box',
      description: 'Sing-box, iOS/Android клиент',
      deviceOs: 'iOS',
      deviceOsVersion: '17.4',
      deviceModel: 'iPhone 14',
    ),
    ClientEmulation(
      id: 'shadowrocket',
      name: 'Shadowrocket',
      userAgent: 'Shadowrocket/2.2.40',
      core: 'Xray',
      description: 'Xray/Clash, iOS-клиент',
      deviceOs: 'iOS',
      deviceOsVersion: '17.5',
      deviceModel: 'iPhone 15',
    ),
    ClientEmulation(
      id: 'streisand',
      name: 'Streisand',
      userAgent: 'Streisand/1.0',
      core: 'Xray',
      description: 'Xray, iOS-клиент',
      deviceOs: 'iOS',
      deviceOsVersion: '17.5',
      deviceModel: 'iPhone 15 Pro Max',
    ),
    ClientEmulation(
      id: 'flclashx',
      name: 'FlClashX',
      userAgent: 'FlClashX/0.8.70',
      core: 'Mihomo',
      description: 'Mihomo/Clash, кроссплатформенный',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Pixel 8',
    ),
    ClientEmulation(
      id: 'koala-clash',
      name: 'Koala Clash',
      userAgent: 'Koala Clash/1.0',
      core: 'Mihomo',
      description: 'Mihomo/Clash, форк Clash Verge Rev',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
    ClientEmulation(
      id: 'throne',
      name: 'Throne',
      userAgent: 'Throne/1.0',
      core: 'Sing-box',
      description: 'Sing-box, десктопный клиент',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
    ClientEmulation(
      id: 'clash-mi',
      name: 'Clash Mi',
      userAgent: 'Clash Mi/1.0',
      core: 'Mihomo',
      description: 'Mihomo/Clash, мобильный клиент',
      deviceOs: 'Android',
      deviceOsVersion: '14',
      deviceModel: 'Pixel 7',
    ),
    ClientEmulation(
      id: 'singbox',
      name: 'sing-box',
      userAgent: 'sing-box/1.12.0 (singbox)',
      core: 'Sing-box',
      description: 'Официальный sing-box',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
    ClientEmulation(
      id: 'mihomo',
      name: 'Mihomo',
      userAgent: 'mihomo/1.19.0',
      core: 'Mihomo',
      description: 'Mihomo/Clash Meta',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
    ClientEmulation(
      id: 'outline',
      name: 'Outline',
      userAgent: 'Outline/1.0',
      core: 'Shadowsocks',
      description: 'Outline / Shadowsocks',
      deviceOs: 'Windows',
      deviceOsVersion: '10.0.22631',
      deviceModel: 'Windows PC',
    ),
  ];

  static ClientEmulation? byId(String? id) {
    if (id == null) return null;
    for (final client in catalog) {
      if (client.id == id) return client;
    }
    return null;
  }
}
