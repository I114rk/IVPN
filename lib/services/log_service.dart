import 'dart:async';
import 'dart:io';

import '../core/models/log_entry.dart';
import 'storage_service.dart';

class LogService {
  LogService(this._storage);

  final StorageService _storage;
  final List<LogEntry> _entries = [];
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  static const int maxEntries = 4000;

  List<LogEntry> get entries => List.unmodifiable(_entries);
  Stream<LogEntry> get stream => _controller.stream;

  void add(LogLevel level, String source, String message) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    _controller.add(entry);
    _append(entry);
  }

  void debug(String source, String message) =>
      add(LogLevel.debug, source, message);
  void info(String source, String message) =>
      add(LogLevel.info, source, message);
  void warn(String source, String message) =>
      add(LogLevel.warn, source, message);
  void error(String source, String message) =>
      add(LogLevel.error, source, message);

  void clear() {
    _entries.clear();
    try {
      if (_storage.logFile.existsSync()) {
        _storage.logFile.deleteSync();
      }
    } catch (_) {}
  }

  Future<void> _append(LogEntry entry) async {
    try {
      await _storage.logFile.writeAsString(
        '${entry.formatted}\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {}
  }

  void dispose() {
    _controller.close();
  }
}
