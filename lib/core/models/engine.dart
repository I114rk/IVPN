enum EngineType { singbox, xray, openvpn }

enum EngineStatus { stopped, starting, running, stopping, error }

class EngineState {
  final EngineType type;
  final EngineStatus status;
  final String? message;
  final int? pid;
  final DateTime? startedAt;

  const EngineState({
    this.type = EngineType.singbox,
    this.status = EngineStatus.stopped,
    this.message,
    this.pid,
    this.startedAt,
  });

  bool get isBusy =>
      status == EngineStatus.starting || status == EngineStatus.stopping;
  bool get isRunning => status == EngineStatus.running;

  EngineState copyWith({
    EngineType? type,
    EngineStatus? status,
    String? message,
    int? pid,
    DateTime? startedAt,
    bool clearMessage = false,
    bool clearPid = false,
    bool clearStartedAt = false,
  }) {
    return EngineState(
      type: type ?? this.type,
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      pid: clearPid ? null : (pid ?? this.pid),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }
}
