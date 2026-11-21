String formatBytes(num? bytes, {int decimals = 1}) {
  if (bytes == null || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fixed = unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(decimals);
  return '$fixed ${units[unit]}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String formatDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

String formatRelative(DateTime? date, {String languageCode = 'ru'}) {
  if (date == null) {
    return switch (languageCode) {
      'en' => 'never',
      'de' => 'nie',
      _ => 'никогда',
    };
  }
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) {
    return switch (languageCode) {
      'en' => 'just now',
      'de' => 'gerade eben',
      _ => 'только что',
    };
  }
  if (diff.inMinutes < 60) {
    return switch (languageCode) {
      'en' => '${diff.inMinutes} min ago',
      'de' => 'vor ${diff.inMinutes} Min.',
      _ => '${diff.inMinutes} мин назад',
    };
  }
  if (diff.inHours < 24) {
    return switch (languageCode) {
      'en' => '${diff.inHours} h ago',
      'de' => 'vor ${diff.inHours} Std.',
      _ => '${diff.inHours} ч назад',
    };
  }
  return switch (languageCode) {
    'en' => '${diff.inDays} d ago',
    'de' => 'vor ${diff.inDays} T.',
    _ => '${diff.inDays} дн назад',
  };
}
