enum LogLevel { debug, info, warn, error }

extension LogLevelX on LogLevel {
  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String source;
  final String message;

  const LogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
  });

  String get formatted {
    final t = time;
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    return '$stamp  ${level.label.padRight(5)}  [$source]  $message';
  }
}
