# 카메라 렌즈 초점 안내 Implementation Plan

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. Critical 트랙 — Implementer 에이전트 분리(GATE 4). 운영 DB 적용(Task 1 마지막 단계)은 사용자 별도 승인 후 메인이 한다. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운영자가 특정 사용자에게 "카메라 렌즈 초점을 맞춰주세요" 안내를 보내면, 그 사용자의 앱 라이브 위(카메라 탭·홈)에 스낵바가 뜨고 알림함에도 남으며, 카메라 상세에는 초점 가이드를 항상 보여 준다.

**Architecture:** 기존 알림 파이프라인을 그대로 쓴다 — `notification_events` INSERT → 트리거 `notification_event_after_insert`가 `app_notifications` 행을 만든다. 새 종류 `camera.focus_needed`는 **푸시 큐(outbox)에 넣지 않는다**. 앱은 이미 구독 중인 `notificationsProvider`에서 읽지 않은 `camera.focus_needed`가 있으면 스낵바를 그리고, 누르면 그 행들을 읽음 처리해 스낵바·알림함 배지가 함께 사라진다.

**Tech Stack:** Supabase(Postgres 트리거·Edge Function 계약 mjs), Flutter + Riverpod + GoRouter + easy_localization.

**Spec:** Figma `Final Design` 페이지 섹션 `카메라 초점`(1813:8269) + 사용자 결정(2026-11-10, 이 세션): ① 스낵바 + 알림함(푸시 없음) ② 사람 단위(카메라 지정 없음) ③ 운영자가 수동 지정.

## 가정

- 확인:
  - 운영 `notification_event_after_insert` 본문 md5(prosrc) = `ce5e129f30f3e72f4ccf8fe10584c6fd` = `supabase/migrations/20261103000000_notification_env_alert_humid_cycle.sql`의 `$$…$$` 본문(2026-11-10 대조).
  - 이 함수의 `CASE NEW.type`에는 ELSE가 없다 → 분기 없는 새 타입은 CASE_NOT_FOUND로 **적재 자체가 실패**한다.
  - `notification_events` 제약: `source IN ('external','database')`, `UNIQUE(source, source_event_id)`, `payload`는 object, type CHECK는 12종(목록은 Task 1 SQL 참조).
  - `app_notifications` RLS: 본인 SELECT·UPDATE만. 앱의 `markRead`가 `read_at`을 쓴다.
  - 앱은 `notificationsProvider`(계정 id select-watch + Realtime stream)로 알림 전체를 이미 구독한다. 알 수 없는 kind는 category `other`, route `/notifications`로 떨어진다(`AppNotification.fromJson`).
  - 카메라 상세 = `/crecam/cameras/:id/live`(`CameraLiveFullscreenScreen` 세로). 실시간 녹화·180° 회전·전원 줄과 하단 재시작이 이미 있다.
  - 서버(카메라)에는 초점·선명도 신호가 없다(`cameras` 컬럼, `image_state` 키 = luma/chroma/exp/ae_auto/ae_frozen/night).
- 미확인:
  - 운영자가 Supabase SQL 편집기에 접근할 수 있는지(없으면 `notification-ingest`의 `PUSH_EVENT_INGEST_SECRET`이 필요 — 로컬 `.env`엔 없음).
  - 디자이너 의도: 오프라인 안내가 뜬 라이브에서도 스낵바를 보일지(아래 추천대로 숨김으로 둠).

## 선택지와 추천

1. **전달 경로** — (A) 기존 `notification_events` 파이프라인에 새 type 추가 / (B) `cameras`나 프로필에 플래그 컬럼 신설. **A 추천:** 사용자별 전달·읽음 처리·실시간 구독·알림함 노출이 이미 있다. B는 알림함 노출을 따로 만들어야 하고 "보낸 기록"이 남지 않는다.
2. **푸시 끄기 위치** — (A) 트리거에서 이 type만 outbox INSERT를 건너뜀 / (B) 앱에서 수신 무시. **A 추천:** 푸시는 서버가 보내므로 앱에서 막을 수 없다.
3. **알림함 탭 시 이동 대상(사람 단위라 카메라 id 없음)** — 현재 카메라 탭에서 선택된 카메라(`selectedCrecamCameraProvider`)가 내 카메라 목록에 있으면 그 상세, 없으면 목록 첫 카메라, 카메라 0대면 `/crecam`. DB `route`에는 `/crecam`을 넣는다(앱 구버전은 이 값으로 카메라 탭을 연다 — 허용 목록에 없으면 `/notifications`로 떨어지므로 Task 3에서 `/crecam` 허용 추가).
4. **오프라인일 때 스낵바** — 확대 버튼과 같은 규칙으로 `WebRtcLiveView.isOfflineNotice`면 숨김(추천). 초점은 영상이 보여야 의미가 있고, 오프라인 안내 문구와 겹친다.
5. **스낵바 누름 처리 순서** — 먼저 화면 이동 + 로컬에서 즉시 숨김, 그다음 `markRead`. 실패해도 이동은 유지하고 다음 진입 때 다시 뜬다(읽음이 안 됐으므로 정확함).

## 실패 시나리오

- **트리거 교체가 기존 분기를 깨뜨림** → 하이라이트·온습도·예약 알림 전부 적재 실패. 대응: 새 마이그레이션은 20261103 본문을 **그대로 복사**하고 두 군데만 더한다. Task 1 테스트가 "기존 12종 분기와 env 수신 끔 로직이 그대로 있음"을 문자열로 검사한다. 적용 직후 운영에서 prosrc md5 변화와 type CHECK를 확인하고, 테스트 행 1건(운영자 본인 계정)으로 `app_notifications` 생성·outbox 미생성을 확인한다.
- **운영자가 같은 `source_event_id`로 다시 보냄** → UNIQUE 위반으로 INSERT 실패(무해). 운영 문서의 SQL은 매번 `gen_random_uuid()`를 쓴다.
- **앱 구버전 사용자에게 보냄** → 스낵바 없음, 알림함에 "일반 알림"으로 표시(알 수 없는 kind → category other, route `/notifications`). 무해.
- **Realtime 지연** → 누른 뒤 stream이 늦게 와도 로컬 숨김 집합으로 다시 나타나지 않는다.
- **글자 크기 확대** → 스낵바 고정 높이 36이면 잘린다. 최소 높이 36에 글자에 맞춰 늘린다(Task 4), 회귀 검사 추가.

## 유저 체험 시뮬레이션

1. 운영자가 영상이 흐린 사용자 A에게 초점 안내를 보낸다(SQL 1줄).
2. A가 앱을 열어 홈을 본다. 라이브 영상 위쪽 안에 연회색 막대 "카메라 렌즈 초점을 맞춰주세요 · **더보기**(빨강)"가 떠 있다. 홈 헤더 알림 배지도 1 늘어 있다.
3. 카메라 탭으로 가도 같은 막대가 라이브 위에 있다. 카메라를 옆으로 넘겨도 계속 있다(사람 단위).
4. A가 막대 아무 곳이나 누른다 → 지금 보던 카메라의 상세 화면(세로 라이브)이 열린다. 아래쪽에 "카메라 초점 가이드" 상자가 있고 렌즈를 돌리는 방법이 3줄로 적혀 있다.
5. 뒤로 돌아오면 홈·카메라 탭 모두 막대가 사라졌고 알림 배지도 줄었다. 다른 폰에서 같은 계정으로 들어가도 사라져 있다(서버 읽음).
6. 알림함에는 "카메라 렌즈 초점을 맞춰주세요" 항목이 남아 있고(분류: 카메라), 누르면 같은 상세로 간다.
7. 막대를 누르지 않고 알림함에서 먼저 열어도 읽음 처리되어 막대가 사라진다.
8. 카메라가 오프라인이라 "카메라가 꺼져 있어요" 안내가 뜬 동안엔 막대가 안 보이고, 다시 켜지면 나타난다.
9. 안내를 받지 않은 사용자도 카메라 상세에서 초점 가이드 상자는 항상 본다. 가로 전체화면에는 없다.

## 근본 원인·전후 동작

- 전: 흐린 영상을 고칠 방법을 앱이 알려 주지 않는다. 운영자가 특정 사용자에게 알릴 수단이 없다(공지 `notice.published`는 푸시까지 나간다).
- 후: 위 시뮬레이션대로.

## 검증 방법

- `node --test supabase/functions/_shared/` 전부 통과.
- `flutter analyze` 에러 0, `flutter test` 전부 통과(새 테스트 포함).
- 운영 적용 후 SQL: prosrc md5가 바뀌었고 본문에 `camera.focus_needed` 포함, type CHECK 13종. 운영자 본인 계정으로 테스트 행 1건 → `app_notifications` 1행, `notification_outbox` 0행.
- 시뮬레이터(13 mini)에서 위 시뮬레이션 1~9를 캡처로 확인하고 Figma 수치(아래 Task 4·5) 대조 표를 `docs/design-audits/2026-11-10-camera-focus/RESULTS.md`에 남긴다.
- 실기기 확인은 사용자만 가능(안내 받은 뒤 실제 렌즈 조정까지).

## 사용자가 정할 것

- 운영 DB 마이그레이션 적용 승인(Task 1 Step 6). 추천: 계획 승인과 별도로 그 시점에 한 번 더 확인.
- 운영자 발송 방법: SQL 편집기(추천, 이 계획 범위) / 관리 화면 신설(범위 밖, 후속).

## Global Constraints

- type 이름 `camera.focus_needed`, category = `split_part(type,'.',1)` = `camera`.
- 문구(Figma 원문 그대로): 스낵바 `카메라 렌즈 초점을 맞춰주세요` / `더보기`. 가이드 제목 `카메라 초점 가이드`. 가이드 3줄: `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요` · `렌즈 돌출 부분을 손으로 잡고 좌우로 천천히 돌리면서, 라이브 화면이 가장 선명해지는 위치를 찾아주세요` · `초점 조정이 필요하면 “카메라 렌즈 초점을 맞춰주세요” 안내 메시지가 표시돼요`.
- 알림함 표시: title `카메라 렌즈 초점을 맞춰주세요`, body `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요`, 분류 라벨 `카메라`.
- 색은 `VivaColors`/역할색만: `#F4F4F4`=`fillButton`, `#3C3C3C`=`labelSecondary`, `#949090`=`labelQuaternary`, `#C00306`=`mainDark`. 하드코딩 금지.
- 글자 크기는 Figma 그대로(임의 확대 금지), 고정 `TextScaler` 금지. 문자열은 `ko.json` + `.tr()`.
- 로딩 표시에 CircularProgressIndicator 금지.
- `lib/` 변경 → `pubspec.yaml` minor bump(현재 `0.175.11+502` → `0.176.0+503`, 병합 직전 main보다 한 칸 위로 재조정) + `CHANGELOG.md` 한글 항목.
- 운영 DB 적용은 `supabase db push` 금지(이력 불일치) — MCP `apply_migration`으로, 사용자 승인 후.
- 건드리지 않는 것: `claim_notification_outbox`, `dispatch-push`, 기존 12종 분기 문구·라우트, 수신 설정(`notification_preferences`), 푸시 수신·로컬 알림 코드, 가로 전체화면 라이브, `CameraDetailScreen`(`/crecam/cameras/:id`).

## Review Focus

1. **트리거 본문 복사 누락** — 새 함수에 기존 분기·env 수신 끔이 하나라도 빠지면 그 알림이 조용히 실패한다. → Task 1 Step 1 테스트가 기존 12종 `WHEN` 전부와 `env_vent_delay`·`env_mist_gap` 문자열 존재를 검사.
2. **계정 전환** — A 계정의 미읽음 안내가 B 계정 화면에 남으면 안 된다. → Task 2 테스트 `숨김 집합은 계정이 바뀌면 비워진다`.
3. **같은 안내 여러 건** — 운영자가 두 번 보냈으면 한 번 누름으로 둘 다 읽음. → Task 2 테스트 `dismiss는 미읽음 초점 안내 전부를 읽음 처리한다`.
4. **카메라 0대 사용자에게 보냄** — 라이브가 없으니 스낵바도 없고, 알림함 탭은 `/crecam`으로. → Task 3 테스트.
5. **글자 2배** — 스낵바·가이드가 넘치지 않는다. → Task 4·5에서 `text_scale_overflow_test.dart`에 추가.

---

### Task 1: DB 트리거·ingest 계약에 `camera.focus_needed` 추가 + 운영자 발송 문서

**Files:**
- Create: `supabase/migrations/20261110000000_notification_camera_focus.sql`
- Modify: `supabase/functions/_shared/notification-contract.mjs` (`notificationTypes`, `validatePayload`)
- Test: `supabase/functions/_shared/notification-migration.test.mjs`, `supabase/functions/_shared/notification-contract.test.mjs`
- Create: `docs/ops/camera-focus-notice.md`

**Context:**
- Depends on: 없음
- Produces: 운영에서 `notification_events(type='camera.focus_needed')` INSERT → `app_notifications(kind='camera.focus_needed', category='camera', route='/crecam')` 1행, outbox 0행.
- Must know: 함수 본문은 20261103 파일의 `$$…$$`를 **한 글자도 바꾸지 말고** 복사한 뒤 아래 두 곳만 더한다. CASE에 ELSE가 없다. payload는 비어 있어도 된다(사람 단위).
- Acceptance: `node --test supabase/functions/_shared/` 통과.

- [ ] **Step 1: 실패하는 마이그레이션 테스트** — `notification-migration.test.mjs`에 새 파일을 읽고:

```js
test('camera focus migration keeps every existing branch and adds camera.focus_needed without push', () => {
  const fn = cameraFocusMigration.match(/CREATE OR REPLACE FUNCTION public\.notification_event_after_insert\(\)[\s\S]*?\n\$\$;/)?.[0];
  const check = cameraFocusMigration.match(/ADD CONSTRAINT notification_events_type_check CHECK \([\s\S]*?\)\);/)?.[0];
  assert.ok(fn && check);
  for (const t of ['highlight.ready','device.action.started','device.action.ended','device.action.failed',
    'device.action.skipped','community.comment','community.like_digest','notice.published',
    'maintenance.water_tank','safety.alert','safety.recovered','env.alert.triggered','camera.focus_needed']) {
    assert.ok(fn.includes(`WHEN '${t}' THEN`), `branch ${t}`);
    assert.ok(check.includes(`'${t}'`), `check ${t}`);
  }
  // 직전 본문(20261103)의 수신 끔 분기가 그대로 남았는지
  for (const s of [String.raw`LIKE 'env\_vent\_%'`, String.raw`LIKE 'env\_mist\_%'`, 'SELECT p.env_temp']) {
    assert.ok(fn.includes(s), s);
  }
  assert.ok(fn.includes("v_route := '/crecam';"));
  assert.ok(fn.includes("AND NEW.type <> 'camera.focus_needed' THEN")); // outbox 건너뜀
});
```

- [ ] **Step 2: 실패 확인** — `node --test supabase/functions/_shared/notification-migration.test.mjs` → FAIL(파일 없음).

- [ ] **Step 3: 마이그레이션 작성** — 헤더 주석에 바탕 md5 `ce5e129f30f3e72f4ccf8fe10584c6fd`와 이 계획 경로를 적는다. 내용:

```sql
ALTER TABLE public.notification_events DROP CONSTRAINT IF EXISTS notification_events_type_check;
ALTER TABLE public.notification_events ADD CONSTRAINT notification_events_type_check CHECK (type IN (
  'highlight.ready','device.action.started','device.action.ended','device.action.failed',
  'device.action.skipped','community.comment','community.like_digest','notice.published',
  'maintenance.water_tank','safety.alert','safety.recovered','env.alert.triggered',
  'camera.focus_needed'
));
-- 이어서 CREATE OR REPLACE FUNCTION public.notification_event_after_insert() — 20261103 본문 그대로 + ↓ 두 곳
```

  ① `WHEN 'env.alert.triggered' THEN … v_route := '/env-detail';` 바로 뒤, `END CASE;` 앞에:

```sql
    WHEN 'camera.focus_needed' THEN
      -- 운영자 수동 안내(사람 단위, 2026-11-10). 앱이 라이브 위 스낵바로 띄우고
      -- 알림함에도 남긴다. 푸시는 보내지 않는다(아래 outbox 조건).
      v_title := '카메라 렌즈 초점을 맞춰주세요';
      v_body := '영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요';
      v_route := '/crecam';
```

  ② 마지막 outbox INSERT 조건을 `IF v_notification_id IS NOT NULL AND v_push_enabled AND NEW.type <> 'camera.focus_needed' THEN`으로.

- [ ] **Step 4: 계약 테스트 먼저** — `notification-contract.test.mjs`:

```js
test('camera focus는 빈 payload로 통과', () =>
  assert.equal(validateNotificationEvent({ ...baseEvent(), type: 'camera.focus_needed', payload: {} }).ok, true));
```
  (`baseEvent`가 없으면 파일의 기존 이벤트 생성 헬퍼를 쓴다.) 실패 확인 후 `notificationTypes`에 `'camera.focus_needed'` 추가, `validatePayload`에 `if (type === 'camera.focus_needed') return null;`.

- [ ] **Step 5: 통과 확인** — `node --test supabase/functions/_shared/` → 전부 PASS.

- [ ] **Step 6: 운영자 문서** — `docs/ops/camera-focus-notice.md`: 보내기 SQL(이메일로 대상 찾기, 매번 새 `source_event_id`)과 확인 SQL.

```sql
insert into public.notification_events (source, source_event_id, user_id, type, occurred_at, payload)
select 'external', 'ops-focus-' || gen_random_uuid(), u.id, 'camera.focus_needed', now(), '{}'::jsonb
from auth.users u where u.email = '<대상 이메일>';
```
  사용자가 누르기 전 취소하려면 해당 `app_notifications` 행의 `read_at = now()`.

- [ ] **Step 7: 커밋** — `feat(notification): 카메라 초점 안내 알림 종류 추가(푸시 없음)`. **운영 적용은 하지 않는다**(Task 6).

### Task 2: 초점 안내 상태 provider

**Files:**
- Create: `lib/features/notification/presentation/focus_notice_providers.dart`
- Modify: `lib/features/notification/domain/app_notification.dart` (상수 `cameraFocusNotificationKind = 'camera.focus_needed'`, `knownNotificationKinds`에 추가)
- Test: `test/features/notification/focus_notice_providers_test.dart`

**Context:**
- Depends on: 없음(DB 미적용이어도 가짜 store로 테스트)
- Consumes: `notificationsProvider`, `notificationRepositoryProvider.markRead(String id)`, `currentUserProvider`
- Produces:
  - `final pendingFocusNoticeIdsProvider = Provider<List<String>>` — 읽지 않은 `camera.focus_needed` id 중 로컬 숨김 집합에 없는 것. 로딩·에러면 `[]`.
  - `final focusNoticeVisibleProvider = Provider<bool>` — 위 목록이 비어 있지 않음.
  - `Future<void> dismissFocusNotices(WidgetRef ref)` — 현재 id들을 로컬 숨김 집합에 먼저 넣고, 각각 `markRead`. 실패는 삼킨다(로그만).
  - 숨김 집합 `_dismissedFocusNoticeIdsProvider`(StateProvider<Set<String>>)는 `currentUserProvider.select((u) => u?.id)`를 watch해 계정이 바뀌면 비워진다.
- Must know: 알림함 탭으로 읽음 처리돼도 stream의 `readAt`으로 자동 반영된다 — 별도 연결 불필요.
- Acceptance: 아래 테스트 통과.

- [ ] **Step 1: 실패하는 테스트** (`notification_test_host.dart`의 가짜 store 패턴 재사용):
  - `미읽음 초점 안내가 있으면 보인다` — 행 1개(kind `camera.focus_needed`, read_at null) → `focusNoticeVisibleProvider == true`.
  - `읽은 안내·다른 종류는 무시한다` — read_at 있음 + `highlight.ready` 미읽음 → false.
  - `dismiss는 미읽음 초점 안내 전부를 읽음 처리한다` — 2건 → dismiss 후 store.markRead 호출 id = 두 건, visible 즉시 false(stream 갱신 전).
  - `숨김 집합은 계정이 바뀌면 비워진다` — A에서 dismiss → B로 전환(B에도 미읽음 1건) → visible true.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/notification/focus_notice_providers_test.dart` → FAIL.
- [ ] **Step 3: 구현** (Produces 시그니처 그대로).
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS + `flutter test test/features/notification/` 전체 PASS.
- [ ] **Step 5: 커밋** — `feat(notification): 카메라 초점 안내 상태 provider`.

### Task 3: 알림함에서 초점 안내 열기

**Files:**
- Modify: `lib/features/notification/domain/notification_route.dart` (허용 목록에 `/crecam`)
- Create: `lib/features/notification/domain/focus_notice_target.dart`
- Modify: `lib/features/notification/presentation/notification_center_screen.dart` (`_open`, `_category`에 `camera`)
- Modify: `assets/l10n/ko.json` (`notifications_category_camera`: `카메라`)
- Test: `test/features/notification/focus_notice_target_test.dart`, `notification_route_test.dart`, `notification_center_screen_test.dart`

**Context:**
- Depends on: Task 2(상수)
- Produces: `String focusNoticeRoute({required List<String> myCameraIds, required String? selectedCameraId})` — `selectedCameraId`가 목록에 있으면 `/crecam/cameras/$id/live`, 아니면 첫 id로 같은 형식, 목록이 비면 `/crecam`.
- Must know: `_open`은 kind가 `cameraFocusNotificationKind`면 `camerasProvider.future`(5초 timeout, 실패 시 `[]`)의 id와 `selectedCrecamCameraProvider`로 경로를 정해 push. 다른 kind는 기존 그대로. 계정 가드(`currentUserProvider.id != userId`)를 await 뒤 다시 본다.
- Acceptance: 테스트 통과, 기존 알림함 테스트 무회귀.

- [ ] **Step 1: 실패하는 테스트**
  - `focusNoticeRoute`: (`['a','b']`,`'b'`)→`/crecam/cameras/b/live`; (`['a','b']`,`'z'`)→`/crecam/cameras/a/live`; (`[]`,`null`)→`/crecam`.
  - `sanitizeNotificationRoute('/crecam') == '/crecam'`.
  - 알림함: 초점 안내 행 탭 → 읽음 + 선택 카메라 상세 경로로 push, 분류 라벨 `카메라`.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/notification/`.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS.
- [ ] **Step 5: 커밋** — `feat(notification): 알림함에서 초점 안내를 카메라 상세로 연다`.

### Task 4: 라이브 위 스낵바(카메라 탭·홈)

**Files:**
- Create: `lib/features/my_cage/presentation/widgets/focus_notice_snack_bar.dart`
- Modify: `lib/features/my_cage/presentation/widgets/camera_live_area.dart` (Stack에 추가)
- Modify: `lib/features/home/presentation/widgets/top_fixed_area.dart` (Stack에 추가)
- Modify: `assets/l10n/ko.json` (`camera_focus_notice`, `camera_focus_notice_more`)
- Test: `test/features/my_cage/focus_notice_snack_bar_test.dart`, `test/design/text_scale_overflow_test.dart`

**Context:**
- Depends on: Task 2
- Consumes: `focusNoticeVisibleProvider`, `dismissFocusNotices(ref)`
- Produces: `class FocusNoticeSnackBar extends ConsumerWidget { const FocusNoticeSnackBar({super.key, required this.cameraId}); static const tapKey = Key('focus_notice_snack_bar'); }` — 안 보일 땐 `SizedBox.shrink()`.
- Must know (Figma 1813:8260 실측):
  - 배치: 라이브 틀 Stack 안 `Positioned(top: 12, left: 12, right: 12)`. 두 화면 모두 `!offline`일 때만 넣는다(확대 버튼과 같은 조건).
  - 면: `fillButton`, 모서리 r8, 좌우 패딩 16, 최소 높이 36(글자 크면 늘어남 — 고정 높이 금지).
  - 본문: Pretendard Medium 16 / 줄높이 28 / 자간 −0.32 / `labelSecondary`, `Expanded` + `maxLines: 2`. "더보기": SemiBold 16 / 줄높이 28 / 자간 −0.32 / `mainDark`, 본문과 간격 8 이상.
  - 막대 전체가 한 터치 영역(`InkWell`, `tapKey`). 누르면 `context.push('/crecam/cameras/$cameraId/live')` 후 `dismissFocusNotices(ref)` — 이동을 먼저(await 하지 않음).
  - `cameraId`: 카메라 탭은 `current.id`, 홈은 `camera.id`.
- Acceptance: 테스트 통과, `flutter analyze` 0.

- [ ] **Step 1: 실패하는 테스트**
  - `안내가 있으면 문구와 더보기가 보인다` — `find.text('카메라 렌즈 초점을 맞춰주세요')`, `find.text('더보기')`.
  - `누르면 상세로 이동하고 사라진다` — 라우터 가짜로 push 경로 `/crecam/cameras/c1/live` 확인, 이후 `find.byKey(tapKey)` 없음.
  - `안내가 없으면 아무것도 그리지 않는다`.
  - `text_scale_overflow_test.dart`에 스낵바 1.0/1.3/2.0 무오버플로 추가.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/my_cage/focus_notice_snack_bar_test.dart`.
- [ ] **Step 3: 위젯 구현 + 두 Stack에 배치**.
- [ ] **Step 4: 통과 확인** — 위 명령 + `flutter test test/design/text_scale_overflow_test.dart` + `flutter test test/features/home/ test/features/my_cage/` PASS.
- [ ] **Step 5: 커밋** — `feat(camera): 라이브 위 렌즈 초점 안내 스낵바`.

### Task 5: 카메라 상세 '카메라 초점 가이드'(항상 노출)

**Files:**
- Create: `lib/features/my_cage/presentation/widgets/camera_focus_guide.dart`
- Modify: `lib/features/my_cage/presentation/camera_live_fullscreen_screen.dart` (`_buildPortrait`, 전원 줄 다음)
- Modify: `assets/l10n/ko.json` (`camera_focus_guide_title`, `camera_focus_guide_1`, `_2`, `_3`)
- Test: `test/features/my_cage/camera_focus_guide_test.dart`, `test/design/text_scale_overflow_test.dart`

**Context:**
- Depends on: 없음
- Produces: `class CameraFocusGuide extends StatelessWidget { const CameraFocusGuide({super.key}); }`
- Must know (Figma 1813:8229 실측): 전원 줄 아래 간격 24. 제목 SemiBold 16 / 줄높이 19.09(≈1.19) / 자간 −0.32 / `labelQuaternary`. 제목→상자 8. 상자 `fillButton`, r16, 패딩 12(사방), 너비는 줄 목록과 같은 345 폭(부모 좌우 여백 그대로). 문장 3개 Medium 14 / 줄높이 21 / 자간 −0.28 / `labelSecondary`, 문장 간 8. 세로 화면만, 가로 레이아웃엔 넣지 않는다. 세로 화면 본문이 스크롤 영역인지 먼저 확인하고, 아니면 가이드가 하단 재시작 버튼에 가리지 않게 스크롤 가능하게 한다(재시작 버튼은 지금 위치 유지).
- Acceptance: 테스트 통과, 시뮬레이터 캡처에서 위 수치 대조.

- [ ] **Step 1: 실패하는 테스트** — `세로 상세에 초점 가이드 제목과 3문장이 있다`(Global Constraints 문구 그대로 `find.text`), `가로에는 없다`, 글자 2.0 무오버플로.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/my_cage/camera_focus_guide_test.dart`.
- [ ] **Step 3: 구현**.
- [ ] **Step 4: 통과 확인** — 위 명령 + `flutter test test/design/` PASS.
- [ ] **Step 5: 커밋** — `feat(camera): 카메라 상세 초점 가이드`.

### Task 6: 버전·패치노트·운영 적용·화면 검수

**Files:**
- Modify: `pubspec.yaml`, `CHANGELOG.md`
- Create: `docs/design-audits/2026-11-10-camera-focus/RESULTS.md`

**Context:**
- Depends on: Task 1~5
- Must know: 운영 적용은 **사용자 승인 뒤** 메인이 MCP `apply_migration`(name `notification_camera_focus`)으로. 적용 전 운영 prosrc md5가 여전히 `ce5e129f…`인지 다시 확인 — 다르면 중단하고 보고(그사이 다른 세션이 바꾼 것).
- Acceptance: 아래 확인 SQL 결과 + 캡처 대조표.

- [ ] **Step 1:** `0.176.0+503`(병합 직전 main 대비 재조정), CHANGELOG `추가` 3줄(초점 안내 스낵바·알림함 / 상세 초점 가이드 / 운영자 발송 경로). `flutter analyze` 0, `flutter test` 전체 PASS 후 커밋.
- [ ] **Step 2 (승인 후):** 적용 → 확인 SQL: prosrc에 `camera.focus_needed` 포함, CHECK 13종. 운영자 본인 계정 테스트 행 1건 → `app_notifications` 1행·`notification_outbox` 0행, 확인 후 그 행 `read_at` 처리.
- [ ] **Step 3:** 시뮬레이터에서 유저 체험 시뮬레이션 1~9 캡처, Figma 수치 대조표 작성(13 mini 배율 주의: 앱 이미지 104.17% 확대 후 비교). 커밋.
