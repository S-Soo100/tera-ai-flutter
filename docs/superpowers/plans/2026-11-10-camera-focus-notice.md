# 카메라 렌즈 초점 안내 Implementation Plan (r2)

> **구현 방식 (CAOF):** Standard 트랙 — 메인이 task 단위로 직접 구현. r1(Critical, 운영 트리거 교체안)은 교차 검수 후 이 r2로 대체했다([검수 결과](../../design-audits/2026-11-10-camera-focus/plan-review-final.md)). 운영 DB 스키마·함수 변경 없음. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운영자가 특정 사용자에게 "카메라 렌즈 초점을 맞춰주세요" 안내를 보내면, 그 사용자의 앱 라이브 위(카메라 탭·홈)에 스낵바가 뜨고 알림함에도 남는다. 카메라 상세에는 초점 가이드를 항상 보여 준다.

**Architecture:** 운영자가 SQL로 `app_notifications`에 `kind='camera.focus_needed'` 1행을 직접 넣는다. 이 테이블에는 INSERT 트리거가 없으므로 푸시 큐(outbox)를 타지 않는다. 앱은 이 kind만 거르는 좁은 Realtime stream으로 미읽음 여부를 본다. 미읽음이 있으면 라이브 위에 스낵바를 그린다. 누르면 그 행들을 읽음 처리해 스낵바와 마이페이지 알림 점이 함께 사라진다. 알림함은 기존 전체 stream에서 이 행을 그대로 보여 준다.

**Tech Stack:** Flutter + Riverpod + GoRouter + easy_localization, Supabase Realtime(RLS).

**Spec:** Figma `Final Design` 섹션 `카메라 초점`(1813:8269) + 사용자 결정(2026-11-10): ① 스낵바 + 알림함(푸시 없음) ② 사람 단위(카메라 지정 없음) ③ 운영자 수동 지정.

## 가정

- 확인:
  - `app_notifications`: 제약은 `data` object CHECK·PK·`UNIQUE(user_id, dedupe_key)`·FK뿐이다. kind·category·source CHECK가 없고 트리거도 없다. NOT NULL 컬럼은 `user_id, kind, category, title, body, route, data, source, source_event_id, dedupe_key, created_at`(기본 now)이다. RLS는 본인 SELECT·UPDATE만이다.
  - 푸시는 `notification_events` 트리거가 `notification_outbox`에 넣을 때만 나간다. `app_notifications`에 직접 넣으면 푸시가 없다.
  - 앱의 알림 전체 stream(`notificationsProvider`)은 지금 알림함(`notification_center_screen.dart:25`)과 마이페이지(`profile_screen.dart:50`, 미읽음 점)만 구독한다. 홈 헤더에는 알림 배지가 없다.
  - 계정당 알림 행은 최대 1,099, 중앙값 16.5다(2026-11-10). 그래서 홈에서 전체 stream을 열지 않는다.
  - 모르는 kind는 `AppNotification.safeRoute`가 `/notifications`로 보낸다(`app_notification.dart:64~66`). 구버전 앱은 알림함에 "일반 알림"으로만 보인다.
  - `/crecam`은 `StatefulShellRoute` 탭 경로이고 `/notifications`는 셸 밖 최상위 경로다(`app_router.dart:205·225·628`).
  - 라이브 단계 enum은 `WebRtcLivePhase`(`webrtc_live_controller.dart:26`)이고, 영상이 보이는 단계는 `streaming`·`stalled`다.
  - 카메라 상세 = `/crecam/cameras/:id/live` 세로 화면(`CameraLiveFullscreenScreen`).
- 미확인:
  - RLS 아래에서 `.stream().eq('kind', …)` Realtime이 INSERT·UPDATE를 받는지 → Task 2 Step 6에서 운영자 본인 계정으로 먼저 확인한다. 안 되면 user_id stream + 앱 필터로 되돌리고 보고한다.
  - 운영자가 Supabase SQL 편집기를 쓸 수 있는지.

## 선택지와 추천

1. **전달 경로** — (A) `app_notifications` 직접 INSERT / (B) `notification_events`에 새 type을 추가하고 운영 트리거를 교체(r1). **A 추천:** 운영 트리거·ingest 계약·재배포가 필요 없고 푸시도 나가지 않는다. 잃는 것은 `notification_events` 기록 하나다. 나중에 서버가 자동 판정으로 보내야 하면 그때 B로 올린다.
2. **앱 구독 범위** — kind만 거르는 좁은 stream(추천) / 기존 전체 stream 재사용. 홈은 앱을 켤 때마다 보는 화면이라 최대 1,099행을 실시간으로 받는 비용을 피한다.
3. **알림함 탭 이동** — 선택된 카메라(`selectedCrecamCameraProvider`)가 내 목록에 있으면 그 상세(push), 없으면 첫 카메라, 0대면 `go('/crecam')`(셸 중복 방지).
4. **스낵바 노출 조건** — 라이브 단계가 `streaming` 또는 `stalled`일 때만. 연결 중·실패·시청 제한·오프라인 화면의 문구와 버튼을 가리지 않기 위해서다.
5. **누름 처리** — 이동 먼저 → 로컬 숨김 → 미읽음 초점 안내 전부 `markRead`. 실패한 id는 숨김에서 빼서 스낵바를 다시 보이게 한다(배지와 일치).

## 실패 시나리오

- **kind 필터 Realtime이 안 옴** → 스낵바가 앱 재시작 때만 갱신된다. Task 2 Step 6 프로토타입에서 잡는다. 대안은 위 미확인 참조.
- **운영자 이메일 오타** → `INSERT 0 0`으로 조용히 실패한다. 운영 문서에 결과 확인 단계를 둔다.
- **같은 사용자에게 두 번 보냄** → 서로 다른 dedupe_key로 2행이 생긴다. 스낵바 한 번 누름이나 알림함 하나 열기로 둘 다 읽음 처리된다.
- **markRead 네트워크 실패** → 숨김을 풀어 스낵바가 다시 보인다. 사용자는 다시 누르면 된다.
- **알림함 "모두 읽음"** → 스낵바도 사라진다(의도된 동작).
- **구버전 앱 사용자** → 스낵바가 없고 알림함에 "일반 알림"으로 보인다. 누르면 알림함에 머문다. 무해하다.
- **글자 크기 확대** → 스낵바에 최소 높이 36을 주고 글자에 맞춰 늘린다. 회귀 검사에 추가한다.

## 유저 체험 시뮬레이션

1. 운영자가 영상이 흐린 사용자 A에게 SQL 한 번으로 초점 안내를 보낸다.
2. A가 앱을 열어 홈을 본다. 라이브 영상이 재생되면 영상 위쪽 안에 연회색 막대가 뜬다. 막대에는 "카메라 렌즈 초점을 맞춰주세요"와 빨간 "**더보기**"가 있다. 마이페이지 알림 줄에도 미읽음 점이 생긴다.
3. 카메라 탭에서도 라이브 위에 같은 막대가 있다. 카메라를 옆으로 넘겨도 계속 있다(사람 단위). 라이브가 연결 중이거나 실패·오프라인 안내가 뜬 동안에는 막대가 숨는다.
4. A가 막대 아무 곳이나 누르면 지금 보던 카메라의 상세 화면(세로 라이브)이 열린다. 아래쪽 "카메라 초점 가이드" 상자에 렌즈를 돌리는 방법이 3줄로 적혀 있다.
5. 뒤로 돌아오면 홈과 카메라 탭 모두 막대가 사라졌고 마이페이지 점도 없다. 같은 계정의 다른 폰에서도 사라진다(서버 읽음).
6. 알림함에는 "카메라 렌즈 초점을 맞춰주세요"(분류: 카메라)가 읽음 상태로 남는다. 누르면 같은 상세로 간다.
7. 막대를 누르지 않고 알림함에서 먼저 열거나 "모두 읽음"을 눌러도 막대가 사라진다.
8. 안내를 받지 않은 사용자도 카메라 상세에서 초점 가이드 상자를 항상 본다. 가로 전체화면에는 없다.

## 근본 원인·전후 동작

- 전: 흐린 영상을 고칠 방법을 앱이 알려 주지 않는다. 운영자가 특정 사용자에게만 앱 안 안내를 보낼 수단도 없다(공지는 푸시까지 나간다).
- 후: 위 시뮬레이션대로.

## 검증 방법

- `flutter analyze` 에러 0, `flutter test` 전체 통과(새 테스트 포함).
- Task 2 Step 6: 운영자 본인 계정에 SQL 1행 → 시뮬레이터에서 실시간 수신 → 읽음 → 소멸까지 확인(로그 `[focus-notice]`).
- 시뮬레이터(13 mini) 캡처로 시뮬레이션 2~8을 확인한다. Figma 수치 대조표를 `docs/design-audits/2026-11-10-camera-focus/RESULTS.md`에 남긴다. 13 mini는 앱 이미지를 104.17% 확대한 뒤 비교한다.
- 실제 렌즈 조정 효과는 사용자만 확인할 수 있다.

## 사용자가 정할 것

- 운영자 발송 경로: Supabase SQL 편집기(추천, 이 계획 범위) / 관리 화면 신설(범위 밖).
- 테스트 행을 넣을 운영자 계정(Task 2 Step 6). 추천: 사용자 본인 계정.

## Global Constraints

- kind `camera.focus_needed`, category `camera`, source `external`, route `/crecam`(기록용 — 앱은 kind로 분기), dedupe_key `ops-focus:<uuid>`.
- 문구(Figma 원문): 스낵바 `카메라 렌즈 초점을 맞춰주세요` / `더보기`. 가이드 제목 `카메라 초점 가이드`. 가이드 3줄: `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요` · `렌즈 돌출 부분을 손으로 잡고 좌우로 천천히 돌리면서, 라이브 화면이 가장 선명해지는 위치를 찾아주세요` · `초점 조정이 필요하면 “카메라 렌즈 초점을 맞춰주세요” 안내 메시지가 표시돼요`.
- 알림함 행: title `카메라 렌즈 초점을 맞춰주세요`, body `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요`, 분류 라벨 `카메라`.
- 색: `#F4F4F4`=`VivaColors.fillButton`, `#3C3C3C`=`labelSecondary`, `#949090`=`labelQuaternary`, `#C00306`=`mainDark`. 하드코딩 금지.
- 글자 크기는 Figma 그대로 쓰고 고정 `TextScaler`는 쓰지 않는다. 문자열은 `ko.json` + `.tr()`. CircularProgressIndicator 금지.
- 작업 공간: `tools/worktree.sh new feat/camera-focus-notice`(최신 main에서). 끝나면 `finish`.
- `lib/` 변경 커밋마다 버전 bump: Task 1 → minor, 이후 patch. 병합 직전 main보다 한 칸 위로 조정한다. 같은 커밋에 `CHANGELOG.md` 한글 항목을 넣는다.
- 건드리지 않는 것: 운영 DB 스키마·함수·트리거, `supabase/` 전체, `notification-ingest`·`dispatch-push`, 기존 알림 kind 처리·`sanitizeNotificationRoute`, 푸시 수신·로컬 알림, 가로 전체화면 라이브, `CameraDetailScreen`(`/crecam/cameras/:id`), 기존 알림 전체 stream(`watchNotifications`).

## Review Focus

1. **계정 전환** — A의 미읽음 안내가 B 화면에 남으면 안 된다. → Task 2 테스트 `계정이 바뀌면 숨김과 목록이 새 계정 기준이다`.
2. **같은 안내 여러 건** — 한 번 누름으로 전부 읽음 처리돼야 한다. → Task 2 `dismiss는 미읽음 초점 안내 전부를 읽음 처리한다`, Task 3 `알림함에서 열면 초점 안내 전부를 읽음 처리한다`.
3. **실패 화면 위 겹침** — 실패 안내와 버튼을 가리면 안 된다. → Task 4 `failed·offline·connecting 단계에서는 그리지 않는다`.
4. **카메라 0대** — 알림함 탭은 `go('/crecam')`. → Task 3 `focusNoticeRoute` 테스트.
5. **글자 2배** — 스낵바와 가이드가 넘치지 않아야 한다. → Task 1·4에서 `text_scale_overflow_test.dart`에 추가.

---

### Task 1: 카메라 상세 '카메라 초점 가이드'(항상 노출) — 단독 병합 가능

**Files:**
- Create: `lib/features/my_cage/presentation/widgets/camera_focus_guide.dart`
- Modify: `lib/features/my_cage/presentation/camera_live_fullscreen_screen.dart` (`_buildPortrait`, 전원 줄 다음)
- Modify: `assets/l10n/ko.json` (`camera_focus_guide_title`, `camera_focus_guide_1`, `camera_focus_guide_2`, `camera_focus_guide_3`)
- Test: `test/features/my_cage/camera_focus_guide_test.dart`, `test/design/text_scale_overflow_test.dart`

**Context:**
- Depends on: 없음
- Produces: `class CameraFocusGuide extends StatelessWidget { const CameraFocusGuide({super.key}); }`
- Must know (Figma 1813:8229 실측):
  - 배치: 전원 줄 아래 간격 24.
  - 제목: SemiBold 16 / 줄높이 19.09 / 자간 −0.32 / `labelQuaternary`. 제목과 상자 사이 8.
  - 상자: `fillButton`, r16, 사방 패딩 12, 폭은 위 줄 목록과 같다.
  - 문장 3개: Medium 14 / 줄높이 21 / 자간 −0.28 / `labelSecondary`, 문장 사이 8.
  - 세로 화면에만 넣는다. 세로 본문이 스크롤 영역인지 먼저 확인한다. 아니면 가이드가 하단 재시작 버튼에 가리지 않게 본문을 스크롤 가능하게 한다(재시작 버튼 위치는 유지).
- Acceptance: 테스트 통과, 시뮬레이터 캡처에서 위 수치를 대조.

- [x] **Step 1: 실패하는 테스트** — `세로 상세에 초점 가이드 제목과 3문장이 있다`(Global Constraints 문구 그대로 `find.text`), `가로에는 없다`, 글자 1.0/1.3/2.0 무오버플로.
- [x] **Step 2: 실패 확인** — `flutter test test/features/my_cage/camera_focus_guide_test.dart` → FAIL.
- [x] **Step 3: 구현**.
- [x] **Step 4: 통과 확인** — 위 명령 + `flutter test test/design/` PASS, `flutter analyze` 0.
- [x] **Step 5: 버전 minor + CHANGELOG `추가: 카메라 상세에 렌즈 초점 가이드` → 커밋** `feat(camera): 카메라 상세 초점 가이드`.

### Task 2: 초점 안내 데이터·상태 + 운영자 발송 문서

**Files:**
- Modify: `lib/features/notification/data/notification_repository.dart` (`NotificationStore.watchKind`, `SupabaseNotificationStore.watchKind`, `NotificationRepository.watchUnreadOfKind`)
- Modify: `lib/features/notification/domain/app_notification.dart` (`const cameraFocusNotificationKind = 'camera.focus_needed';` + `knownNotificationKinds`에 추가)
- Create: `lib/features/notification/presentation/focus_notice_providers.dart`
- Create: `docs/ops/camera-focus-notice.md`
- Test: `test/features/notification/focus_notice_providers_test.dart`, `test/features/notification/notification_repository_test.dart`(가짜 store에 `watchKind` 추가)

**Context:**
- Depends on: 없음
- Produces:
  - `Stream<List<Map<String, Object?>>> watchKind(String kind)` — `client.from('app_notifications').stream(primaryKey: ['id']).eq('kind', kind)`. 행 범위는 RLS로 본인 것만이다.
  - `Stream<List<AppNotification>> watchUnreadOfKind(String userId, String kind)` — `user_id == userId && kind == kind && readAt == null`인 행만 남긴다(RLS만 믿지 않고 한 번 더 거른다).
  - `final focusNoticeIdsProvider = StreamProvider.autoDispose<List<String>>` — `currentUserProvider.select((u) => u?.id)`를 watch한다. 계정이 없으면 `[]`.
  - `final focusNoticeVisibleProvider = Provider.autoDispose<bool>` — 위 id 중 로컬 숨김에 없는 것이 하나라도 있으면 true. 로딩·에러면 false.
  - `Future<void> dismissFocusNotices(WidgetRef ref)` — 현재 id들을 숨김 집합에 넣고 각각 `markRead`를 호출한다. 실패한 id는 숨김에서 다시 빼고 `[focus-notice]` 로그를 남긴다.
  - 숨김 집합 `focusNoticeDismissedProvider`(`StateProvider<Set<String>>`)는 계정 id를 watch해 계정이 바뀌면 비워진다.
- Must know: 기존 `watchNotifications`와 `notificationsProvider`는 바꾸지 않는다. 가짜 store는 `notification_repository_test.dart`의 구현을 확장한다.
- Acceptance: 테스트 통과 + Step 6 실기 확인.

- [x] **Step 1: 실패하는 테스트**
  - `미읽음 초점 안내가 있으면 보인다` — 행 1개(kind `camera.focus_needed`, read_at null) → visible true.
  - `읽은 안내·다른 계정 행은 무시한다` — read_at 있음 + user_id 다른 행 → false.
  - `dismiss는 미읽음 초점 안내 전부를 읽음 처리한다` — 2건 → markRead 호출 id 2개, visible은 stream 갱신 전에 바로 false.
  - `markRead 실패한 id는 다시 보인다` — 가짜 store가 1건 throw → visible true.
  - `계정이 바뀌면 숨김과 목록이 새 계정 기준이다` — A에서 dismiss → B(미읽음 1건)로 전환 → visible true.
- [x] **Step 2: 실패 확인** — `flutter test test/features/notification/focus_notice_providers_test.dart` → FAIL.
- [x] **Step 3: 구현**(Produces 시그니처 그대로).
- [x] **Step 4: 통과 확인** — `flutter test test/features/notification/` 전체 PASS.
- [x] **Step 5: 운영자 문서** `docs/ops/camera-focus-notice.md` — 아래 보내기 SQL, 결과가 `INSERT 0 1`인지 확인, 보낸 기록 조회, 취소(`read_at = now()`) SQL.

```sql
insert into public.app_notifications
  (user_id, kind, category, title, body, route, data, source, source_event_id, dedupe_key)
select u.id, 'camera.focus_needed', 'camera',
       '카메라 렌즈 초점을 맞춰주세요', '영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요',
       '/crecam', jsonb_build_object('kind', 'camera.focus_needed', 'source', 'external'),
       'external', e.id, 'ops-focus:' || e.id
from auth.users u, (select gen_random_uuid()::text as id) e
where u.email = '<대상 이메일>';
```

- [x] **Step 6: 실기 프로토타입(사용자가 고른 운영자 계정)** — 앱을 디버그 실행한다. 임시로 `focusNoticeIdsProvider`를 로그로 찍는 상태에서 위 SQL을 1회 넣는다. 수 초 안에 `[focus-notice] ids=[…]` 로그가 나오는지 본다. SQL로 `read_at`을 채운 뒤 `ids=[]` 로그가 나오는지도 본다. 실패하면 중단하고 보고한다.
- [x] **Step 7: 버전 patch + CHANGELOG → 커밋** `feat(notification): 카메라 초점 안내 수신 상태`.

### Task 3: 알림함에서 초점 안내 열기

**Files:**
- Create: `lib/features/notification/domain/focus_notice_target.dart`
- Modify: `lib/features/notification/presentation/notification_center_screen.dart` (`_open`, `_category`)
- Modify: `assets/l10n/ko.json` (`notifications_category_camera`: `카메라`)
- Test: `test/features/notification/focus_notice_target_test.dart`, `test/features/notification/notification_center_screen_test.dart`

**Context:**
- Depends on: Task 2(상수, `dismissFocusNotices`)
- Produces: `String? focusNoticeCameraPath({required List<String> myCameraIds, required String? selectedCameraId})` — 선택 id가 목록에 있으면 `/crecam/cameras/$id/live`, 아니면 첫 id, 목록이 비면 `null`.
- Must know: `_open`에서 kind가 `cameraFocusNotificationKind`면 다음 순서로 처리한다.
  1. `dismissFocusNotices(ref)`로 나머지 초점 안내도 읽음 처리한다.
  2. `camerasProvider.future`(5초 timeout, 실패 시 `[]`)와 `selectedCrecamCameraProvider`로 경로를 정한다.
  3. 경로가 있으면 `context.push(path)`, `null`이면 `context.go('/crecam')`.
  4. await 뒤 계정 가드를 다시 본다.
  다른 kind는 기존 그대로 처리한다.
- Acceptance: 테스트 통과, 기존 알림함 테스트 무회귀.

- [x] **Step 1: 실패하는 테스트**
  - `focusNoticeCameraPath`: (`['a','b']`,`'b'`)→`/crecam/cameras/b/live`; (`['a','b']`,`'z'`)→`/crecam/cameras/a/live`; (`[]`,`null`)→`null`.
  - `알림함에서 열면 초점 안내 전부를 읽음 처리한다` — 초점 2건 중 1건 탭 → markRead 2회, 분류 라벨 `카메라`.
- [x] **Step 2: 실패 확인** — `flutter test test/features/notification/`.
- [x] **Step 3: 구현**.
- [x] **Step 4: 통과 확인** — 같은 명령 PASS.
- [x] **Step 5: 버전 patch + CHANGELOG → 커밋** `feat(notification): 알림함에서 초점 안내를 카메라 상세로 연다`.

### Task 4: 라이브 위 스낵바(카메라 탭·홈)

**Files:**
- Create: `lib/features/my_cage/presentation/widgets/focus_notice_snack_bar.dart`
- Modify: `lib/features/my_cage/presentation/widgets/camera_live_area.dart` (Stack)
- Modify: `lib/features/home/presentation/widgets/top_fixed_area.dart` (Stack)
- Modify: `assets/l10n/ko.json` (`camera_focus_notice`, `camera_focus_notice_more`)
- Test: `test/features/my_cage/focus_notice_snack_bar_test.dart`, `test/design/text_scale_overflow_test.dart`. 기존 home·my_cage 위젯 테스트는 `focusNoticeVisibleProvider.overrideWith((_) => false)`로 고정한다.

**Context:**
- Depends on: Task 2
- Consumes: `focusNoticeVisibleProvider`, `dismissFocusNotices(ref)`, `webrtcLiveControllerProvider(cameraId)`의 phase
- Produces: `class FocusNoticeSnackBar extends ConsumerWidget { const FocusNoticeSnackBar({super.key, required this.cameraId}); static const tapKey = Key('focus_notice_snack_bar'); }` — 안내가 없거나 phase가 `streaming`·`stalled`가 아니면 `SizedBox.shrink()`.
- Must know (Figma 1813:8260 실측):
  - 배치: 라이브 틀 Stack 안 `Positioned(top: 12, left: 12, right: 12)`. 카메라 탭은 `current.id`, 홈은 `camera.id`.
  - 면: `fillButton`, r8, 좌우 패딩 16, 최소 높이 36. 고정 높이는 쓰지 않는다.
  - 본문: Medium 16 / 줄높이 28 / 자간 −0.32 / `labelSecondary`, `Expanded` + `maxLines: 2`.
  - "더보기": SemiBold 16 / 줄높이 28 / 자간 −0.32 / `mainDark`, 본문과 간격 8 이상.
  - 막대 전체가 한 터치 영역이다(`InkWell`, `tapKey`). 누르면 `context.push('/crecam/cameras/$cameraId/live')`를 먼저 하고, 그다음 `dismissFocusNotices(ref)`를 부른다(await 안 함).
  - 카메라 탭의 이름 배지, LiveSurface status·corner, 가운데 알약(멈춤·종료 임박)과 동시에 뜰 때 겹침을 대조표에 기록한다.
- Acceptance: 테스트 통과, `flutter analyze` 0.

- [x] **Step 1: 실패하는 테스트**
  - `안내가 있고 streaming이면 문구와 더보기가 보인다`.
  - `failed·offline·connecting 단계에서는 그리지 않는다`.
  - `누르면 상세로 이동하고 사라진다` — push 경로 `/crecam/cameras/c1/live`, 이후 `find.byKey(tapKey)` 없음.
  - `text_scale_overflow_test.dart`에 스낵바 1.0/1.3/2.0 무오버플로를 추가한다.
- [x] **Step 2: 실패 확인** — `flutter test test/features/my_cage/focus_notice_snack_bar_test.dart`.
- [x] **Step 3: 위젯 구현 + 두 Stack에 배치 + 기존 테스트 override**.
- [x] **Step 4: 통과 확인** — `flutter test` 전체 PASS, `flutter analyze` 0.
- [x] **Step 5: 버전 patch + CHANGELOG → 커밋** `feat(camera): 라이브 위 렌즈 초점 안내 스낵바`.

### Task 5: 화면 검수·병합

**Files:**
- Create: `docs/design-audits/2026-11-10-camera-focus/RESULTS.md`

**Context:**
- Depends on: Task 1~4
- Acceptance: 시뮬레이션 2~8 캡처, Figma 수치 대조표(차이는 보고 후 확정), `/code-review` 요청(사용자 호출).

- [x] **Step 1:** 운영자 계정으로 SQL 1행 → 시뮬레이터에서 시뮬레이션 2~8을 캡처하고 대조표를 작성한다.
- [ ] **Step 2:** 사용자에게 `/code-review`를 요청하고, 지적은 `receiving-code-review`로 처리한다.
- [ ] **Step 3:** 버전을 main 대비 재조정하고 `tools/worktree.sh finish feat/camera-focus-notice`를 실행한다.
