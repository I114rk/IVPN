import 'proxy_profile.dart';

class SubscriptionUsage {
  final int upload;
  final int download;
  final int total;
  final int expire;

  const SubscriptionUsage({
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire = 0,
  });

  bool get hasTotal => total > 0;
  bool get isExpired =>
      expire > 0 &&
      DateTime.fromMillisecondsSinceEpoch(expire * 1000).isBefore(DateTime.now());

  int get used => upload + download;

  double get ratio {
    if (!hasTotal) return 0;
    return (used / total).clamp(0.0, 1.0);
  }

  DateTime? get expireDate => expire > 0
      ? DateTime.fromMillisecondsSinceEpoch(expire * 1000)
      : null;

  Map<String, dynamic> toJson() => {
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire,
      };

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsage(
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      expire: (json['expire'] as num?)?.toInt() ?? 0,
    );
  }

  static SubscriptionUsage? parseHeader(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = <String, int>{};
    for (final chunk in value.split(';')) {
      final pair = chunk.split('=');
      if (pair.length != 2) continue;
      final key = pair[0].trim().toLowerCase();
      final parsed = int.tryParse(pair[1].trim());
      if (parsed != null) parts[key] = parsed;
    }
    if (parts.isEmpty) return null;
    return SubscriptionUsage(
      upload: parts['upload'] ?? 0,
      download: parts['download'] ?? 0,
      total: parts['total'] ?? 0,
      expire: parts['expire'] ?? 0,
    );
  }
}

class Subscription {
  final String id;
  final String name;
  final String url;
  final DateTime addedAt;
  final DateTime? updatedAt;
  final String format;
  final String? title;
  final String? announce;
  final String? supportUrl;
  final String? webPageUrl;
  final int? updateIntervalHours;
  final bool hwidActive;
  final bool hwidLimitReached;
  final bool hwidNotSupported;
  final SubscriptionUsage? usage;
  final List<ProxyProfile> profiles;
  final String? error;

  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    required this.addedAt,
    this.updatedAt,
    this.format = 'unknown',
    this.title,
    this.announce,
    this.supportUrl,
    this.webPageUrl,
    this.updateIntervalHours,
    this.hwidActive = false,
    this.hwidLimitReached = false,
    this.hwidNotSupported = false,
    this.usage,
    this.profiles = const [],
    this.error,
  });

  String get displayName =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : name;

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? addedAt,
    DateTime? updatedAt,
    String? format,
    String? title,
    String? announce,
    String? supportUrl,
    String? webPageUrl,
    int? updateIntervalHours,
    bool? hwidActive,
    bool? hwidLimitReached,
    bool? hwidNotSupported,
    SubscriptionUsage? usage,
    List<ProxyProfile>? profiles,
    String? error,
    bool clearError = false,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      format: format ?? this.format,
      title: title ?? this.title,
      announce: announce ?? this.announce,
      supportUrl: supportUrl ?? this.supportUrl,
      webPageUrl: webPageUrl ?? this.webPageUrl,
      updateIntervalHours: updateIntervalHours ?? this.updateIntervalHours,
      hwidActive: hwidActive ?? this.hwidActive,
      hwidLimitReached: hwidLimitReached ?? this.hwidLimitReached,
      hwidNotSupported: hwidNotSupported ?? this.hwidNotSupported,
      usage: usage ?? this.usage,
      profiles: profiles ?? this.profiles,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'addedAt': addedAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'format': format,
        'title': title,
        'announce': announce,
        'supportUrl': supportUrl,
        'webPageUrl': webPageUrl,
        'updateIntervalHours': updateIntervalHours,
        'hwidActive': hwidActive,
        'hwidLimitReached': hwidLimitReached,
        'hwidNotSupported': hwidNotSupported,
        'usage': usage?.toJson(),
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'error': error,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final rawProfiles = (json['profiles'] as List?) ?? const [];
    return Subscription(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Subscription',
      url: json['url']?.toString() ?? '',
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      format: json['format']?.toString() ?? 'unknown',
      title: json['title']?.toString(),
      announce: json['announce']?.toString(),
      supportUrl: json['supportUrl']?.toString(),
      webPageUrl: json['webPageUrl']?.toString(),
      updateIntervalHours: (json['updateIntervalHours'] as num?)?.toInt(),
      hwidActive: json['hwidActive'] == true,
      hwidLimitReached: json['hwidLimitReached'] == true,
      hwidNotSupported: json['hwidNotSupported'] == true,
      usage: json['usage'] is Map
          ? SubscriptionUsage.fromJson(
              (json['usage'] as Map).cast<String, dynamic>())
          : null,
      profiles: rawProfiles
          .whereType<Map>()
          .map((item) => ProxyProfile.fromJson(item.cast<String, dynamic>()))
          .toList(),
      error: json['error']?.toString(),
    );
  }
}
