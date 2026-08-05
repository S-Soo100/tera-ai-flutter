/// 홈 탭 서브탭 식별자. PRD §3.3 2구분 세그먼트 탭.
enum HomeSubTab { control, timeline }

/// PRD §5-1.1 "기기 연동 모드에 따른 홈 탭 UI 자동 전환".
///
/// 세트가 가진 기기 조합에서 도출되며, 홈 탭의 모든 분기(상단 영역 종류,
/// 서브탭 활성/비활성, 기본 선택 탭)가 이 값 하나에서 나온다.
enum DeviceMode {
  /// 통합 세트 — 캠 + 제어기 둘 다.
  integrated,

  /// 사육장 단품 — 제어기만. 상단은 개체 프로필 카드로 대체.
  cageOnly,

  /// 캠 단품 — 캠만. 사육장 제어 서브탭 비활성.
  camOnly,

  /// 기기 미연동 — 사육장만 등록된 상태. PRD 미명세이나 등록 직후 실재한다.
  none;

  /// 사육장 제어 서브탭 활성 여부.
  bool get controlEnabled =>
      this == DeviceMode.integrated || this == DeviceMode.cageOnly;

  /// 타임라인 서브탭 활성 여부.
  bool get timelineEnabled =>
      this == DeviceMode.integrated || this == DeviceMode.camOnly;

  /// 상단 고정 영역에 라이브 비디오를 띄우는가. false면 개체 프로필 카드.
  bool get showsLiveVideo =>
      this == DeviceMode.integrated || this == DeviceMode.camOnly;

  /// 진입 시 기본 선택 서브탭. 활성 탭이 없으면 control(빈 상태 표시용).
  HomeSubTab get defaultTab =>
      controlEnabled ? HomeSubTab.control : HomeSubTab.timeline;
}
