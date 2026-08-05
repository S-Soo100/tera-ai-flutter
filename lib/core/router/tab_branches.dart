/// 바텀 네비 탭 경로. PRD 목업 바텀 네비 = 홈/통계/마이크레/커뮤니티 4탭.
///
/// 순서가 곧 탭 인덱스이고 `StatefulShellRoute`의 브랜치 순서와 일치해야 한다.
/// 라우터 본문에서 분리한 이유는 이 테이블만 단위 테스트하기 위해서다.
const List<String> kHomeTabPaths = [
  '/home',
  '/stats',
  '/my-pets',
  '/community',
];

/// [kHomeTabPaths]와 같은 순서의 i18n 라벨 키.
const List<String> kHomeTabLabelKeys = [
  'tab_home',
  'tab_stats',
  'tab_my_pets',
  'tab_community',
];

/// 탭에서 내렸지만 화면·딥링크는 유지하는 경로.
/// 삭제하지 않는 이유: 되돌리기 비용을 낮추고 홈 재구성 전까지 기능 공백을
/// 만들지 않기 위함. 하위 경로(`/crecam/cameras/pair` 등)도 그대로 산다.
const List<String> kLegacySecondaryPaths = ['/crecam', '/smart-cage'];

/// 인증 없이 접근 가능한 경로.
const List<String> kPublicPaths = [
  '/splash',
  '/home',
  '/stats',
  '/wiki',
  '/community',
  '/search',
  '/login',
  '/signup',
  '/verify-email',
  '/error',
];
