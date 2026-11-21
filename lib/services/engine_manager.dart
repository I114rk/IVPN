import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/models/engine.dart';
import '../core/models/log_entry.dart';
import 'log_service.dart';

class EngineManager {
  EngineManager(this._logs);

  final LogService _logs;
  Process? _process;
  EngineState _state = const EngineState();
  final StreamController<EngineState> _controller =
      StreamController<EngineState>.broadcast();

  EngineState get state => _state;
  Stream<EngineState> get states => _controller.stream;
  int? get pid => _process?.pid;
  bool get isRunning => _state.isRunning;

  Future<void> start({
    required EngineType type,
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    await stop(silent: true);
    _emit(EngineState(type: type, status: EngineStatus.starting));

    Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );
    } catch (error) {
      _emit(
        EngineState(
          type: type,
          status: EngineStatus.error,
          message: 'Не удалось запустить ядро: $error',
        ),
      );
      rethrow;
    }

    _process = process;
    _logs.info(
      type.name,
      'Запуск PID ${process.pid}: ${_basename(executable)} ${arguments.join(' ')}',
    );
    final errorLines = <String>[];
    void rememberError(String line, LogLevel level) {
      final clean = _stripAnsi(line).trim();
      final lower = clean.toLowerCase();
      if (level != LogLevel.error &&
          !lower.contains('failed') &&
          !lower.contains('failure')) {
        return;
      }
      errorLines.add(clean);
      if (errorLines.length > 3) errorLines.removeAt(0);
    }

    final stdoutDone = _pipe(
      process.stdout,
      type,
      LogLevel.info,
      onLine: rememberError,
    );
    final stderrDone = _pipe(
      process.stderr,
      type,
      LogLevel.warn,
      onLine: rememberError,
    );

    var exited = false;
    process.exitCode.then((code) async {
      exited = true;
      try {
        await Future.wait([stdoutDone, stderrDone]);
      } catch (_) {}
      if (!identical(_process, process)) return;
      _process = null;
      if (code == 0) {
        _emit(EngineState(type: type, status: EngineStatus.stopped));
      } else {
        _emit(
          EngineState(
            type: type,
            status: EngineStatus.error,
            message: errorLines.isEmpty
                ? 'Ядро завершилось с кодом $code'
                : 'Ядро завершилось с кодом $code:\n${errorLines.last}',
          ),
        );
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!exited && identical(_process, process)) {
      _emit(
        EngineState(
          type: type,
          status: EngineStatus.running,
          pid: process.pid,
          startedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> stop({bool silent = false}) async {
    final process = _process;
    if (process == null) {
      if (!silent) {
        _emit(EngineState(type: _state.type, status: EngineStatus.stopped));
      }
      return;
    }

    _emit(_state.copyWith(status: EngineStatus.stopping));
    try {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 6));
    } catch (_) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    if (identical(_process, process)) _process = null;
    if (!silent) {
      _emit(EngineState(type: _state.type, status: EngineStatus.stopped));
    }
  }

  Future<void> _pipe(
    Stream<List<int>> stream,
    EngineType type,
    LogLevel fallback, {
    void Function(String line, LogLevel level)? onLine,
  }) async {
    await stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
          final text = line.trimRight();
          if (text.trim().isEmpty) return;
          final lower = text.toLowerCase();
          var level = fallback;
          if (lower.contains('error') || lower.contains('fatal')) {
            level = LogLevel.error;
          } else if (lower.contains('warn')) {
            level = LogLevel.warn;
          } else if (lower.contains('debug')) {
            level = LogLevel.debug;
          }
          _logs.add(level, type.name, text);
          onLine?.call(text, level);
        });
  }

  void _emit(EngineState state) {
    _state = state;
    _controller.add(state);
  }

  static String _basename(String path) =>
      path.split(Platform.pathSeparator).last;

  static String _stripAnsi(String value) =>
      value.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');

  void dispose() {
    _controller.close();
  }
}
