class LanClient {
  final String ip;
  final int activeConnections;
  final int upload;
  final int download;
  final DateTime lastSeen;
  final List<String> hosts;

  const LanClient({
    required this.ip,
    this.activeConnections = 0,
    this.upload = 0,
    this.download = 0,
    required this.lastSeen,
    this.hosts = const [],
  });

  bool get isActive => activeConnections > 0;

  LanClient copyWith({int? activeConnections}) {
    return LanClient(
      ip: ip,
      activeConnections: activeConnections ?? this.activeConnections,
      upload: upload,
      download: download,
      lastSeen: lastSeen,
      hosts: hosts,
    );
  }
}
