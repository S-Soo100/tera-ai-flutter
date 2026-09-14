# Android FCM Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비바나트 Android 앱이 Supabase 계정에 FCM token을 등록하고, 원격 알림을 수신·표시·안전한 화면 이동·읽음 처리하며, Supabase가 외부 이벤트를 idempotent하게 저장·발송하도록 만든다.

**Architecture:** Supabase의 `push_devices`, `app_notifications`, `notification_events`, `notification_outbox`가 SOT다. Flutter는 Firebase Messaging과 Repository/Riverpod 계층으로 기기 token 및 알림 센터를 연결하고, Supabase Edge Functions는 전용 ingest secret으로 이벤트를 받아 Firebase HTTP v1으로 전송한다.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase, Firebase Core, Firebase Messaging, flutter_local_notifications, PostgreSQL/RLS, Supabase Edge Functions

**Spec:** `docs/superpowers/specs/2026-09-15-android-fcm-notifications-design.md`

## Global Constraints

- Android 앱 ID는 `com.vivanaut.app`, Firebase project는 `vivanaut-app`이다.
- Android만 구현하며 iOS/APNs와 Apple Developer 작업은 제외한다.
- FCM token·알림·읽음·outbox SOT는 Supabase다.
- 외부 생산자에게 Supabase service-role 또는 Firebase 자격 증명을 제공하지 않는다.
- 허용 route만 이동하며 외부 URL과 알 수 없는 route는 `/notifications`로 제한한다.
- Riverpod만 사용하고 Widget의 직접 데이터 접근을 금지한다.
- UI 문자열은 `assets/l10n/ko.json`, 색상은 Theme/AppTheme 역할색을 사용한다.
- `CircularProgressIndicator`를 사용하지 않고 로딩은 skeleton을 사용한다.
- `lib/` 변경과 함께 버전을 `0.103.0+205`로 올리고 같은 커밋에 한글 `CHANGELOG.md`를 기록한다.
- 테스트는 RED 확인 후 최소 구현으로 GREEN을 만들고, 최종 `flutter analyze`, `flutter test`, `flutter build apk --debug`를 통과시킨다.
- Firebase private key, FCM token, ingest secret을 Git·로그·패치노트에 남기지 않는다.

---

### Task 1: Supabase 알림 저장소와 외부 이벤트 계약

**Files:**
- Create: `supabase/migrations/2026-09-15_fcm_notifications.sql`
- Create: `supabase/functions/_shared/notification-contract.mjs`
- Create: `supabase/functions/_shared/notification-contract.test.mjs`
- Create: `supabase/functions/notification-ingest/index.ts`
- Modify: `docs/supabase-setup.md`

**Interfaces:**
- Consumes: `schema_version=1`, `event_id`, `type`, `occurred_at`, `user_id`, `payload` JSON contract from the spec.
- Produces: `push_devices`, `app_notifications`, `notification_events`, `notification_outbox`; RPC `register_push_device(p_installation_id uuid, p_fcm_token text, p_platform text, p_app_version text, p_locale text)` and `deactivate_push_device(p_installation_id uuid)`; ingest HTTP 202/400/401/422.

- [ ] **Step 1: Write failing contract tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateNotificationEvent } from './notification-contract.mjs';

test('accepts a matching scheduled action event', () => {
  assert.equal(validateNotificationEvent({
    schema_version: 1,
    event_id: 'command:c1:started',
    type: 'device.action.started',
    occurred_at: '2026-09-15T21:00:03+09:00',
    user_id: '4da7f48b-0000-4000-8000-111111111111',
    payload: { command_id: 'c1', device_id: 'd1', execution_source: 'schedule', execution_phase: 'started', action: 'fan_on', result: 'succeeded' },
  }).ok, true);
});

test('rejects a mismatched phase and unsupported source', () => {
  const result = validateNotificationEvent({
    schema_version: 1,
    event_id: 'command:c1:ended',
    type: 'device.action.ended',
    occurred_at: '2026-09-15T21:00:03+09:00',
    user_id: '4da7f48b-0000-4000-8000-111111111111',
    payload: { command_id: 'c1', device_id: 'd1', execution_source: 'manual', execution_phase: 'started', action: 'fan_off', result: 'succeeded' },
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `node --test supabase/functions/_shared/notification-contract.test.mjs`

Expected: FAIL because `notification-contract.mjs` does not exist or does not export `validateNotificationEvent`.

- [ ] **Step 3: Implement the contract validator and migration**

Implement `validateNotificationEvent(value)` to return `{ok:true,value}` or `{ok:false,status:400|422,error}`. Accept only the kinds in the approved spec; require UUID `user_id`, timezone-bearing ISO-8601, non-empty event ID and object payload; require matching `type/execution_phase/result` for device events and `schedule|timer` source.

The migration must:

```sql
create table public.push_devices (... unique (user_id, installation_id), unique (fcm_token));
create table public.app_notifications (... unique (user_id, dedupe_key));
create table public.notification_events (... unique (source, source_event_id));
create table public.notification_outbox (... check (status in ('pending','processing','sent','failed','cancelled')));
```

Enable RLS on all four tables. Authenticated users may select and mutate only their own `push_devices`; may select own `app_notifications` and update only `read_at`; cannot directly insert/delete notifications, events or outbox. Security-definer RPCs must set `search_path = public`, derive the user from `auth.uid()`, and revoke execution from `public` before granting to `authenticated`.

The event processing function must insert a single user notification and outbox row using `(user_id, source || ':' || source_event_id)` as dedupe key. Unknown future types are rejected at ingest rather than producing an untrusted route.

Add database-owned producers for the existing community tables: a comment by another user creates `community.comment` immediately; likes on the same post are merged by post owner and 10-minute KST-independent epoch bucket into one `community.like_digest` whose count/title/body are updated until dispatch; a new `community_notices` row fans out `notice.published` to authenticated users. Self-comment/self-like never notifies. Provide security-definer RPC `schedule_water_tank_notification(p_due_at timestamptz, p_enclosure_id uuid, p_enclosure_name text)` so the future settings UI can schedule `maintenance.water_tank` without granting clients direct notification/outbox insertion.

- [ ] **Step 4: Implement the ingest Edge Function**

Read `PUSH_EVENT_INGEST_SECRET`, compare `Authorization: Bearer ...`, validate the body, then insert `{source:'external', source_event_id:event_id, ...}` with service credentials. A unique conflict is an idempotent success. Return JSON with 202 for accepted/duplicate, 400 malformed, 401 auth failure and 422 unsupported type.

- [ ] **Step 5: Verify Task 1**

Run: `node --test supabase/functions/_shared/notification-contract.test.mjs`

Expected: PASS.

Run: `git diff --check`

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/2026-09-15_fcm_notifications.sql supabase/functions docs/supabase-setup.md
git commit -m "feat: add Supabase notification event store"
```

### Task 2: Firebase HTTP v1 outbox dispatcher

**Files:**
- Create: `supabase/functions/_shared/firebase-message.mjs`
- Create: `supabase/functions/_shared/firebase-message.test.mjs`
- Create: `supabase/functions/dispatch-push/index.ts`
- Modify: `supabase/migrations/2026-09-15_fcm_notifications.sql`
- Modify: `docs/supabase-setup.md`

**Interfaces:**
- Consumes: due `notification_outbox` rows and enabled `push_devices` from Task 1.
- Produces: RPC `claim_notification_outbox(p_limit integer)` and Firebase HTTP v1 requests containing `notification` plus string-only `data`; terminal token disable and outbox status updates.

- [ ] **Step 1: Write failing message builder tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildFirebaseMessage, classifyFcmFailure } from './firebase-message.mjs';

test('builds string-only data and safety channel', () => {
  const message = buildFirebaseMessage({ token: 'token', notificationId: 'n1', kind: 'safety.alert', title: '온도 경고', body: '확인해 주세요', route: '/env-detail' });
  assert.equal(message.message.android.notification.channel_id, 'vivanaut_safety');
  assert.deepEqual(message.message.data, { notification_id: 'n1', kind: 'safety.alert', route: '/env-detail' });
});

test('classifies unregistered token as terminal', () => {
  assert.equal(classifyFcmFailure(404, 'UNREGISTERED'), 'disable-token');
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run: `node --test supabase/functions/_shared/firebase-message.test.mjs`

Expected: FAIL because the module or exports do not exist.

- [ ] **Step 3: Implement claim RPC and message helpers**

`claim_notification_outbox` must use `for update skip locked`, atomically change due `pending` rows to `processing`, increment attempts and return at most the requested positive limit. `buildFirebaseMessage` must use `vivanaut_safety` only for `safety.*`, otherwise `vivanaut_default`. `classifyFcmFailure` must disable `UNREGISTERED`/invalid token, retry 429/5xx, and permanently fail other 4xx.

- [ ] **Step 4: Implement `dispatch-push`**

Use `FIREBASE_SERVICE_ACCOUNT_JSON` from Supabase secrets, create an RS256 JWT for OAuth scope `https://www.googleapis.com/auth/firebase.messaging`, exchange it at Google's OAuth token endpoint, then POST each active installation to `https://fcm.googleapis.com/v1/projects/vivanaut-app/messages:send`. Never log tokens or credentials. Mark rows sent when all active tokens are handled; requeue transient failures with bounded exponential delay; mark permanent failures with a safe error code; disable invalid token rows.

- [ ] **Step 5: Verify Task 2**

Run: `node --test supabase/functions/_shared/firebase-message.test.mjs`

Expected: PASS.

Run: `git diff --check`

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions supabase/migrations/2026-09-15_fcm_notifications.sql docs/supabase-setup.md
git commit -m "feat: dispatch notification outbox through FCM"
```

### Task 3: Flutter 알림 domain·Repository·안전 route

**Files:**
- Create: `lib/features/notification/domain/app_notification.dart`
- Create: `lib/features/notification/domain/notification_route.dart`
- Create: `lib/features/notification/data/notification_repository.dart`
- Create: `lib/features/notification/data/push_device_repository.dart`
- Create: `test/features/notification/app_notification_test.dart`
- Create: `test/features/notification/notification_route_test.dart`
- Create: `test/features/notification/notification_repository_test.dart`
- Modify: `lib/features/notification/presentation/notification_providers.dart`

**Interfaces:**
- Consumes: Supabase schema and RPCs from Task 1.
- Produces: immutable `AppNotification`, `sanitizeNotificationRoute(String?)`, `NotificationRepository.watchNotifications(userId)`, `markRead(id)`, `markAllRead(userId)`, `PushDeviceRepository.register(...)`, `deactivate(...)`, account-isolated Riverpod providers.

- [ ] **Step 1: Write failing parsing and route tests**

```dart
test('unknown kind remains visible as a general notification', () {
  final item = AppNotification.fromJson({'id':'n1','user_id':'u1','kind':'future.kind','category':'other','title':'제목','body':'본문','route':'https://evil.example','data':<String,dynamic>{},'created_at':'2026-09-15T12:00:00Z','read_at':null});
  expect(item.isRead, isFalse);
  expect(item.safeRoute, '/notifications');
});

test('allows only approved internal routes and UUID community ids', () {
  expect(sanitizeNotificationRoute('/env-detail'), '/env-detail');
  expect(sanitizeNotificationRoute('/community-player/4da7f48b-0000-4000-8000-111111111111'), '/community-player/4da7f48b-0000-4000-8000-111111111111');
  expect(sanitizeNotificationRoute('https://evil.example'), '/notifications');
  expect(sanitizeNotificationRoute('/profile'), '/notifications');
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `flutter test test/features/notification/app_notification_test.dart test/features/notification/notification_route_test.dart`

Expected: FAIL because the types do not exist.

- [ ] **Step 3: Implement domain and route allowlist**

Allow exact routes `/notifications`, `/crecam/highlights`, `/home/routines`, `/env-detail`; allow `/community-player/{uuid}` only. Keep title/body/data for unknown kinds but force its route to `/notifications`.

- [ ] **Step 4: Write failing Repository/provider tests**

Test that JSON rows sort newest first, `markRead` only sends the selected ID, unread count derives from `readAt == null`, and switching `currentUserProvider` yields no prior account rows. Use a small fake store interface rather than asserting mock call counts on Supabase internals.

- [ ] **Step 5: Implement repositories and providers**

`NotificationRepository` must expose a real-time stream filtered by `user_id`, a one-row `read_at` update, and a user-filtered mark-all RPC/update. `PushDeviceRepository` calls the security-definer RPCs and never logs token values. Providers must select-watch only `currentUserProvider`'s ID and emit an empty list/count for signed-out users.

- [ ] **Step 6: Verify Task 3**

Run: `flutter test test/features/notification/`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notification test/features/notification
git commit -m "feat: add account scoped notification repositories"
```

### Task 4: Firebase Messaging lifecycle와 권한 UX

**Files:**
- Create: `lib/features/notification/data/push_messaging_service.dart`
- Create: `lib/features/notification/presentation/push_lifecycle_observer.dart`
- Create: `lib/features/notification/presentation/push_permission_prompt.dart`
- Create: `test/features/notification/push_lifecycle_controller_test.dart`
- Create: `test/features/notification/push_permission_prompt_test.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `lib/shared/services/local_notifications.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `assets/l10n/ko.json`

**Interfaces:**
- Consumes: `PushDeviceRepository`, Firebase Messaging streams, route sanitizer, `LocalNotifications`.
- Produces: top-level `firebaseMessagingBackgroundHandler`, a single app lifecycle observer, explanation-sheet preference in Hive `app_settings`, permission retry action, logout token deactivation-before-signout.

- [ ] **Step 1: Add maintained Firebase dependencies**

Run: `flutter pub add firebase_core firebase_messaging`

Expected: dependency solve succeeds and lockfile records compatible versions.

- [ ] **Step 2: Write failing lifecycle tests**

Use injected token/permission/message ports. Assert: signed-out state does not register; signed-in + authorized registers installation ID/token; token refresh re-registers; logout calls deactivate before sign-out callback; duplicate foreground message ID is displayed once; a tapped unsafe route resolves to `/notifications`.

- [ ] **Step 3: Run focused tests and verify RED**

Run: `flutter test test/features/notification/push_lifecycle_controller_test.dart`

Expected: FAIL because the controller/service does not exist.

- [ ] **Step 4: Implement Firebase lifecycle**

Initialize Firebase after Supabase startup and register the background handler before `runApp`. `PushMessagingService` owns permission state, `getToken`, `onTokenRefresh`, `onMessage`, `onMessageOpenedApp`, and `getInitialMessage`. The observer watches only current user ID, disposes subscriptions, stores a stable random installation UUID in Hive, registers only after authorization, and delegates foreground display to the shared local notification core.

Extend `LocalNotifications` with two Android channels (`vivanaut_default`, `vivanaut_safety`) and one configurable tap callback without reinitializing the plugin. Preserve fan timer behavior.

- [ ] **Step 5: Write failing permission widget tests**

Assert the first authenticated eligible launch shows the Korean explanation sheet, `나중에` records the explanation as seen without calling OS permission, `알림 켜기` calls permission, and the notification center retry banner remains available when permission is denied.

- [ ] **Step 6: Implement permission UX and logout ordering**

Wrap the routed child in `PushLifecycleObserver` and `PushPermissionPrompt` from `App.builder`. Use localization keys for every visible string. In `ProfileScreen._logout`, await device deactivation first, catch/report without exposing token, then always call auth sign-out and route to login if mounted.

- [ ] **Step 7: Verify Task 4**

Run: `flutter test test/features/notification/push_lifecycle_controller_test.dart test/features/notification/push_permission_prompt_test.dart test/features/home/fan_timer_duration_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/app.dart lib/shared/services/local_notifications.dart lib/features/notification lib/features/profile/presentation/profile_screen.dart assets/l10n/ko.json test/features/notification
git commit -m "feat: register and receive Android push notifications"
```

### Task 5: Supabase 알림 센터와 릴리스 마감

**Files:**
- Modify: `lib/features/notification/presentation/notification_center_screen.dart`
- Create: `test/features/notification/notification_center_screen_test.dart`
- Create: `test/features/profile/profile_screen_test.dart`
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: account-isolated notification stream/count, `markRead`, `markAllRead`, route sanitizer, permission state from Tasks 3–4.
- Produces: 최신순 알림 목록, 빈/오류/로딩/권한 재시도 UI, 읽음 표시, 전체 읽음, 항목 탭 이동, 프로필 red dot.

- [ ] **Step 1: Write failing widget tests**

Test with provider overrides: skeleton while loading; localized empty state; error and retry action; unread row visual/key; tapping a row marks its ID then navigates to the safe route; mark-all clears unread count; denied permission shows `알림 켜기`; profile red dot exists only when count is positive.

- [ ] **Step 2: Run widget tests and verify RED**

Run: `flutter test test/features/notification/notification_center_screen_test.dart test/features/profile/profile_screen_test.dart`

Expected: FAIL because the live list UI and providers are not yet wired.

- [ ] **Step 3: Implement notification center**

Use `ConsumerWidget`, `GlassPageShell`, `SkeletonPageLoading`, themed list rows and `easy_localization`. Show category, title, body and localized relative/absolute time; unknown kind remains visible. Tap order is `markRead` then `context.push(safeRoute)` unless the route is `/notifications`, in which case remain on the page. Preserve cached data during refresh where Riverpod exposes it.

- [ ] **Step 4: Version and Korean patch notes**

Set `version: 0.103.0+205`. Add the newest `## 0.103.0+205 - 2026-09-15` section to `CHANGELOG.md` describing Android FCM token registration, permission UX, foreground/background taps, Supabase notification center/read state and backend event/outbox contract. Do not claim production push activation until secrets and deployment are verified.

- [ ] **Step 5: Run focused and full verification**

Run: `flutter test test/features/notification/ test/features/profile/profile_screen_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: 0 errors.

Run: `flutter test`

Expected: all non-opt-in tests pass.

Run: `flutter build apk --debug`

Expected: debug APK build succeeds.

Run: `rg -n "PRIVATE KEY|PUSH_EVENT_INGEST_SECRET=|fcm_token[^a-z_]" . --glob '!docs/superpowers/**' --glob '!docs/handoffs/**' --glob '!supabase/migrations/**'`

Expected: no committed secret value or token literal.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notification lib/features/profile test/features/notification test/features/profile pubspec.yaml CHANGELOG.md
git commit -m "feat: ship Android notification center"
```

### Task 6: 배포 가능성 점검과 안전한 운영 인계

**Files:**
- Create: `docs/handoffs/2026-09-15-fcm-deployment-checklist.md`
- Modify: `docs/fcm-notification-work-split.md`

**Interfaces:**
- Consumes: migration/functions/app build from Tasks 1–5.
- Produces: 실제 배포됨/로컬 준비됨/보안 입력 필요 상태가 분명한 운영 체크리스트.

- [ ] **Step 1: Inspect Supabase link/auth without changing remote state**

Run: `supabase projects list`

Expected: either project `slxjvzzfisxqwnghvrit` is accessible or the checklist records that login/link is needed.

- [ ] **Step 2: Verify deploy artifacts locally**

Run: `supabase db lint --local`

Expected: pass when a local Supabase stack is available; otherwise record the exact unavailable prerequisite without claiming deployment.

Run: `node --test supabase/functions/_shared/*.test.mjs`

Expected: PASS.

- [ ] **Step 3: Write deployment checklist**

Record exact commands for linking project `slxjvzzfisxqwnghvrit`, pushing migrations, deploying both functions, setting `PUSH_EVENT_INGEST_SECRET` and `FIREBASE_SERVICE_ACCOUNT_JSON`, and adding a scheduled invocation for `dispatch-push`. Secret values must be entered interactively or via an untracked local source, never pasted into the document.

The status table must distinguish:

- repository implementation complete;
- Android build verified;
- Supabase schema/functions deployed or not deployed;
- Firebase service account secret present or absent;
- physical Android test push verified or pending;
- terra-server and petcam-lab integration pending.

- [ ] **Step 4: Commit**

```bash
git add docs/handoffs/2026-09-15-fcm-deployment-checklist.md docs/fcm-notification-work-split.md
git commit -m "docs: add FCM deployment handoff checklist"
```
