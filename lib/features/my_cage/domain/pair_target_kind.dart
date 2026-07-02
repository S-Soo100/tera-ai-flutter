/// WiFi 프로비저닝 대상 기기 종류.
///
/// 사육장·카메라가 동일한 BLE Service UUID를 광고하므로, 스캔 결과의
/// 광고 이름(advName/platformName)으로 종류를 구분한다.
enum PairTargetKind {
  /// 사육장 모듈 (광고 이름 `terra-iot`).
  device,

  /// 게코캠 카메라 (광고 이름 `FB2_P4_CAM`).
  camera;

  /// 이 종류에 해당하는 BLE 광고 이름.
  String get advertisedName {
    switch (this) {
      case PairTargetKind.device:
        return 'terra-iot';
      case PairTargetKind.camera:
        return 'FB2_P4_CAM';
    }
  }

  /// 스캔 결과의 광고 이름이 이 종류와 일치하는지.
  /// 접두 매칭(startsWith) — 펌웨어가 이름 뒤에 식별자를 붙이는 경우 대응.
  bool matchesAdvName(String? advName) {
    if (advName == null || advName.isEmpty) return false;
    return advName == advertisedName || advName.startsWith(advertisedName);
  }
}
