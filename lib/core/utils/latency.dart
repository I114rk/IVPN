import 'dart:io';

Future<int?> measureLatency(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final stopwatch = Stopwatch()..start();
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  } catch (_) {
    return null;
  } finally {
    socket?.destroy();
  }
}
