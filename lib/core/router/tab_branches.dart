/// 바텀 네비 탭 경로. PRD §2.1(2026-09-02 개정) = 홈/카메라/마이크레/커뮤니티 4탭.
/// 통계 탭은 폐지 — 온습도 상세(`/env-detail`)가 흡수한다.
///
/// 순서가 곧 탭 인덱스이고 `StatefulShellRoute`의 브랜치 순서와 일치해야 한다.
/// 라우터 본문에서 분리한 이유는 이 테이블만 단위 테스트하기 위해서다.
const List<String> kHomeTabPaths = [
  '/home',
  '/crecam',
  '/my-pets',
  '/community',
];

/// [kHomeTabPaths]와 같은 순서의 i18n 라벨 키.
const List<String> kHomeTabLabelKeys = [
  'tab_home',
  'tab_camera',
  'tab_my_pets',
  'tab_community',
];

/// [kHomeTabPaths]와 같은 순서의 Figma 아이콘 에셋명(`assets/icons/{name}.svg`).
///
/// Figma Navigation(668:2485)의 원본 SVG(2026-09-04 사용자 제공) — 활성/비활성이
/// 같은 글리프에 색만 다르므로 아이콘 쌍이 아니라 **단일 에셋**이다.
/// 라우터가 독 항목을 여기서 **파생**한다 — 경로·라벨·아이콘이 세 곳에
/// 병렬로 흩어지면 탭 하나를 고칠 때 한 곳이 조용히 어긋난다.
const List<String> kHomeTabIconAssets = [
  'nav_home',
  'nav_camera',
  'nav_mycre', // Figma `fertile` — 구 발바닥/임시 별을 대체(2026-09-04).
  'nav_community',
];

/// 탭에서 내렸지만 화면·딥링크는 유지하는 경로.
/// `/crecam`은 2026-09-02 카메라 탭으로 **승격** — 여기서 뺀다. 하위 경로
/// (`/crecam/cameras/pair` 등)는 셸 밖 최상위 라우트로 그대로 산다.
const List<String> kLegacySecondaryPaths = ['/smart-cage'];

/// 인증 없이 접근 가능한 경로.
/// `/crecam`은 탭이지만 **비공개**(카메라는 계정 종속 — 비로그인이면 /login).
const List<String> kPublicPaths = [
  '/splash',
  '/home',
  '/community',
  // 디자인 테스트 공개(전부 mock, 하위 a/b/c 포함 — redirect가 startsWith로
  // 처리). 테스트 종료 시 이 줄 + 로그인 화면 진입점 1줄만 지우면 숨는다:
  // docs/design-test-rollout-plan.md §2.4
  '/design-test',
  '/login',
  '/signup',
  '/verify-email',
  '/error',
];
