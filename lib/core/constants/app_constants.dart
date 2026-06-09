class AppConstants {
  AppConstants._();

  static const List<String> categories = [
    '도마뱀',
    '뱀',
    '거북',
    '양서류',
  ];

  static const List<String> featuredSpeciesIds = [
    'leopard-gecko',
    'crested-gecko',
    'fat-tailed-gecko',
  ];

  static const Map<String, String> featuredSpeciesNames = {
    'leopard-gecko': '레오파드 게코',
    'crested-gecko': '크레스티드 게코',
    'fat-tailed-gecko': '펫테일 게코',
  };

  // TEMP: live stream demo (임시 — 추후 카메라별 URL로 교체)
  // 라이브 캠과 ESP32 제어 모듈은 비밀번호가 서로 다름 — 절대 동기화하지 말 것.
  static const String tempLiveStreamUrl =
      'http://mycamgb.iptime.org:8080/stream';
  static const String tempLiveStreamUser = 'admin';
  static const String tempLiveStreamPass = 'ChangeMe!StrongPass2026';
}
