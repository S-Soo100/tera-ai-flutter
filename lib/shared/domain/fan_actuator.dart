/// 두 팬의 명령·설정·알림 식별자를 한 곳에서 구분한다.
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
