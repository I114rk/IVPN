import 'dart:io';

/// Returns the most likely LAN IPv4 address of this machine, or null.
Future<String?> localIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('loopback') ||
          name.contains('wsl') ||
          name.contains('docker') ||
          name.contains('vethernet') ||
          name.contains('virtual')) {
        continue;
      }
      for (final address in interface.addresses) {
        final ip = address.address;
        if (address.isLoopback || ip.startsWith('169.254.')) continue;
        addresses.add(ip);
      }
    }
    if (addresses.isEmpty) return null;

    int score(String ip) {
      if (ip.startsWith('192.168.')) return 0;
      if (ip.startsWith('10.')) return 1;
      if (ip.startsWith('172.')) return 2;
      return 3;
    }

    addresses.sort((a, b) => score(a).compareTo(score(b)));
    return addresses.first;
  } catch (_) {
    return null;
  }
}
