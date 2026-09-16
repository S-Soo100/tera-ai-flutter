/// 작동 시간(`duration_ms`)을 걸 수 있는 액추에이터의 명령·설정·알림 식별자를
/// 한 곳에서 구분한다. 이름은 역사적으로 팬이지만 2026-09-16부터 LED 작동
/// 시간도 같은 문법(`led_on` + `duration_ms`, 펌웨어 자동 OFF)을 쓴다 —
/// 서버·펌웨어 계약 확인 전 미리 구현(요청서
/// `docs/handoffs/2026-09-16-server-request-led-timer-schedule-payload.md` §1).
enum FanActuator {
  ventilation('fan', 'module_actuator_fan'),
  cooling('fan2', 'device_cool_fan'),
  led('led', 'module_actuator_led');

  const FanActuator(this.wire, this.labelKey);
  final String wire;
  final String labelKey;

  String get onAction => '${wire}_on';
  String get offAction => '${wire}_off';
  List<String> get actions => [onAction, offAction, '${wire}_toggle'];

  // 기존 환기팬 키/알림 ID를 유지해 업데이트 전 예약도 취소 가능하게 한다.
  String storageKey(String deviceId) =>
      this == ventilation ? deviceId : '$deviceId:$wire';
}
