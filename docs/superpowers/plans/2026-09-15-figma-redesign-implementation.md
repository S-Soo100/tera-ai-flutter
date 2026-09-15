# Figma 전면 재설계 Implementation Plan

> **For agentic workers:** 실행 시 `superpowers:executing-plans`를 적용해 작업 단위별로 진행한다. 프로젝트 CAOF에 따라 기존 feature 수정은 메인이 맡고, 새 화면·새 RLS 정책 등 Critical 작업은 승인된 범위를 `flutter-dev`에 분리한다. 지금은 문서 저장 단계이며 구현 에이전트를 실행하지 않는다.

**Goal:** 사용자 승인 기획대로 Home·Camera·MyCre·연결·관리·등록 UI와 데이터 동작을 교체하고 Figma 실측 대조로 검수한다.

**Architecture:** Riverpod + Repository + GoRouter를 유지한다. Figma 원본과 runtime 에셋을 분리하고, 사용자 영상 숨김·로컬 메모·개체 연결 이력을 서로 다른 책임으로 구현한다. 기존 서버 명령을 재사용하며 원본 데이터 생산·기기 소유권 계약은 담당자 합의 후 연결한다.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, Supabase, Hive, flutter_secure_storage, flutter_blue_plus, flutter_webrtc, video_player, fl_chart, easy_localization.

**Spec:** [사용자 확정 기획](../specs/2026-09-15-figma-redesign-approved-design.md). 담당·서버 선행조건은 [업무 분장표](../../handoffs/2026-09-15-redesign-server-work-split.md)가 단일 기준이다.

## Global Constraints

- 확정 상태: 2026-09-15 사용자 승인. 이번 커밋은 문서만 저장하며 코드·운영 DB·외부 메시지는 변경하지 않는다.
- 신규 구현 전 최신 `CLAUDE.md` 및 실행 중인 다른 작업·git status를 확인한다. FCM 관련 최신 변경을 덮거나 별도 하이라이트 배치 체계를 만들지 않는다.
- 배경 **#FFFFFF**, 카드·버튼 기본 면 **#F4F4F4**. Material 기본 tint/elevation/최소 크기에 의한 Figma 오차를 확인한다.
- 색·문자열 하드코딩 금지. Riverpod/Repository/GoRouter 사용. 새 로딩은 기존 스켈레톤 규칙을 따른다.
- 원본 `assets/figma/2026-09-15/` 수정 금지. SVG 70개·PNG 4개 SHA-256 보존.
- 드롭다운 헤더·목록은 그룹 소속이면 그룹명, 그룹이 없으면 Home=사육장, Camera=카메라, MyCre=도마뱀 이름. 실제 선택·조회·제어 대상은 각 항목의 ID로 유지한다.
- 신규 기본 이름은 `사육 환경 1`/`사육장 1`/`카메라 1`부터 번호를 붙인다. 사용 중인 이름은 건너뛰며 기존 저장 이름은 자동 변경하지 않는다. 그룹 생성 순서 번호와 표시명을 분리한다.
- 그룹당 사육장 1개·카메라 1개·도마뱀 1마리. 개체 신규 등록은 크레스티드 게코.
- 기기·개체·그룹 이름 최대 10자·동일 계정 중복 금지. LCD 최대 20자·중복 허용·기기 이름과 독립.
- 메모는 계정별 로컬, 북마크는 기존 Supabase 동기화, 영상 삭제는 사용자 숨김. R2·활동 원본 유지.
- MyCre 자정 경계·월요일 주간, 관측 완료 0 포함·미수집 제외. 기존 사용자 과거 기록 승계.
- LED 20~100%/10% 단위. 홈 분무 3초·5초 중복 방지. 냉각팬 fan2는 전달 계약 사용.
- 전체 전원 버튼 ON 고정 표시는 기기 관리의 임시 UI에만 적용한다.
- 코드 변경 커밋마다 버전·한글 CHANGELOG, analyze 오류 0·관련 테스트. push는 요청 시에만 한다.
- 빌드/수정 반복은 프로젝트 규칙상 최대 3회. 기능과 무관한 리팩터링·기존 원본 제거를 섞지 않는다.

## 0. 의존 관계와 실행 단위

| 단계 | 산출물 | 선행 조건 |
|---|---|---|
| 1 | 화면별 측정표, 에셋 매핑, 공통 UI | 없음 |
| 2 | 앱 전용 데이터 모델·migration·계약 fixture | A2/A3 즉시, A4/T1/T2는 담당 회신과 통합 |
| 3 | Home·환경·제어·일정 | 1, 기존 API, fan2 계약. 과거 정확 평균은 T3 |
| 4 | 기기 연결·그룹·개체 관리 | 1/2, claim·unlink 경로는 T1/T2/T4 |
| 5 | Camera·플레이어·메모·숨김 | 1/A3, 공개 배치는 P2 |
| 6 | MyCre·연결 이력·legacy 승계 | 1/2, P1 활동 구간·coverage |
| 7 | 화면 대조·실기기·회귀·출시 기록 | 각 기능 통합 완료 |

3/5의 독립 앱 작업은 외부 회신 전에 진행할 수 있다. 미지원 API를 가짜 성공으로 연결하지 않는다. 별도 담당 요청 문서는 이미 준비돼 있으나 발송은 사용자 요청 때 한다.

## 1. 디자인 기준·에셋 연결

### Task 1A — 화면과 에셋의 추적 가능한 기준 확정

**Files**
- Read: `assets/figma/2026-09-15/README.md`, `manifest.json`.
- Create: `docs/design-audits/2026-09-15-redesign-frame-matrix.md`, `docs/design-audits/2026-09-15-redesign-asset-map.json`.
- Modify: `lib/shared/widgets/figma_icon.dart`의 `FigmaIcon`·`FigmaIcons`, `pubspec.yaml`.
- Create when needed: `assets/icons/redesign_v2/`의 runtime 사본. 필요한 변환별 원본 path/hash를 asset map에 기록.

- [ ] `rg -n 'class FigmaIcons|class FigmaIcon' lib`로 현재 registry와 renderer의 실제 위치를 확정한다. duplicate registry를 새로 만들지 않는다.
- [ ] Talk to Figma로 확정 기획 §1 노드를 읽고 상태별 frame ID, 너비, safe area, font/line height, parent/icon bounds, padding, radius, fills를 측정표에 기록한다. 추출되지 않은 auto-layout 값은 화면 bounds와 시각 검증으로 확인한다.
- [ ] 아이콘별 역할·ON/OFF·Figma node·원본 파일·runtime 파일·viewBox·표시 크기를 매핑한다. 이름 접미사만으로 역할을 정하지 않는다.
- [ ] SVG 마스크·여백·다색 렌더를 실제 Flutter에서 확인한다. 원본 변환 필요 시 runtime 사본만 변경한다.
- [ ] PNG Empty 345×227, favicon 56×56의 3배율을 등록한다. 필요한 이미지 크기보다 해상도가 낮으면 별도 디자인 보완으로 기록하고 완료로 숨기지 않는다.
- [ ] 원본 해시 불변과 깨진 에셋 경로 0을 확인하고 에셋 연결 단위로 커밋한다.

**Acceptance:** 각 보이는 아이콘은 source node/file까지 역추적 가능. ‘대충 같은 아이콘’ 대체 없음. fan/LED/schedule 팝업은 Figma 미제작 보완 화면으로 분리해 검수한다.

### Task 1B — 공통 레이아웃·상태·흰 상단

**Files:** `lib/core/theme/glass_palette.dart`, `lib/core/theme/app_theme.dart`, `lib/shared/widgets/glass_dock.dart`, `lib/shared/widgets/glass_tab_header.dart`, `lib/features/home/presentation/widgets/home_header_bar.dart`, shell/router의 실제 소비처.

- [ ] `rg -n 'class GlassTabShell|WallpaperBackground|appBarTheme|surfaceTintColor' lib`로 상단 회색의 렌더 경로를 추적한다. Android 재현 화면을 먼저 기록한다.
- [ ] palette 역할색과 Figma 실측 크기를 공통 컴포넌트에 적용한다. ThemeExtension 변경은 생성자/dark/light/copyWith/lerp까지 일치시킨다.
- [ ] 헤더·dock 고정, body 단일 스크롤, 바닥/키보드 inset을 적용한다. 버튼 저장 중 잠금·입력 보존·미저장 이탈 정책을 공유 처리한다.
- [ ] Android 스크롤 전·중·후의 상단 흰색, 긴 이름, text scale·작은 화면을 실제 렌더로 확인한다. 화면 스타일만 바꾼 곳은 구현을 복제하는 불필요한 단위 테스트 대신 비교 이미지를 남긴다.

## 2. 데이터 구조·계약 준비

### Task 2A — 현재 schema와 외부 계약 경계 고정

**Files:** 업무 분장표, 기존 `supabase/migrations/`, `lib/features/my_pets/data/supabase_pet_repository.dart`, `lib/features/my_cage/data/camera_repository.dart`, `supabase_module_control_repository.dart`, `lib/features/home/data/enclosure_set_repository.dart`.

- [ ] 실제 linked project·remote migration history·대상 테이블 column/type/index/FK/RLS·`assign_pet_to_enclosure` 정의를 읽기 전용으로 확인한다. 비밀값/개인 행을 문서에 저장하지 않는다.
- [ ] 현재 기기 삭제 cascade, clip owner 접근, 웹/서버의 연결 UPDATE 경로를 T1/T2 회신에 대조한다.
- [ ] 아래 앱 모델의 경계는 유지하되 실제 SQL 타입·RPC 이름은 이 조회 결과에 맞춰 migration에서 정의한다. 다른 팀이 소유한 raw table/view 교체는 별도 계약 없이 실행하지 않는다.
- [ ] P1/T3/P2의 입력 fixture를 받아 실제 응답과 비교한다. 회신이 없는 계약은 `외부 계약 대기`로 명시하고 UI fixture만을 운영 완료 증거로 사용하지 않는다.

### Task 2B — 사용자 숨김·로컬 메모·연결 이력의 저장 책임 분리

**Create**
- `lib/features/my_cage/domain/clip_memo.dart`, `data/clip_memo_repository.dart`, `data/clip_visibility_repository.dart`.
- `lib/features/my_pets/domain/pet_camera_assignment.dart`, `data/pet_camera_assignment_repository.dart`.
- `supabase/migrations/20260915010000_redesign_app_data.sql`(작성 당시 remote history와 충돌하면 다음 고유 timestamp 사용).
- `test/features/my_cage/clip_memo_repository_test.dart`, `clip_visibility_repository_test.dart`, `test/features/my_pets/pet_camera_assignment_history_test.dart`.

**Interface contracts — 새 코드 작성 시 적용할 경계**

```dart
enum AssignmentOrigin { recorded, legacyInherited }

class ClipMemo {
  const ClipMemo({
    required this.clipId,
    required this.text,
    required this.colorIndex,
    required this.updatedAt,
  });
  final String clipId;
  final String text;
  final int colorIndex;
  final DateTime updatedAt;
}

// 메모는 서버로 전송하지 않는다. accountId는 인증 provider에서 주입한다.
abstract interface class ClipMemoRepository {
  Future<ClipMemo?> read(String accountId, String clipId);
  Future<void> save(String accountId, String clipId, String text);
  Future<void> remove(String accountId, String clipId);
}
// ClipMemo: clipId, text, colorIndex(0..5), updatedAt.
// 새 색 배정은 직전 색을 제외하며 업데이트는 기존 colorIndex를 유지한다.

abstract interface class ClipVisibilityRepository {
  Future<Set<String>> hiddenClipIds(String accountId);
  Future<void> hide(String accountId, String clipId);
}
// 실제 write owner는 DB auth.uid()로 검증한다. 위 accountId는 앱 캐시 격리 키다.
```

메모 repository의 공통 수락 테스트는 새 파일에서 아래 형태로 실행한다. `buildRepository`는 각 테스트에서 임시 Hive 저장소를 쓰는 실제 구현을 반환하며 운영 box를 열지 않는다.

```dart
void verifyMemoContract(ClipMemoRepository Function() buildRepository) {
  test('색상 유지, 연속 색 제외, 계정 격리', () async {
    final repo = buildRepository();
    await repo.save('account-a', 'clip-1', '첫 메모');
    final first = (await repo.read('account-a', 'clip-1'))!;
    await repo.save('account-a', 'clip-2', '다음 메모');
    final second = (await repo.read('account-a', 'clip-2'))!;
    expect(second.colorIndex, isNot(first.colorIndex));
    await repo.save('account-a', 'clip-1', '수정');
    expect((await repo.read('account-a', 'clip-1'))!.colorIndex,
        first.colorIndex);
    expect(await repo.read('account-b', 'clip-1'), isNull);
  });
}
```

- [ ] 먼저 테스트에서 메모 저장/수정/북마크 해제/계정 전환, 연속 색 금지, 사용자 숨김 재조회 fixture를 만든다.
- [ ] 숨김은 `(user_id, clip_id)` 유일성·owner RLS·원본 접근 검증을 가진 추가 테이블로 작성한다. 원본 activity view의 RLS를 바꾸지 않는다.
- [ ] 메모 key는 account+clip, 마지막 색 key도 account별로 둔다. 로그아웃이나 계정 변경 후 다른 owner cache를 노출하지 않는다.
- [ ] 연결 이력은 account/pet/camera, `[start,end)`, origin을 저장한다. 기존 사용자는 migration 전 조회 범위·출처를 승계하고, 신규 개체에는 적용하지 않는다.
- [ ] 시작/종료 구간 생성·빈 그룹 제거·이름 할당은 T1과 합의한 원자 write 경로에서 수행한다. 서버 clock을 사용한다.
- [ ] 두 사용자 fixture로 읽기/쓰기 거부·clip 원본 보존·집계 불변을 SQL transaction 테스트하고 rollback한다. production에 fixture를 영구 삽입하지 않는다.
- [ ] 해당 테스트 실행 후 데이터 준비 단위를 커밋한다. 운영 적용은 별도 실행 단계이며 본 문서 저장 중에는 하지 않는다.

### Task 2C — 카탈로그 대조·기존 데이터 승계

**Files:** `assets/data/morphs/crested-gecko.json`, `lib/features/wiki/data/care_info_repository.dart`, `lib/features/home/data/species_repository.dart`, `lib/features/my_pets/data/supabase_pet_repository.dart`.

- [ ] DB/로컬 카탈로그를 ID·이름·유전자·모프·라인브리딩 특성별로 비교한 목록을 만든다. 17 대 23 항목 차이를 문서화한다.
- [ ] 중복/조합/명칭 차이를 출처로 검증하고 등록용 stable ID↔표시명 매핑을 만든다. 명칭이 비슷하다는 이유로 서로 다른 trait를 병합하지 않는다.
- [ ] 신규 선택에는 크레스티드만 노출한다. 기존 다른 종·모프 문자열은 읽기/수정 시 보존하며 강제로 초기화하지 않는다.
- [ ] legacy 연결 migration은 개체별 현재 연결과 기존 조회 결과를 비교하고 재실행 시 중복 이력이 생기지 않도록 한다. 기존 전체 카메라 리포트를 개체별 실제 관측으로 오인한 재배정은 막는다.

## 3. Home·환경·제어·일정

**Modify:** `lib/features/home/presentation/home_screen.dart`, `widgets/cage_control_grid.dart`, `cage_control_actions.dart`, `widgets/fan_duration_sheet.dart`, `env_detail_screen.dart`, `env_detail_providers.dart`, `routine_settings_screen.dart`, `widgets/schedule_editor_sheet.dart`, `lib/features/my_cage/domain/telemetry_reading.dart`, `device_command.dart`, `lib/shared/domain/actuator_marker.dart`, `control_log.dart`, `lib/features/home/domain/schedule.dart`, timer/notification의 해당 fan 소비처, `lib/features/my_cage/presentation/widgets/lcd_setting_tile.dart`.

- [ ] Home 사육장 없음/사육장만/통합/기기별 오프라인 상태를 fixture로 검증하고 단일 스크롤 배치를 적용한다.
- [ ] telemetry 모델에 fan2를 추가하고 null→unavailable을 보존한다. command·schedule enum과 wire 역변환·off counterpart·구간 UI·marker/log 종류에 fan2를 함께 등록한다.
- [ ] fan 실행 로직을 대상 actuator로 분리한다. 환기팬과 냉각팬의 선택 저장·진행 중 타이머·알림 취소가 섞이지 않게 식별자를 확장한다. 명시 시작 전에는 명령 0회.
- [ ] LED 선택창 20~100/10% 단위, 실제 tile은 보고값을 표시한다. 보고값이 선택 단계 사이면 UI 선택값만 가장 가까운 단계로 초기화하며 명시 적용 전에는 장치 상태를 바꾸지 않는다.
- [ ] LCD maxLength와 카운터를 20으로 바꾸고 이름 중복 검증을 적용하지 않는다. 저장 대상을 이름 수정과 분리한다.
- [ ] 온습도 결측 선 끊김·과거 가중 평균·요일 min/max·사용자 scroll 보존을 적용한다. 제어 로그는 승인된 근사치 계산, missing 값의 우측 칸을 `--`로 유지하고 원본 실행 결과를 확인한다.
- [ ] 제어 log 계산은 시작/종료 짝을 시간순으로 처리하고 표시는 최신순. 자정을 넘는 종료도 필요한 직전 시작을 조회해 매칭하며 없으면 변화량 `--`.
- [ ] 일정 기존 자료를 유지하고 fan2 on/off·구간·guard 구분을 확장한다. 수정에서 서버가 허용하지 않는 action 변경을 보내지 않는다. 시간/요일 변경과 구간 양쪽 활성화/삭제 실패를 함께 검증한다.
- [ ] 분무 3초·5초 잠금, 팬 off 취소, 냉각팬 null, 잘못된 result를 성공으로 표시하지 않는 fixture와 기존 FCM/타이머 알림 회귀를 실행한다.

**Relevant tests:** `test/features/home/fan_duration_sheet_test.dart`, `fan_timer_duration_test.dart`, `schedule_test.dart`, `routine_settings_screen_test.dart`, `control_log_list_test.dart`, `test/features/shared/control_log_test.dart`, `env_day_test.dart`, `env_day_chart_test.dart`, `test/fan_timer_notification_plan_test.dart`, `test/schedule_notification_plan_test.dart`.

fan2 연결 전에 실패를 확인할 핵심 예시(새 enum 이름 `fan2On`, `fan2Off`와 telemetry 필드 `fan2`를 이 작업에서 함께 추가):

```dart
test('냉각팬 wire와 미보고 상태를 구분한다', () {
  expect(CommandAction.fromWire('fan2_on'), CommandAction.fan2On);
  expect(CommandAction.fan2Off.toWire(), 'fan2_off');
  expect(TelemetryReading.fromJson({'fan2': 'ON'}).fan2, ActuatorState.on);
  expect(TelemetryReading.fromJson({'fan2': null}).fan2,
      ActuatorState.unavailable);
  expect(FanTimerDuration.h2.payload, {'duration_ms': 7200000});
});
```

**실물 수락:** 앱을 백그라운드로 보낸 뒤 팬2가 정해진 시간에 멈춤, LED 단계가 실제 밝기로 반영, 분무 연속 탭이 추가 명령을 만들지 않음, Android 상단 흰색 유지. 실물 검증 전에는 문서의 배포 완료 문구만으로 앱 E2E 통과라고 보고하지 않는다.

## 4. 통합 연결·그룹·개체 관리

**Modify:** `lib/features/my_cage/data/ble_pairing_repository.dart`, `wifi_credentials_store.dart`, `presentation/widgets/wifi_provisioning_view.dart`, 기존 `device_pairing_screen.dart`/`camera_pairing_screen.dart`, `lib/features/home/data/enclosure_set_repository.dart`, `lib/features/my_pets/presentation/pet_add_screen.dart`, `pet_edit_screen.dart`, `my_pets_providers.dart`, `lib/core/router/app_router.dart`.

**Create:** `lib/features/my_cage/presentation/device_add_flow_screen.dart`, `device_management_screen.dart`, `group_editor_screen.dart`, `device_add_flow_controller.dart`, `lib/features/my_pets/presentation/pet_management_screen.dart`, `test/features/my_cage/device_add_flow_test.dart`, `test/features/my_pets/pet_management_test.dart`.

- [ ] 두 종류의 BLE 기기를 선택하는 흐름을 `선택→Wi-Fi→각 기기 연결 결과→완료/부분 성공` 상태로 나눈다. 성공한 기기에 재전송하지 않는다.
- [ ] 표시명으로 기기를 동일시하지 않고 프로토콜과 대응하는 고유 ID를 사용한다. 서버의 등록 기기 목록을 BLE 검색 결과에 합성하지 않는다.
- [ ] Wi-Fi 기억을 명시적 체크·WIFI_OK 성공 시·account+SSID 저장으로 변경한다. 기존 계정 미구분 캐시를 다른 계정에 자동 공개하지 않는다.
- [ ] 자동 그룹 대상은 이번 동시 선택 또는 이어서 추가한 상대다. 독립 추가에서 여러 후보가 있으면 사용자가 선택하고, 기존 그룹 이동은 확인한다.
- [ ] T1/T2 경로로 그룹 변경·이름 할당·이력 갱신·등록 해제를 실행한다. 미등록 기기 claim은 T4 회신 전에 성공으로 취급하지 않는다.
- [ ] 기본 이름 생성기를 `사육 환경 1`/`사육장 1`/`카메라 1`부터 시작하도록 통일한다. 공백·접미사 포함 10자 제한, 기존 이름 충돌 건너뛰기, 동시 생성의 원자 할당을 확인한다. 기존 이름은 migration으로 자동 개명하지 않는다.
- [ ] Home·Camera·MyCre의 선택 헤더와 목록 항목에 그룹명 우선 표시 규칙을 공통 적용한다. 그룹 없는 항목은 개별 이름, 상세·프로필은 원래 기기/개체 이름을 유지한다. 표시명 대신 ID를 사용하고 그룹명 수정·소속 이동·해제 후 세 탭의 표시를 갱신한다.
- [ ] 같은 그룹의 세 탭에서 동일 그룹명이 보이는지, 그룹 해제 후 개별 이름으로 돌아오는지, 이름만 같은 서로 다른 항목이 잘못 선택되지 않는지 검증한다. 첫 생성 번호 1·이름 충돌·기존 사용자 이름 보존도 확인한다.
- [ ] 기기 관리의 전체 전원은 ON 고정 버튼으로 구현한다. 온라인 상태나 actuator 상태와 같은 provider로 대체하지 않는다.
- [ ] 등록·관리 폼을 Figma에 맞추고 이름 10자/중복 금지, 사진, 크레스티드 종·모프, 성별·날짜·체중·메모·선택 그룹을 구현한다. 저장 실패 시 입력이나 기존 사진을 지우지 않는다.
- [ ] 마지막 구성원 제외 시 빈 그룹 제거, 유형별 상한 1개, 표시 순서·추가 버튼 조건을 검증한다. 원본·카메라·개체 정보가 연쇄 삭제되지 않는지 확인한다.
- [ ] 기존 pairing/deep link를 보존하고 `/devices/add`, `/devices/manage`, `/groups/new`, `/my-pets/manage`를 필요한 신규 route로 등록한다. `/my-pets/:petId`보다 manage 정적 경로를 먼저 처리한다.

**사용 흐름 수락:** 동시 등록 중 하나 실패→성공 기기 유지→실패 기기만 재시도→완료 후 ‘나중에 하기’→Home에 성공 기기 표시. 기존 개체 이동→확인 취소 시 소속 유지, 확정 시 이전 이력 종료와 새 이력 시작.

## 5. Camera·플레이어·메모·사용자별 숨김

**Modify:** `lib/features/my_cage/presentation/crecam_screen.dart`, `highlights_screen.dart`, `bookmarks_screen.dart`, `clip_playlist_player_screen.dart`, `bookmark_controller.dart`, `my_cage_providers.dart`, `data/favorite_clip_repository.dart`, `motion_clip_repository.dart`의 목록 조회 경로.

**Create:** `lib/features/my_cage/presentation/clip_memo_providers.dart`, `widgets/clip_memo_editor.dart`, `test/features/my_cage/clip_visibility_feed_test.dart`.

- [ ] 기존 60건 cursor·캐시·전체 기간 기준을 보존하며 헤더/라이브/진입 카드/3열 그리드를 Figma에 맞춘다. 카메라 상태 갱신만으로 feed를 초기화하지 않는다.
- [ ] 모든 플레이어에서 메모 편집으로 연결하고 메모 카드는 북마크 목록에만 표시한다. 북마크 조작과 메모 삭제의 독립성을 테스트한다.
- [ ] 새 색은 직전 색을 제외하고 배정하며 문자 편집·스크롤·재실행으로 바꾸지 않는다. Hive adapter 변경으로 기존 캐시를 손상하지 않는다.
- [ ] hide 성공 시 일반/하이라이트/북마크/현재 재생 큐/캐시를 갱신한다. 원본 활동 조회는 필터하지 않는다. 다른 기기의 재조회에도 동일 hidden ID가 반영되는지 확인한다.
- [ ] 숨긴 영상만 있는 페이지에서도 다음 cursor를 조회할 수 있게 하고, 무한 루프·잘못된 조기 종료를 테스트한다.
- [ ] 북마크/일반은 영상 끝에서 정지, 하이라이트만 다음으로 이동한다. 회전·seek·공유/저장·기존 로컬 mp4 회귀를 확인한다.
- [ ] P2의 공개 배치 메타를 재사용하고 존재하지 않는 공개 시각/도착/읽음 상태를 만들지 않는다. FCM 설계와 같은 배치인지 대조한다.

**Run:** `flutter test test/features/my_cage` 및 관련 새 fixture. 표시만 달라지는 부분은 Figma 이미지 비교로 확인한다.

## 6. MyCre·일간·주간 집계·기존 이력

**Create:** `lib/features/my_pets/domain/activity_summary.dart`, `activity_window.dart`, `presentation/my_cre_activity_screen.dart`, `activity_providers.dart`, `widgets/activity_day_chart.dart`, `activity_week_chart.dart`, `activity_pet_header.dart`, `test/features/my_pets/activity_aggregation_test.dart`, `my_cre_activity_screen_test.dart`.
**Modify:** `lib/core/router/app_router.dart`의 `/my-pets`, `lib/features/my_pets/presentation/my_pets_screen.dart`의 관리 진입. 기존 profile/event/weight repositories는 공유한다.

**Interfaces:** activity provider는 인증 ID·선택 pet ID·일/주를 key로 삼는다. assignment repository에서 대상 camera·허용 기간을 얻어 P1 interval/coverage adapter로 전달한다. 출력은 시간/요일별 활동 초·관측 상태·평균의 분모다. 렌더 코드에서 raw clip duration을 직접 합산하지 않는다.

- [ ] P1 응답을 fixture로 고정하고 UTC interval을 KST 일/주 조회 창 및 배정 기간으로 자른 뒤 합집합·시간 bucket 분할을 수행한다.
- [ ] 유효한 0/미수집/처리 중을 다른 상태로 보존한다. 일평균은 직전 7일, 주평균은 선택 주 완료일, 금주 합계에는 당일 진행분을 포함한다.
- [ ] legacy origin은 기존 범위를 보존하며 신규 개체의 연결 시작 이후 조건과 분기한다. 이동 경계의 동일 초를 중복 집계하지 않는다.
- [ ] 일/주 전환·개체 선택·자정 날짜 변경에서 이전 Future 응답이 새 화면을 덮지 않는다. 미연결·미수집·값 0을 구분한다.
- [ ] 프로필+일간+주간 단일 스크롤, 고정 헤더, 긴 이름·빈 상태를 Figma와 대조한다.

**Core fixture table**

| Input | Expected |
|---|---|
| 23:59:50~다음 날 00:00:10 | 이전 날짜 10초, 새 날짜 10초 |
| 00:00:00~00:00:20 및 00:00:10~00:00:30 | 합계 30초 |
| 완료일 10분·완료일 0분·미수집일 | 평균 5분, 분모 2 |
| 한 시간에 중복 구간 다수 | 합집합 후 60분 이하 |
| 월요일로 날짜 변경 | 새 주로 이동, 이전 주 합계 불변 |
| A→B를 12:00에 이동 | A는 12:00 미만, B는 12:00 이후 |
| 기존 사용자 + legacy | 과거 표시 승계, 가상의 시작일 생성 없음 |
| 신규 개체 + 12:00 연결 | 12:00 전은 연결 전 |
| 동일 카메라 영상을 사용자별 숨김 | MyCre 합계 불변 |

## 7. 통합 검증·기록·완료 판정

- [ ] 각 단계에서 변경 개요를 읽고 기능별 diff를 점검한다. 10개 이상 파일을 한 번에 모두 읽지 않는다.
- [ ] 구현을 그대로 되풀이하는 테스트를 양산하지 않고 상태 전이·데이터 경계·다른 계정 거부·실패 재시도를 focused test로 검증한다.
- [ ] `flutter analyze --no-pub` 오류 0을 확인한다. 기존 info는 건수를 명시하고 신규 오류를 기존 문제로 취급하지 않는다. 의존 변경 시 pub get을 먼저 수행한다.
- [ ] focused test 이후 전체 회귀가 필요한 통합 변경에는 `flutter test`를 수행한다. 새 변경이나 실패가 없으면 이유 없이 반복하지 않는다.
- [ ] Android debug build와 실기기에서 흰 상단, BLE 동시/부분 연결, fan/fan2/LED/mist, 백그라운드 타이머를 확인한다. iOS도 safe area·키보드·저장을 확인한다.
- [ ] Figma frame별 같은 논리 폭으로 촬영해 색·아이콘 실측 크기·여백·문자·잘림·터치 영역·고정 스크롤을 대조한다. 차이는 수정하거나 승인된 차이로 기록한다.
- [ ] `docs/design-audits/2026-09-15-redesign-implementation-results.md`에 spec 절→task→테스트/이미지→결과를 기록한다. 외부 계약 대기는 미완료로 표시하고 담당과 필요한 회신을 명시한다.
- [ ] 코드를 포함하는 논리 단위마다 version+CHANGELOG와 함께 커밋한다. 순수 계획 문서 커밋은 앱 버전·CHANGELOG를 변경하지 않는다.

### 완료를 잘못 판정하지 않기 위한 기준

1. SVG 원본 보관 완료와 runtime 전 화면 적용 완료를 구분한다.
2. 로컬 UI/fixture 성공과 실제 서버의 소유권·관측 데이터·실기기 성공을 구분한다.
3. 전체 전원 ON 고정, 제어 로그 근사치, 삭제 문구와 실제 보존 정책 차이는 사용자 승인된 사양 차이로 기록한다.
4. P1/T2/T4 등의 계약을 충족하지 못한 부분을 완료된 화면으로 보고하지 않는다. 독립적인 구현은 진행한다.
5. 본 계획의 문서 저장 완료는 구현·외부 의뢰 발송·DB 적용 허가나 완료 보고를 대신하지 않는다.

## 확정 기획 범위 점검

| 기획 절 | 구현 위치 |
|---|---|
| §1~2 범위·공통·원본 에셋 | 1A/1B, 7 |
| §3 Home·팬·LED·분무·LCD | 3 |
| §4 온습도·제어 기록 | 3, T3 외부 계약 |
| §5 Camera·북마크·메모·숨김 | 2B, 5, P2 외부 계약 |
| §6 MyCre·legacy·연결 이력 | 2A/2B/2C, 6, P1/T1 |
| §7 연결·이름·그룹·임시 전원 | 2A/2B, 4, T1/T2/T4 |
| §8 크레스티드 등록·보존형 삭제 | 2C, 4/5/6, T2 |
| §9 일정·보조 화면·공통 처리 | 1B, 3/4 |
| §10 검증·변경 관리 | 7 |

## 문서 저장 시 검증 기록 (2026-09-15)

- 새 기획·계획·분장 문서 3개의 내부 파일 링크와 코드 fence 검사 통과.
- 기존 SVG/PNG 원본 74개 manifest SHA-256 일치, fan2 전달 문서 보관본과 Desktop 원문 바이트 일치.
- `flutter analyze --no-pub`: 오류 0·경고 0·기존 info 10개. info 때문에 프로세스 exit code는 1이었다. 이번 변경은 문서만이며 Dart 코드는 수정하지 않았다.
- 앱 빌드·동작 테스트·DB migration 실행·외부 요청 전송은 이 문서 저장 작업에서 수행하지 않았다. 앞의 체크리스트는 후속 구현용이다.
