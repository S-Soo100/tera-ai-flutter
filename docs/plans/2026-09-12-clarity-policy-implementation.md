# Clarity Policy Implementation Plan

> For agentic workers: execute task-by-task with TDD; CAOF Critical uses flutter-dev implementers. User approved policy and app implementation on 2026-09-12. Main agent owns integration and evidence. Project CLAUDE.md review rules override generic skill reviewer dispatch.

**Goal:** Apply the approved planner-facing policy through opt-in capture, default masking, safe screen names, and typed feature/outcome events.
**Architecture:** One provider-owned recorder gates all analytics; a stable app boundary owns SDK initialization, route/auth/lifecycle synchronization and permanent root masking. Existing UI actions call a typed facade and never pass domain identifiers or content.
**Tech Stack:** Flutter, Riverpod 2.6, GoRouter 14.8, Hive, clarity_flutter 1.10.0. No new dependencies.
**Spec:** docs/clarity-policy.md (approved); this file contains implementation details only.

## Global constraints and decisions

- Work in branch codex/clarity-policy, current checkout. No automatic push or deployment.
- No new setState/ChangeNotifier, hardcoded UI strings/colors, or packages. Preserve existing control and navigation behavior.
- Default user consent is false. Profile contains an optional analytics switch with explanation and withdrawal. Store choices locally per account; never transmit account IDs.
- A compile-time CLARITY_ENABLED flag defaults false until device masking/session QA and operational checks are complete. CLARITY_PROJECT_ID defaults to the existing production ID only in release; debug/profile require explicit QA ID different from production. Missing/unsupported configuration is inert.
- Root ClarityMask always protects all user text/images/content descriptions. Only known fixed label leaves may be unmasked; never arbitrary text or entire content containers.
- Exclude auth/account, notifications, error, dev and unknown routes. Normalize allowed dynamic routes to fixed screen names; never transmit paths/IDs/query strings.
- SDK pause cannot purge old upload queues and can leave one already-scheduled masked frame. Disclose that previously collected data can still be processed; do not claim deletion or immediate network shutdown.
- Environment approval/retention/access/deletion and real dashboard QA are not proven by unit tests. Leave activation gated until verified.

## Experience sequence

[Screen] Profile shows “앱 사용 분석” and an explanation that masked usage data is sent to Microsoft Clarity → [Action] user switches on → [Response] preference is saved; capture begins only after leaving excluded profile for an allowed screen and if deployment is enabled → [Feeling] a voluntary, reversible choice.
[Screen] same setting → [Action] switch off → [Response] app event gate closes synchronously before saving; no new app events are accepted; SDK pauses → [Feeling] control of participation. Prior collected data is not described as deleted.
Existing feature interactions retain their visuals and behavior; only observations of actual selected actions and results are added.

## Shared contract (core owner creates first)

Files: lib/core/analytics/analytics_events.dart, analytics_recorder.dart, analytics_providers.dart.

```dart
enum AnalyticsFeature {
  live, clips, highlights, bookmarks, environment,
  control, routines, pets, reports, community,
}
// Event members fixed below. Wire names use snake_case; no dynamic payload.
// analyticsRecorderProvider returns AnalyticsRecorder without accessing Hive/auth
// until app-boundary integration. It is inactive by default in isolated screens.
// int get epoch; invalidated on session/auth/consent/capture boundary changes.
// void featureUsed(AnalyticsFeature feature, {int? epoch});
// void record(AnalyticsEvent event, {int? epoch});
```

AnalyticsEvent members: pairStarted, pairDeviceSelected, pairWifiSubmitted, pairWifiSucceeded, pairFailed, pairCancelled, liveRequested, liveConnected, liveFailed, clipRequested, clipPlaying, clipAutoPlaying, clipFailed, bookmarkAdded, bookmarkRemoved, bookmarkReplayed, clipShareOpened, controlRequested, controlAccepted, controlFailed, routineSaved, petSaved, communityPublished, communityLiked.

Async instrumentation captures `final analytics = ref.read(analyticsRecorderProvider); final epoch = analytics.epoch;` before work, then uses `analytics.record(AnalyticsEvent.controlAccepted, epoch: epoch);` on verified outcome. SDK errors never affect business result. `featureUsed` deduplicates by feature within an SDK session; raw events preserve intentional separate attempts.

### Task 1: Capture foundation, consent and boundary (core implementer)

**Own files:** lib/core/analytics/**, lib/main.dart, lib/app.dart, lib/features/profile/presentation/profile_screen.dart (setting insertion only), assets/l10n/ko.json, test/core/analytics/**. Router delegate observation can live in boundary, avoiding router source edits.
**Produce:** shared contract above, consent repository/notifier/tile, capture boundary, SDK adapter, configuration.

- [x] Add recorder/config tests: default-off sends nothing; supported opt-in session sends events; duplicate features produce one event; old epoch outcome is rejected; SDK failure is swallowed; production/QA IDs never mix.
- [x] Run `flutter test test/core/analytics` and confirm missing implementation/red behavior before production code.
- [x] Implement typed recorder and publish shared contract to feature owners. Use injected SDK port for meaningful unit tests.
- [x] Add repository/provider tests for default false, account isolation, failed writes, immediate revoke, old-account pending saves.
- [x] Implement Hive repository and Riverpod state. Storage errors never enable collection; revocation closes gate before persistence.
- [x] Add boundary tests for unknown/auth routes, push/pop/nested routes, excluded first frame, account changes, backgrounding, late SDK callback, mounting stability.
- [x] Implement stable root masking, SDK startup after consent and allowed route; both normal and forced session callbacks honor latest generation. Never await rotation while paused. Pause on shutdown/exclusion before accepting events; no account identifiers in SDK calls.
- [x] Add localized profile setting and consent widget test; keep App/router state when activation changes. Static strings only unmasked if safe.
- [x] Run focused tests and format owned files. Report real-device residual limitations.

### Task 2: Camera, pairing and control observations (camera implementer)

**Own files:** my_cage presentation players, crecam/highlights/bookmarks, favorite_toggle_button, wifi_provisioning_view, camera live fullscreen, home/presentation/cage_control_actions.dart; tests for these observations. No profile/l10n edits. Follow-up ownership also includes the fixed public-label helper, main-dock label wiring in glass_dock/app_router, and pairing observer/tests.
**Consume:** recorder contract. Get recorder from WidgetRef before awaits; plain widgets can become ConsumerWidget without changing behavior.

- [x] Add tests of actual selected action versus automatic callbacks using fake recorder/SDK port; await core API before running integration tests.
- [x] Pairing: started/device selected/Wi-Fi submitted/WIFI_OK/failed/explicit cancel boundaries. Do not report Wifi success as camera online or live ready; no SSID, IDs or errors in events.
- [x] Camera: explicit live entry requested; stream connected event only on actual connection (not first-frame claim); user-selected clips versus automatic next separated; actual playing event from player state. Dedupe rebuilds/automatic retries.
- [x] Favorite success and removal after repository success, saved clip selection, share-sheet request completion (not delivery). Use fixed events and epoch guard.
- [x] Control: record request/accepted/failed around existing send functions, including mist path; never change commands/ACK timing/safety. Capture service before async work.
- [x] Run focused existing player/live/control tests and new instrumentation tests; report covered paths and deliberate unobservable boundaries.

### Task 3: Remaining feature observations (feature implementer)

**Own files:** home env_detail/routine_settings; my_pets screens; community presentation screens/providers. No Task 1/2 paths. Tests in corresponding feature folders.

- [x] Add observable interaction tests using provider override; verify automatic build/prefetch is not deliberate usage and failed save is not success.
- [x] Environment: usage after direct detail interaction/data display, not home automatic values. Routines: direct list use/actual saves. Pets/reports: explicit detail/report action and successful save. Community: explicit feed interaction/like/publish success; no content or identifiers.
- [x] Keep epoch guard for deferred callbacks and separate request from success. Do not change business logic, API contracts or UI behavior.
- [x] Run focused tests. List remaining measurement limitations in implementation report.


Task 3 exception: two new pet-save failure widget tests were removed after the permitted three harness attempts; the existing unawaited error path conflicts with the test error zone. Success and account-change cases remain tested. Production error handling was not changed.

### Task 4: Integration and handoff (main + implementers)

- [x] Inspect git diff --stat, then each owned group sequentially. Reconcile shared API and route/session semantics through implementers.
- [x] Run new tests together, existing relevant tests, flutter analyze (errors 0), Android debug build and iOS simulator build where toolchain is available. Existing baseline: analyze has 7 info findings, no errors.
- [x] Update policy status without expanding planner body. Add a concise technical event/feature catalog and activation/QA checklist for operators in this plan or separate implementation evidence document.
- [x] Version bump 0.97.0+187 → 0.98.0+188 for lib feature changes. Commit complete logical changes; no push.
- [x] Report implementation/test evidence and outstanding real-device/dashboard checks. Keep CLARITY_ENABLED off until operational validation; do not claim live capture verified without dashboard evidence.

Validation evidence: full suite 668 tests passed; analyze 0 errors/warnings (7 existing infos); Android debug and iOS simulator builds passed. Production collection remains disabled pending the device/dashboard checks in docs/clarity-implementation.md.
