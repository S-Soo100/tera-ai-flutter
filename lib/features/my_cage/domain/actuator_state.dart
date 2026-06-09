enum ActuatorState { on, off, unavailable }

ActuatorState actuatorFromString(String? s) {
  switch (s) {
    case 'ON':
      return ActuatorState.on;
    case 'OFF':
      return ActuatorState.off;
    case 'N/A':
    default:
      return ActuatorState.unavailable;
  }
}

class HeaterState {
  final ActuatorState state;
  final bool locked;

  const HeaterState({required this.state, required this.locked});

  factory HeaterState.fromJson(Map<String, dynamic> j) => HeaterState(
        state: actuatorFromString(j['state'] as String?),
        locked: j['locked'] as bool? ?? false,
      );
}

/// 히터 토글 액션 결과 (rc + 새 상태)
class HeaterToggleResult {
  final HeaterState state;
  final int rc; // 0=성공, -1=거부됨(latch 등)
  final String rawBody;

  const HeaterToggleResult({
    required this.state,
    required this.rc,
    required this.rawBody,
  });
}
