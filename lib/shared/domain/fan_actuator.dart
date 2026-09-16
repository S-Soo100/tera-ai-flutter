/// 두 팬의 명령·설정·알림 식별자를 한 곳에서 구분한다.
///
/// LED는 여기 없다 — 펌웨어가 `led_on`의 `duration_ms`를 읽지 않아(2026-09-16
/// 회신 §1.4, MOSFET 보드는 타이머 슬롯 없음) LED 작동 시간은 A안(앱 제거)으로
/// 확정했다. `duration_ms`를 처리하는 action은 `mist`/`fan_on`/`fan2_on`뿐이다.
enum FanActuator {
  ventilation('fan', 'module_actuator_fan'),
  cooling('fan2', 'device_cool_fan');

  const FanActuator(this.wire, this.labelKey);
  final String wire;
  final String labelKey;

  String get onAction => '${wire}_on';
  String get offAction => '${wire}_off';
  List<String> get actions => [onAction, offAction, '${wire}_toggle'];

  // 기존 환기팬 키/알림 ID를 유지해 업데이트 전 예약도 취소 가능하게 한다.
  String storageKey(String deviceId) =>
      this == ventilation ? deviceId : '$deviceId:fan2';
}
