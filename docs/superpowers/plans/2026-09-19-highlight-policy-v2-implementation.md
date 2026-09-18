# 하이라이트 정책 v2 Implementation Plan

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. Critical 트랙 — 사용자 "승인" 뒤 `flutter-dev` 에이전트에 task별로 전달(GATE 4). 에이전트는 계획서 범위 안에서만 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카메라 탭 전체 영상 목록을 "하이라이트 규칙 O 전부"로 바꾸고, 하이라이트(대표)는 밤 구간만 D+2일 08:00 KST에 앱이 시간으로 공개하며 도착을 알린다.

**Architecture:** (1) 공개 정책은 순수 도메인 함수(`highlight_night_policy.dart`)가 맡는다 — 서버가 `publication`을 안 주면 day_key로 **결정적 publication을 합성**해, 기존 도착 배너·읽음·"업데이트 N일 전" 로직을 그대로 재사용한다. (2) 전체 목록은 새 데이터 소스 `PassedClipFeedSource`가 petcam-api `/highlights`(cursor 페이지)로 통과 clip_id를 받고 Supabase `motion_clips`로 채워 기존 `MotionClipPage`를 돌려준다 — 피드 컨트롤러·플레이어·숨김 로직은 로더 한 줄만 바뀐다.

**Tech Stack:** Flutter · Riverpod · http(`MockClient` 테스트) · supabase_flutter · easy_localization

**기획 SOT:** [`../specs/2026-09-19-highlight-policy-v2-design.md`](../specs/2026-09-19-highlight-policy-v2-design.md) · 서버 요청: [`../../handoffs/2026-09-19-petcam-lab-highlight-policy-v2-request.md`](../../handoffs/2026-09-19-petcam-lab-highlight-policy-v2-request.md)

---

## 범위

**1단계(이 계획, 서버 작업 없음):** Task 1~8.
**2단계(petcam-lab 배포 후):** 앱 코드 변경 없음 — `until`은 1단계부터 보내고, `publication`·`highlight.ready` 수신 경로는 이미 있다. 알림 문구만 고친다(Task 9, 운영 DB 변경이라 별도 승인).

**건드리지 않는 것**
- 어젯밤 리포트(`nightlyReportProvider`·`nightly_report_view.dart`·홈 배지) — 기획서 §6-1 미결. 현행 유지.
- 활동시간 집계(`motionSeconds*`, `v_clip_effective_activity`) — 전체 클립 기준 유지.
- 북마크(`FavoriteClipRepository`)·커뮤니티 스냅샷 — 통과 여부와 무관하게 유지.
- `MotionClipRepository.listPage`·`listByCamera*` 자체는 남긴다(다른 소비처·테스트). 카메라 탭 피드와 플레이어 필름스트립만 새 소스로 바꾼다.
- 하이라이트 선정 규칙·`groupByDay`·읽음 저장소(`HighlightReadStore`)·배너 dismiss 저장소.

## 파일 구조

| 파일 | 책임 |
|---|---|
| Create `lib/features/my_cage/domain/highlight_night_policy.dart` | 밤 구간·공개 시각 계산(KST 고정), publication 합성, 밤 필터+공개 게이트, 다음 공개 시각 |
| Modify `lib/features/my_cage/domain/nightly_highlight.dart` | `withPublication()` 추가 |
| Modify `lib/features/my_cage/domain/motion_clip_page.dart` | `MotionClipCursor`에 서버 불투명 커서 `token` 추가 |
| Modify `lib/features/my_cage/data/highlight_repository.dart` | `listPassedPage()` — `/highlights` since·until·cursor·limit |
| Modify `lib/features/my_cage/data/motion_clip_repository.dart` | `getByIds()` — id 목록으로 채우기(+라벨) |
| Create `lib/features/my_cage/data/passed_clip_feed_source.dart` | 두 저장소를 묶어 `MotionClipPage` 반환, 범위 상한 재필터, 504 1회 재시도 |
| Modify `lib/features/my_cage/presentation/my_cage_providers.dart` | `highlightClockProvider`, 정책 적용, 08:00 자동 갱신, `latestHighlightAtProvider` 단순화, `passedClipFeedSourceProvider` |
| Modify `lib/features/my_cage/presentation/clip_feed_controller.dart` · `player_view_providers.dart` | 로더를 새 소스로 교체 |
| Modify `assets/l10n/ko.json` | 빈 목록 문구 2개 교체 |
| Modify `test/regression/redesign_baseline_guard_test.dart` · `CLAUDE.md` · `CHANGELOG.md` · `pubspec.yaml` | 가드·문서·버전 |

---

### Task 1: 밤 구간·공개 시각 도메인

**Context:**
- Depends on: 없음
- Inputs: 서버 `day_key`("YYYY-MM-DD", 밤이 **시작한** 날짜, 20:00 KST 경계). `NightlyHighlight`, `HighlightPublication`(이미 있음).
- Outputs: `nightWindowFor`, `applyNightPolicy`, `nextPublishAfter`, `NightlyHighlight.withPublication`
- Must know: **KST = UTC+9 고정(서머타임 없음).** 기기 시간대·`DateTime.now()`의 로컬 해석에 의존하지 말고 전부 UTC로 계산한다. D일 20:00 KST = D일 11:00 UTC / D+1일 08:00 KST = D일 23:00 UTC / D+2일 08:00 KST = D+1일 23:00 UTC. `DateTime.utc(y, m, d + 1, 23)`은 월말을 자동으로 넘긴다. `NightlyHighlight.startedAt`은 로컬 DateTime이므로 비교 전에 `.toUtc()`.
- Acceptance: `flutter test test/features/my_cage/highlight_night_policy_test.dart` → All tests passed

**Files:**
- Create: `lib/features/my_cage/domain/highlight_night_policy.dart`
- Modify: `lib/features/my_cage/domain/nightly_highlight.dart`
- Test: `test/features/my_cage/highlight_night_policy_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_night_policy.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';

NightlyHighlight _h(String id, DateTime startedAtUtc,
        {String dayKey = '2026-08-16', HighlightPublication? publication}) =>
    NightlyHighlight(
      clipId: id,
      cameraId: 'cam',
      startedAt: startedAtUtc.toLocal(),
      tier: 'featured',
      dayKey: dayKey,
      publication: publication,
    );

void main() {
  // 사용자 예시(2026-09-19): 8/16 밤~8/17 아침 촬영 → 8/18 아침 8시 공개.
  test('밤 구간은 D 20:00~D+1 08:00 KST, 공개는 D+2 08:00 KST', () {
    final w = nightWindowFor('2026-08-16')!;
    expect(w.captureStart, DateTime.utc(2026, 8, 16, 11)); // 8/16 20:00 KST
    expect(w.captureEnd, DateTime.utc(2026, 8, 16, 23)); // 8/17 08:00 KST
    expect(w.publishedAt, DateTime.utc(2026, 8, 17, 23)); // 8/18 08:00 KST
  });

  test('월말을 넘겨도 공개 시각이 맞다', () {
    expect(nightWindowFor('2026-08-31')!.publishedAt,
        DateTime.utc(2026, 9, 1, 23)); // 9/2 08:00 KST
  });

  test('형식이 깨진 day_key는 null', () {
    expect(nightWindowFor(''), isNull);
    expect(nightWindowFor('2026-8-16'), isNull);
  });

  test('공개 시각 전에는 숨기고, 정각부터 보인다', () {
    final night = _h('a', DateTime.utc(2026, 8, 16, 15)); // 8/17 00:00 KST
    expect(applyNightPolicy([night], DateTime.utc(2026, 8, 17, 22, 59)),
        isEmpty);
    final shown = applyNightPolicy([night], DateTime.utc(2026, 8, 17, 23));
    expect(shown.single.clipId, 'a');
    expect(shown.single.publication!.batchId, 'night:2026-08-16');
    expect(shown.single.publication!.publishedAt,
        DateTime.utc(2026, 8, 17, 23));
  });

  test('낮(08:00 KST 이후) 촬영분은 하이라이트에서 뺀다', () {
    final day = _h('d', DateTime.utc(2026, 8, 17, 1)); // 8/17 10:00 KST
    final edge = _h('e', DateTime.utc(2026, 8, 16, 23)); // 정확히 08:00 KST
    final night = _h('n', DateTime.utc(2026, 8, 16, 22, 59));
    final shown =
        applyNightPolicy([day, edge, night], DateTime.utc(2026, 8, 20));
    expect(shown.map((h) => h.clipId), ['n']);
  });

  test('서버가 publication을 주면 그 값을 우선한다', () {
    final server = HighlightPublication(
      batchId: 'srv',
      captureStart: DateTime.utc(2026, 8, 16, 11),
      captureEnd: DateTime.utc(2026, 8, 16, 23),
      publishedAt: DateTime.utc(2026, 8, 18, 23), // 서버가 하루 늦게 공개
      status: 'ready',
    );
    final h = _h('s', DateTime.utc(2026, 8, 16, 15), publication: server);
    expect(applyNightPolicy([h], DateTime.utc(2026, 8, 18)), isEmpty);
    expect(
        applyNightPolicy([h], DateTime.utc(2026, 8, 19)).single.publication!
            .batchId,
        'srv');
  });

  test('다음 공개 시각은 다음 23:00 UTC(08:00 KST)', () {
    expect(nextPublishAfter(DateTime.utc(2026, 8, 17, 22)),
        DateTime.utc(2026, 8, 17, 23));
    expect(nextPublishAfter(DateTime.utc(2026, 8, 17, 23)),
        DateTime.utc(2026, 8, 18, 23));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/highlight_night_policy_test.dart`
Expected: FAIL — `highlight_night_policy.dart` 없음(컴파일 에러)

- [ ] **Step 3: `NightlyHighlight.withPublication` 추가**

`lib/features/my_cage/domain/nightly_highlight.dart`의 `bool get isFeatured => tier == 'featured';` 바로 아래에 추가:

```dart
  /// 공개 메타만 바꾼 사본 — 서버가 publication을 주지 않을 때 앱이 day_key로
  /// 합성한 값을 붙인다([applyNightPolicy], 정책 v2 2026-09-19).
  NightlyHighlight withPublication(HighlightPublication value) =>
      NightlyHighlight(
        clipId: clipId,
        publication: value,
        startedAt: startedAt,
        cameraId: cameraId,
        cameraName: cameraName,
        durationSec: durationSec,
        source: source,
        reason: reason,
        ruleVersion: ruleVersion,
        decidedAt: decidedAt,
        tier: tier,
        dayKey: dayKey,
        activitySec: activitySec,
        behaviorFlagged: behaviorFlagged,
        episodeRank: episodeRank,
        episodeHourRank: episodeHourRank,
        episodeClipCount: episodeClipCount,
        episodeActivitySec: episodeActivitySec,
        episodeStartedAt: episodeStartedAt,
        episodeEndedAt: episodeEndedAt,
        playFromSec: playFromSec,
      );
```

- [ ] **Step 4: 정책 구현**

`lib/features/my_cage/domain/highlight_night_policy.dart`:

```dart
import 'highlight_publication.dart';
import 'nightly_highlight.dart';

/// 하이라이트 정책 v2(2026-09-19 사용자 확정) — 밤 구간만, D+2일 08:00 KST 공개.
///
/// 공개 시각이 날짜만의 함수라 서버 상태 없이 앱이 계산한다(검수가 늦어도
/// 기다리지 않는다). **KST = UTC+9 고정**이므로 전부 UTC로 계산한다 — 기기
/// 시간대·시계 설정과 무관하게 같은 순간에 열린다.
typedef NightWindow = ({
  DateTime captureStart,
  DateTime captureEnd,
  DateTime publishedAt,
});

final _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// day_key(밤이 시작한 날짜 D) → 촬영 D 20:00~D+1 08:00 KST, 공개 D+2 08:00 KST.
/// 형식이 깨졌으면 null.
NightWindow? nightWindowFor(String dayKey) {
  final m = _dayKeyPattern.firstMatch(dayKey);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  return (
    captureStart: DateTime.utc(y, mo, d, 11), // D 20:00 KST
    captureEnd: DateTime.utc(y, mo, d, 23), // D+1 08:00 KST
    publishedAt: DateTime.utc(y, mo, d + 1, 23), // D+2 08:00 KST
  );
}

/// 서버 목록에 정책을 입힌다: ① 밤 구간 밖(낮) 촬영분 제거 ② publication이
/// 없으면 day_key로 합성 ③ 아직 공개 시각 전인 항목 제거.
///
/// 서버가 publication을 주면 그 값을 그대로 쓴다(공개 시각·구간 모두).
/// day_key를 못 읽는 항목은 공개 시각을 알 수 없으므로 버린다.
List<NightlyHighlight> applyNightPolicy(
    List<NightlyHighlight> highlights, DateTime now) {
  final result = <NightlyHighlight>[];
  for (final h in highlights) {
    final server = h.publication;
    if (server != null) {
      if (server.availableAt(now)) result.add(h);
      continue;
    }
    final window = nightWindowFor(h.dayKey);
    if (window == null) continue;
    final at = h.startedAt.toUtc();
    if (at.isBefore(window.captureStart) || !at.isBefore(window.captureEnd)) {
      continue;
    }
    final publication = HighlightPublication(
      batchId: 'night:${h.dayKey}',
      captureStart: window.captureStart,
      captureEnd: window.captureEnd,
      publishedAt: window.publishedAt,
      status: 'ready',
    );
    if (publication.availableAt(now)) result.add(h.withPublication(publication));
  }
  return result;
}

/// [now] **이후** 처음 오는 08:00 KST(=23:00 UTC). 화면이 켜진 채 공개 시각을
/// 넘길 때 목록을 다시 계산하는 타이머용.
DateTime nextPublishAfter(DateTime now) {
  final utc = now.toUtc();
  final today = DateTime.utc(utc.year, utc.month, utc.day, 23);
  return utc.isBefore(today) ? today : today.add(const Duration(days: 1));
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/my_cage/highlight_night_policy_test.dart`
Expected: All tests passed!

- [ ] **Step 6: 커밋**

```bash
git add lib/features/my_cage/domain/highlight_night_policy.dart lib/features/my_cage/domain/nightly_highlight.dart test/features/my_cage/highlight_night_policy_test.dart
git commit -m "feat(highlights): 밤 구간·D+2 08:00 KST 공개 정책 도메인"
```

---

### Task 2: 하이라이트 provider에 정책 적용 + 08:00 자동 갱신

**Context:**
- Depends on: Task 1
- Inputs: `applyNightPolicy`, `nextPublishAfter`. 기존 `_highlightGroupsForCameraProvider`(`my_cage_providers.dart` 595행 부근), `latestHighlightAtProvider`(546행 부근).
- Outputs: `highlightClockProvider`, 정책이 입혀진 `highlightGroupsProvider`, 공개 시각 기준 `latestHighlightAtProvider`
- Must know: ① 하이라이트 화면의 도착 배너(`highlights_screen.dart` `_groupView`)는 `publication.availableAt(now)`인 대표만 본다 — 지금까지는 서버가 publication을 안 줘서 **운영에서 배너가 한 번도 안 떴다.** 이 task 이후 합성 publication 덕에 공개된 최신 밤에 배너가 뜬다(의도된 변화 = 기획서 §3.3 "앱 안 표시"). 화면 코드는 고치지 않는다. ② provider는 autoDispose라 화면 진입마다 재조회한다 — 타이머는 "화면을 켠 채 08:00을 넘기는" 경우만 담당. ③ 테스트는 `DateTime.now()`를 못 바꾸므로 시계를 provider로 주입한다. ④ 2026-09-19에 넣은 "day_key 다음 날" 추정은 이 task에서 **제거**한다(공개 시각이 정확해졌다).
- Acceptance: `flutter test test/features/my_cage/latest_highlight_at_provider_test.dart test/features/my_cage/highlight_camera_scope_provider_test.dart test/features/my_cage/highlights_screen_test.dart test/features/my_cage/highlights_layout_test.dart` → All tests passed, `flutter analyze` 에러 0

**Files:**
- Modify: `lib/features/my_cage/presentation/my_cage_providers.dart`
- Test: `test/features/my_cage/latest_highlight_at_provider_test.dart` (교체), `test/features/my_cage/highlight_gate_provider_test.dart` (신규)

- [ ] **Step 1: 실패하는 테스트 — 게이트**

`test/features/my_cage/highlight_gate_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

class _Repo implements HighlightRepository {
  _Repo(this.items);
  final List<NightlyHighlight> items;
  @override
  Future<List<NightlyHighlight>> listFeatured(
          {required String cameraId,
          int days = HighlightRepository.defaultFeaturedDays,
          String tier = 'all'}) async =>
      items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NightlyHighlight _h(String id, String dayKey, DateTime utc) => NightlyHighlight(
    clipId: id,
    cameraId: 'cam',
    startedAt: utc.toLocal(),
    tier: 'featured',
    dayKey: dayKey,
    episodeRank: 1);

ProviderContainer _container(DateTime nowUtc) {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(User(
        id: 'u',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'a',
        createdAt: '2026-01-01T00:00:00Z')),
    selectedCrecamCameraProvider.overrideWith((ref) => 'cam'),
    hiddenClipIdsProvider.overrideWith((ref) async => <String>{}),
    highlightClockProvider.overrideWithValue(() => nowUtc),
    highlightRepositoryProvider.overrideWithValue(_Repo([
      _h('old', '2026-08-15', DateTime.utc(2026, 8, 15, 15)),
      _h('new', '2026-08-16', DateTime.utc(2026, 8, 16, 15)),
    ])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('8/18 08:00 KST 전에는 8/16 밤 묶음이 보이지 않는다', () async {
    final groups = await _container(DateTime.utc(2026, 8, 17, 22))
        .read(highlightGroupsProvider.future);
    expect(groups.map((g) => g.dayKey), ['2026-08-15']);
  });

  test('8/18 08:00 KST부터 8/16 밤 묶음이 보인다', () async {
    final groups = await _container(DateTime.utc(2026, 8, 17, 23))
        .read(highlightGroupsProvider.future);
    expect(groups.map((g) => g.dayKey), ['2026-08-16', '2026-08-15']);
  });
}
```

> `currentUserProvider`·`hiddenClipIdsProvider`의 override 형태는 기존 `test/features/my_cage/highlight_camera_scope_provider_test.dart`를 열어 **그 파일과 똑같이** 맞춘다(타입이 다르면 그쪽이 SOT).

- [ ] **Step 2: `latest_highlight_at_provider_test.dart` 기대값 교체**

첫 테스트(이름·본문)를 아래로 바꾼다. 둘째·셋째 테스트는 그대로 둔다.

```dart
  // 정책 v2(2026-09-19): 공개 시각 = 밤이 시작한 날 D의 D+2일 08:00 KST.
  // 9/13 밤 묶음은 9/15 08:00 KST(=9/14 23:00 UTC)에 올라온 것으로 본다.
  test('공개 시각이 없으면 D+2일 08:00 KST를 올라온 시각으로 제공한다', () async {
    final h = NightlyHighlight(
      clipId: 'a',
      startedAt: DateTime.utc(2026, 9, 13, 15).toLocal(),
      tier: 'featured',
      dayKey: '2026-09-13',
    );
    // 실제 provider 체인에서는 applyNightPolicy가 publication을 붙여 준다.
    final group = groupByDay(applyNightPolicy([h], DateTime.utc(2026, 9, 20)));
    final container = ProviderContainer(overrides: [
      highlightGroupsProvider.overrideWith((ref) async => group),
      highlightClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 20)),
    ]);
    addTearDown(container.dispose);
    expect(
      await container.read(latestHighlightAtProvider.future),
      DateTime.utc(2026, 9, 14, 23).toLocal(),
    );
  });
```

import에 `package:vivanaut/features/my_cage/domain/highlight_night_policy.dart` 추가. 기존 `_container` 헬퍼를 쓰는 둘째 테스트(서버 공개 시각 우선)는 `published`가 과거(2026-09-14)라 실제 시계로도 통과한다.

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/my_cage/highlight_gate_provider_test.dart test/features/my_cage/latest_highlight_at_provider_test.dart`
Expected: FAIL — `highlightClockProvider` 미정의

- [ ] **Step 4: provider 구현**

`my_cage_providers.dart` import에 추가:

```dart
import '../domain/highlight_night_policy.dart';
```

`highlightRepositoryProvider` 정의 바로 아래에 추가:

```dart
/// 하이라이트 공개 게이트가 보는 시계. 테스트가 고정 시각을 주입한다.
final highlightClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
```

`_highlightGroupsForCameraProvider` 안의 `fetch()`를 교체하고, provider 시작부에 타이머를 건다:

```dart
final _highlightGroupsForCameraProvider = FutureProvider.autoDispose
    .family<List<DayHighlightGroup>, String>((ref, cameraId) async {
  ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 격리
  final repo = ref.watch(highlightRepositoryProvider);
  final clock = ref.watch(highlightClockProvider);
  // 화면을 켠 채 08:00 KST를 넘기면 새 밤 묶음이 열려야 한다(정책 v2).
  final publishTimer = Timer(
    nextPublishAfter(clock()).difference(clock().toUtc()) +
        const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(publishTimer.cancel);
  Future<List<DayHighlightGroup>> fetch() async {
    final list = await repo.listFeatured(
      cameraId: cameraId,
      tier: 'featured',
    );
    // 밤 구간만 · D+2일 08:00 KST 이후만 · publication 합성(정책 v2).
    return groupByDay(applyNightPolicy(
      list.where((h) => h.clipId.isNotEmpty).toList(),
      clock(),
    ));
  }
  // (이하 try/catch 재시도 블록은 그대로)
```

`latestHighlightAtProvider` 본문 교체(주석 포함):

```dart
/// 마지막 하이라이트가 **공개된 시각** — 카메라 탭 하이라이트 카드의
/// "업데이트 N일 전". 정책 v2(2026-09-19): 공개 = D+2일 08:00 KST.
/// [highlightGroupsProvider]가 이미 공개된 항목만 남기고 publication(서버 값
/// 또는 앱 합성)을 붙여 주므로 그 최댓값을 읽는다. 에러는 에러로 전파.
final latestHighlightAtProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  final groups = await ref.watch(highlightGroupsProvider.future);
  DateTime? published;
  for (final group in groups) {
    for (final h in group.featured) {
      final at = h.publication?.publishedAt.toLocal();
      if (at != null && (published == null || at.isAfter(published))) {
        published = at;
      }
    }
  }
  return published;
});
```

- [ ] **Step 5: 기존 하이라이트 테스트 회귀 확인**

Run: `flutter test test/features/my_cage/ --name highlight`
그리고: `flutter test test/features/my_cage/highlights_screen_test.dart test/features/my_cage/highlights_layout_test.dart test/features/my_cage/highlight_camera_scope_provider_test.dart`

Expected: PASS. 픽스처가 `highlightGroupsProvider`를 직접 override하는 테스트는 영향 없음. `highlightRepositoryProvider`를 override해 **과거가 아닌 day_key**나 **낮 시각** 항목을 쓰는 테스트가 실패하면, 그 테스트에 `highlightClockProvider.overrideWithValue(() => DateTime.utc(2030))`을 넣고 항목 시각을 밤 구간(UTC 11:00~23:00)으로 옮긴다 — 기대값(묶음 수·순서)은 바꾸지 않는다.

- [ ] **Step 6: analyze + 커밋**

```bash
flutter analyze
git add lib/features/my_cage/presentation/my_cage_providers.dart test/features/my_cage/
git commit -m "feat(highlights): D+2 08:00 KST 공개 게이트·밤 구간 필터 적용"
```

---

### Task 3: `HighlightRepository.listPassedPage`

**Context:**
- Depends on: 없음
- Inputs: petcam-api `GET /highlights?camera_id&since&until&limit&cursor` → `{highlights:[{clip_id, camera_id, started_at, duration_sec, ...}], has_more, next_cursor, camera_id}`. `next_cursor`는 **불투명 문자열** — 앱이 해석·조립하지 않는다.
- Outputs: `PassedClipRefPage`, `HighlightRepository.listPassedPage()`
- Must know: `until`은 서버 미배포(요청서 ②). FastAPI는 모르는 쿼리를 무시하므로 보내도 안전하고, 상한 재필터는 Task 5가 한다. `limit`은 서버 상한 100(`maxLimit`)으로 클램프. 404(활성 규칙 없음)는 빈 페이지.
- Acceptance: `flutter test test/features/my_cage/highlight_repository_test.dart` → All tests passed

**Files:**
- Modify: `lib/features/my_cage/data/highlight_repository.dart`
- Test: `test/features/my_cage/highlight_repository_test.dart` (추가)

- [ ] **Step 1: 실패하는 테스트 추가** (`main()` 끝에)

```dart
  group('listPassedPage — 전체 영상 목록(규칙 O 전부)', () {
    test('since·until·cursor·limit을 보내고 커서를 그대로 돌려준다', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'camera_id': cameraId,
            'highlights': [
              {
                'clip_id': 'c1',
                'camera_id': cameraId,
                'started_at': '2026-09-07T15:00:00Z',
                'duration_sec': 12.5,
              },
            ],
            'has_more': true,
            'next_cursor': 'opaque-token',
          }),
          200,
        );
      });
      final page = await repo(client).listPassedPage(
        cameraId: cameraId,
        since: DateTime.utc(2026, 9, 7),
        until: DateTime.utc(2026, 9, 8),
        cursor: 'prev-token',
        limit: 500,
      );
      expect(captured!.url.path, '/highlights');
      expect(captured!.url.queryParameters, {
        'camera_id': cameraId,
        'limit': '100',
        'since': '2026-09-07T00:00:00.000Z',
        'until': '2026-09-08T00:00:00.000Z',
        'cursor': 'prev-token',
      });
      expect(page.clipIds, ['c1']);
      expect(page.oldestStartedAt, DateTime.utc(2026, 9, 7, 15));
      expect(page.nextCursor, 'opaque-token');
      expect(page.hasMore, isTrue);
    });

    test('범위·커서가 없으면 그 쿼리를 보내지 않는다', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
            jsonEncode({'camera_id': cameraId, 'highlights': []}), 200);
      });
      final page = await repo(client).listPassedPage(cameraId: cameraId);
      expect(captured!.url.queryParameters,
          {'camera_id': cameraId, 'limit': '60'});
      expect(page.clipIds, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('다른 카메라의 응답은 통째로 버린다', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'camera_id': 'other',
            'highlights': [
              {'clip_id': 'x', 'camera_id': 'other', 'started_at': '2026-09-07T15:00:00Z'}
            ],
            'has_more': true,
            'next_cursor': 't',
          }),
          200));
      final page = await repo(client).listPassedPage(cameraId: cameraId);
      expect(page.clipIds, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('404는 빈 페이지, 504는 BackendException', () async {
      expect(
          (await repo(MockClient((_) async => http.Response('', 404)))
                  .listPassedPage(cameraId: cameraId))
              .clipIds,
          isEmpty);
      expect(
          repo(MockClient((_) async => http.Response('timeout', 504)))
              .listPassedPage(cameraId: cameraId),
          throwsA(isA<BackendException>()
              .having((e) => e.statusCode, 'statusCode', 504)));
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/highlight_repository_test.dart`
Expected: FAIL — `listPassedPage` 미정의

- [ ] **Step 3: 구현**

`highlight_repository.dart` 파일 상단(import 아래, class 위)에 추가:

```dart
/// `/highlights` 한 페이지의 통과 클립 참조 — 전체 영상 목록용(정책 v2).
/// [nextCursor]는 서버 불투명 커서라 앱이 해석·조립하지 않는다.
/// [oldestStartedAt]은 이 페이지에서 가장 오래된 항목 시각(UTC) — 앱측
/// 범위 재필터가 "더 넘길 필요가 있는지" 판단하는 데 쓴다.
typedef PassedClipRefPage = ({
  List<String> clipIds,
  List<DateTime> startedAts,
  DateTime? oldestStartedAt,
  String? nextCursor,
  bool hasMore,
});
```

`HighlightRepository` 안, `list()` 아래에 추가:

```dart
  /// 전체 영상 목록 기본 페이지 크기(기존 motion_clips 피드와 동일).
  static const defaultPassedPageSize = 60;

  /// 규칙 O + 사람 확정 O **전부**를 최신순 cursor 페이지로 — 카메라 탭 전체
  /// 영상 목록(정책 v2, 2026-09-19). [since] 포함 하한, [until] 미포함 상한
  /// (서버 미배포 동안은 무시된다 — 호출부가 상한을 한 번 더 거른다).
  Future<PassedClipRefPage> listPassedPage({
    required String cameraId,
    DateTime? since,
    DateTime? until,
    String? cursor,
    int limit = defaultPassedPageSize,
  }) async {
    limit = limit.clamp(1, maxLimit);
    final token = await _tokenProvider();
    final uri = Uri.parse('$_baseUrl/highlights').replace(
      queryParameters: {
        'camera_id': cameraId,
        'limit': '$limit',
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (until != null) 'until': until.toUtc().toIso8601String(),
        if (cursor != null) 'cursor': cursor,
      },
    );
    final resp = await _client.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    const empty = (
      clipIds: <String>[],
      startedAts: <DateTime>[],
      oldestStartedAt: null,
      nextCursor: null,
      hasMore: false,
    );
    if (resp.statusCode == 404) return empty;
    if (resp.statusCode != 200) {
      throw BackendException(resp.statusCode, resp.body);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final responseCameraId = body['camera_id'];
    if (responseCameraId != null && responseCameraId != cameraId) {
      debugPrint('[passed-clips] discarded mismatched response: '
          'requested=$cameraId, response=$responseCameraId');
      return empty;
    }
    final ids = <String>[];
    final times = <DateTime>[];
    for (final raw in body['highlights'] as List? ?? const []) {
      final item = raw as Map<String, dynamic>;
      final id = item['clip_id'] as String? ?? '';
      final at = DateTime.tryParse('${item['started_at']}')?.toUtc();
      if (id.isEmpty || at == null) continue;
      if (responseCameraId == null && item['camera_id'] != cameraId) continue;
      ids.add(id);
      times.add(at);
    }
    return (
      clipIds: ids,
      startedAts: times,
      oldestStartedAt: times.isEmpty
          ? null
          : times.reduce((a, b) => a.isBefore(b) ? a : b),
      nextCursor: body['next_cursor'] as String?,
      hasMore: body['has_more'] == true,
    );
  }
```

- [ ] **Step 4: 통과 확인 + 커밋**

Run: `flutter test test/features/my_cage/highlight_repository_test.dart` → All tests passed!

```bash
git add lib/features/my_cage/data/highlight_repository.dart test/features/my_cage/highlight_repository_test.dart
git commit -m "feat(clips): /highlights cursor 페이지 조회(listPassedPage)"
```

---

### Task 4: 커서에 서버 토큰 + `MotionClipRepository.getByIds`

**Context:**
- Depends on: 없음
- Inputs: `MotionClipCursor = ({DateTime startedAt, String id})`(`motion_clip_page.dart`). 생성 지점: `motion_clip_repository.dart:110`, 테스트 `motion_clip_paging_test.dart`·`clip_visibility_test.dart`·`clip_playlist_player_screen_test.dart`·`test/design/redesign_camera_pet_capture_test.dart`.
- Outputs: `MotionClipCursor`에 `String? token` 필드, `MotionClipRepository.getByIds(List<String>)`
- Must know: Dart record는 named 필드를 **전부** 써야 생성된다 — 필드를 추가하면 모든 생성 지점에 `token: null`을 넣어야 컴파일된다(`flutter analyze`가 전부 짚어 준다). `loadVisibleClipPage`는 커서를 `Set`에 넣어 "커서가 안 움직임"을 감지하므로 record 동등성(필드 전체 비교)이 그대로 유효해야 한다. `getByIds`는 입력 순서를 보장하지 않으므로 호출부가 정렬한다. Supabase `inFilter`는 URL 길이 제한이 있으니 100개 이하로만 부른다(페이지 상한 100과 일치).
- Acceptance: `flutter analyze` 에러 0, `flutter test test/features/my_cage/motion_clip_paging_test.dart test/features/my_cage/clip_visibility_test.dart test/features/my_cage/clip_playlist_player_screen_test.dart` → PASS

**Files:**
- Modify: `lib/features/my_cage/domain/motion_clip_page.dart`
- Modify: `lib/features/my_cage/data/motion_clip_repository.dart`
- Modify: 위 테스트 4개(커서 생성 지점에 `token: null`)

- [ ] **Step 1: typedef 변경**

```dart
/// [token]은 petcam-api `/highlights`의 불투명 서버 커서(정책 v2 전체 영상
/// 목록). Supabase 직결 페이징(`MotionClipRepository.listPage`)은 null.
typedef MotionClipCursor = ({DateTime startedAt, String id, String? token});
```

- [ ] **Step 2: 컴파일 에러 지점 전부 수정**

Run: `flutter analyze 2>&1 | grep -i "token\|MotionClipCursor\|named"`
각 지점의 `(startedAt: X, id: Y)`를 `(startedAt: X, id: Y, token: null)`로 바꾼다. `motion_clip_repository.dart`:

```dart
      nextCursor: hasMore && items.isNotEmpty
          ? (startedAt: items.last.startedAt, id: items.last.id, token: null)
          : null,
```

- [ ] **Step 3: `getByIds` 추가** (`getById` 아래)

```dart
  /// id 목록으로 모션 클립을 채운다 — 전체 영상 목록(정책 v2)이 petcam-api가
  /// 준 통과 clip_id를 화면용 [MotionClip]으로 바꿀 때 쓴다. RLS 본인 것만,
  /// 원본이 지워진 id는 조용히 빠진다. **반환 순서는 보장하지 않는다.**
  Future<List<MotionClip>> getByIds(List<String> clipIds) async {
    if (clipIds.isEmpty) return const [];
    final rows =
        await _supabase.from('motion_clips').select().inFilter('id', clipIds);
    final clips = (rows as List)
        .map((r) => MotionClip.fromJson(r as Map<String, dynamic>))
        .toList();
    if (!kClipClassificationEnabled || clips.isEmpty) return clips;
    final labels = await _fetchLabels(clips.map((c) => c.id).toList());
    return [
      for (final c in clips)
        labels.containsKey(c.id) ? c.copyWith(action: labels[c.id]) : c,
    ];
  }
```

- [ ] **Step 4: 확인 + 커밋**

Run: `flutter analyze` → No issues (기존 info 제외) · `flutter test test/features/my_cage/ test/design/redesign_camera_pet_capture_test.dart` → PASS

```bash
git add lib/features/my_cage/domain/motion_clip_page.dart lib/features/my_cage/data/motion_clip_repository.dart test/
git commit -m "refactor(clips): 페이지 커서에 서버 토큰 필드·getByIds 추가"
```

---

### Task 5: `PassedClipFeedSource` — 통과 영상 페이지 로더

**Context:**
- Depends on: Task 3, Task 4
- Inputs: `HighlightRepository.listPassedPage`, `MotionClipRepository.getByIds`, `ClipFeedQuery = ({ownerId, cameraId, ClipDateRange? range})`, `ClipDateRange = ({start, endExclusive})`
- Outputs: `PassedClipFeedSource.loadPage(ClipFeedQuery, {MotionClipCursor? before})` → `MotionClipPage`
- Must know: ① 서버 `until` 미배포 동안 과거 범위를 보면 첫 페이지들이 전부 범위 **이후** 영상일 수 있다 → 범위 안 항목이 나오거나 끝날 때까지 **내부에서 계속 넘긴다**(빈 페이지를 돌려주면 `ClipFeedController`가 "끝"으로 오해하진 않지만 스크롤 트리거가 없어 멈춘다). 무한 루프 방지로 최대 20페이지. ② 504(조회 시 계산 시간 초과)는 1초 쉬고 1회 재시도 — 그 외 에러는 그대로 던진다(화면이 retry 표시). ③ 결과는 `startedAt` 내림차순·동시각은 id 내림차순(기존 피드 정렬과 동일). ④ 테스트를 위해 두 저장소 호출을 함수로 주입받는다.
- Acceptance: `flutter test test/features/my_cage/passed_clip_feed_source_test.dart` → All tests passed

**Files:**
- Create: `lib/features/my_cage/data/passed_clip_feed_source.dart`
- Test: `test/features/my_cage/passed_clip_feed_source_test.dart`

- [ ] **Step 1: 실패하는 테스트**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/camera_exceptions.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/data/passed_clip_feed_source.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';

PassedClipRefPage _refs(Map<String, DateTime> items,
        {String? next, bool more = false}) =>
    (
      clipIds: items.keys.toList(),
      startedAts: items.values.toList(),
      oldestStartedAt: items.isEmpty
          ? null
          : items.values.reduce((a, b) => a.isBefore(b) ? a : b),
      nextCursor: next,
      hasMore: more,
    );

MotionClip _clip(String id, DateTime at) =>
    MotionClip(id: id, cameraId: 'cam', startedAt: at, durationSec: 10);

const ClipFeedQuery _all = (ownerId: 'u', cameraId: 'cam', range: null);

void main() {
  test('통과 id를 모션 클립으로 채워 최신순으로 돌려주고 서버 커서를 싣는다', () async {
    final t1 = DateTime.utc(2026, 9, 7, 15), t2 = DateTime.utc(2026, 9, 7, 16);
    String? askedCursor = 'unset';
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        askedCursor = cursor;
        return _refs({'a': t1, 'b': t2}, next: 'tok', more: true);
      },
      hydrate: (ids) async => [_clip('a', t1), _clip('b', t2)],
    );
    final page = await source.loadPage(_all);
    expect(askedCursor, isNull);
    expect(page.items.map((c) => c.id), ['b', 'a']);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, (startedAt: t1, id: 'a', token: 'tok'));
  });

  test('다음 페이지는 이전 커서의 token으로 요청한다', () async {
    String? askedCursor;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        askedCursor = cursor;
        return _refs({});
      },
      hydrate: (ids) async => const [],
    );
    await source.loadPage(_all,
        before: (startedAt: DateTime.utc(2026), id: 'x', token: 'tok'));
    expect(askedCursor, 'tok');
  });

  test('원본이 지워진 id는 빠진다', () async {
    final t = DateTime.utc(2026, 9, 7, 15);
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'gone': t, 'kept': t}),
      hydrate: (ids) async => [_clip('kept', t)],
    );
    expect((await source.loadPage(_all)).items.map((c) => c.id), ['kept']);
  });

  test('범위 상한을 앱에서도 거르고, 범위 안이 나올 때까지 넘긴다', () async {
    final range = (
      start: DateTime.utc(2026, 9, 5),
      endExclusive: DateTime.utc(2026, 9, 6),
    );
    final after = DateTime.utc(2026, 9, 7), inside = DateTime.utc(2026, 9, 5, 12);
    var calls = 0;
    DateTime? since, until;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since: s, until: u, cursor}) async {
        calls++;
        since = s;
        until = u;
        return cursor == null
            ? _refs({'late': after}, next: 'p2', more: true)
            : _refs({'in': inside});
      },
      hydrate: (ids) async => [
        for (final id in ids) _clip(id, id == 'in' ? inside : after),
      ],
    );
    final page = await source
        .loadPage((ownerId: 'u', cameraId: 'cam', range: range));
    expect(calls, 2);
    expect(since, range.start);
    expect(until, range.endExclusive);
    expect(page.items.map((c) => c.id), ['in']);
    expect(page.hasMore, isFalse);
  });

  test('504는 한 번 재시도하고, 다른 에러는 바로 던진다', () async {
    var calls = 0;
    final retry = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        if (++calls == 1) throw const BackendException(504, 'timeout');
        return _refs({});
      },
      hydrate: (ids) async => const [],
      retryDelay: Duration.zero,
    );
    await retry.loadPage(_all);
    expect(calls, 2);

    final fail = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          throw const BackendException(502, 'db'),
      hydrate: (ids) async => const [],
      retryDelay: Duration.zero,
    );
    expect(fail.loadPage(_all), throwsA(isA<BackendException>()));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/passed_clip_feed_source_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현**

`lib/features/my_cage/data/passed_clip_feed_source.dart`:

```dart
import '../domain/motion_clip.dart';
import '../domain/motion_clip_page.dart';
import 'camera_exceptions.dart';
import 'highlight_repository.dart';

typedef PassedRefLoader = Future<PassedClipRefPage> Function({
  required String cameraId,
  DateTime? since,
  DateTime? until,
  String? cursor,
});
typedef ClipHydrator = Future<List<MotionClip>> Function(List<String> clipIds);

/// 카메라 탭 **전체 영상 목록**의 데이터 소스(정책 v2, 2026-09-19) — 거르지
/// 않은 `motion_clips` 대신 "하이라이트 규칙 O + 사람 확정 O 전부"만 보여준다.
///
/// petcam-api `/highlights`가 통과 clip_id를 cursor 페이지로 주고, 화면용
/// 메타(썸네일 키·행동 라벨)는 Supabase `motion_clips`에서 채운다. 반환형이
/// 기존 [MotionClipPage]라 피드 컨트롤러·플레이어·숨김 처리는 그대로다.
class PassedClipFeedSource {
  PassedClipFeedSource({
    required PassedRefLoader listRefs,
    required ClipHydrator hydrate,
    this.retryDelay = const Duration(seconds: 1),
  })  : _listRefs = listRefs,
        _hydrate = hydrate;

  final PassedRefLoader _listRefs;
  final ClipHydrator _hydrate;
  final Duration retryDelay;

  /// 서버 `until` 미배포 동안 과거 범위를 찾으러 넘기는 페이지 상한.
  static const _maxSkipPages = 20;

  Future<MotionClipPage> loadPage(ClipFeedQuery query,
      {MotionClipCursor? before}) async {
    final range = query.range;
    var cursor = before?.token;
    for (var i = 0; i < _maxSkipPages; i++) {
      final refs = await _refsWithRetry(query.cameraId, range, cursor);
      // 서버가 until을 아직 모르면 상한 이후 영상이 섞여 온다 — 한 번 더 거른다.
      final wanted = <String>[
        for (var k = 0; k < refs.clipIds.length; k++)
          if (range == null ||
              refs.startedAts[k].isBefore(range.endExclusive.toUtc()))
            refs.clipIds[k],
      ];
      final clips = (await _hydrate(wanted)).toList()
        ..sort((a, b) {
          final date = b.startedAt.compareTo(a.startedAt);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });
      final hasMore = refs.hasMore && refs.nextCursor != null;
      if (clips.isNotEmpty || !hasMore) {
        return (
          items: List<MotionClip>.unmodifiable(clips),
          nextCursor: hasMore
              ? (
                  startedAt: clips.isNotEmpty
                      ? clips.last.startedAt
                      : (refs.oldestStartedAt ?? DateTime.utc(1970)),
                  id: clips.isNotEmpty ? clips.last.id : '',
                  token: refs.nextCursor,
                )
              : null,
          hasMore: hasMore,
        );
      }
      cursor = refs.nextCursor;
    }
    throw StateError('Passed clip range scan exceeded $_maxSkipPages pages');
  }

  /// `/highlights`는 조회 시 계산이라 간헐 504가 난다 — 1회만 재시도한다.
  Future<PassedClipRefPage> _refsWithRetry(
      String cameraId, ClipDateRange? range, String? cursor) async {
    Future<PassedClipRefPage> call() => _listRefs(
          cameraId: cameraId,
          since: range?.start,
          until: range?.endExclusive,
          cursor: cursor,
        );
    try {
      return await call();
    } on BackendException catch (e) {
      if (e.statusCode != 504) rethrow;
      await Future<void>.delayed(retryDelay);
      return call();
    }
  }
}
```

- [ ] **Step 4: 통과 확인 + 커밋**

Run: `flutter test test/features/my_cage/passed_clip_feed_source_test.dart` → All tests passed!

```bash
git add lib/features/my_cage/data/passed_clip_feed_source.dart test/features/my_cage/passed_clip_feed_source_test.dart
git commit -m "feat(clips): 통과 영상 페이지 로더(PassedClipFeedSource)"
```

---

### Task 6: 카메라 탭 피드·플레이어를 새 소스로 교체 (단독 커밋)

**Context:**
- Depends on: Task 5
- Inputs: `clip_feed_controller.dart`의 `clipFeedProvider`(47행 `load: (before) => repository.listPage(query, before: before)`), `player_view_providers.dart`의 `playerFeedPageLoaderProvider`(24행 같은 호출)
- Outputs: `passedClipFeedSourceProvider`; 두 로더가 `source.loadPage`를 호출
- Must know: **화면 동작이 바뀌는 지점이라 이 task만 단독 커밋**한다(되돌리기 쉽게). 두 곳을 **반드시 같이** 바꾼다 — 그리드는 통과분만인데 플레이어 필름스트립이 전체를 넘기면 "목록에 없던 영상"이 재생된다. `motionClipRepositoryProvider`를 쓰는 다른 곳(활동시간·북마크 메타·포스터)은 건드리지 않는다. 기존 위젯 테스트는 `clipFeedProvider` 자체를 override하므로 영향 없음.
- Acceptance: `flutter analyze` 에러 0 · `flutter test test/features/my_cage/` 전체 PASS

**Files:**
- Modify: `lib/features/my_cage/presentation/my_cage_providers.dart`
- Modify: `lib/features/my_cage/presentation/clip_feed_controller.dart:37-48`
- Modify: `lib/features/my_cage/presentation/player_view_providers.dart:15-26`
- Test: `test/features/my_cage/passed_clip_feed_wiring_test.dart`

- [ ] **Step 1: 실패하는 배선 테스트**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/passed_clip_feed_source.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';

void main() {
  // 그리드와 플레이어 필름스트립이 같은 "통과 영상" 소스를 봐야 한다 —
  // 어긋나면 목록에 없던 영상이 플레이어에서 재생된다(정책 v2).
  test('플레이어 필름스트립 로더는 통과 영상 소스를 쓴다', () async {
    final at = DateTime.utc(2026, 9, 7, 15);
    const ClipFeedQuery query = (ownerId: 'u', cameraId: 'cam', range: null);
    final container = ProviderContainer(overrides: [
      passedClipFeedSourceProvider.overrideWithValue(PassedClipFeedSource(
        listRefs: ({required cameraId, since, until, cursor}) async => (
          clipIds: ['p'],
          startedAts: [at],
          oldestStartedAt: at,
          nextCursor: null,
          hasMore: false,
        ),
        hydrate: (ids) async => [
          MotionClip(id: 'p', cameraId: 'cam', startedAt: at, durationSec: 5)
        ],
      )),
      clipVisibilityProvider('u').overrideWith(
          (ref) => throw UnimplementedError('아래 주석 참고')),
    ]);
    addTearDown(container.dispose);
    final page = await container.read(playerFeedPageLoaderProvider(query))(null);
    expect(page.items.single.id, 'p');
  });
}
```

> `clipVisibilityProvider` override는 기존 `test/features/my_cage/clip_visibility_feed_test.dart`의 방식(`clipVisibilityRepositoryProvider.overrideWithValue(가짜 저장소)` + `currentUserProvider`)을 **그대로 복사**해 맞춘다 — 위 `UnimplementedError` 줄은 그 블록으로 교체한다. 그 파일이 이 영역 override의 SOT다.

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/passed_clip_feed_wiring_test.dart`
Expected: FAIL — `passedClipFeedSourceProvider` 미정의

- [ ] **Step 3: provider 추가** (`my_cage_providers.dart`, `highlightClockProvider` 아래)

```dart
/// 카메라 탭 전체 영상 목록의 소스 — 하이라이트 규칙 O 전부(정책 v2).
/// 그리드([clipFeedProvider])와 플레이어 필름스트립
/// ([playerFeedPageLoaderProvider])이 **같이** 이걸 쓴다.
final passedClipFeedSourceProvider = Provider<PassedClipFeedSource>((ref) {
  final highlights = ref.watch(highlightRepositoryProvider);
  final clips = ref.watch(motionClipRepositoryProvider);
  return PassedClipFeedSource(
    listRefs: ({required cameraId, since, until, cursor}) =>
        highlights.listPassedPage(
            cameraId: cameraId, since: since, until: until, cursor: cursor),
    hydrate: clips.getByIds,
  );
});
```

import 추가: `import '../data/passed_clip_feed_source.dart';`

- [ ] **Step 4: 두 로더 교체**

`clip_feed_controller.dart` — `final repository = ref.watch(motionClipRepositoryProvider);`를 아래로 바꾸고 load 줄을 교체:

```dart
  final source = ref.watch(passedClipFeedSourceProvider);
  // ...
      load: (before) => source.loadPage(query, before: before),
```

`player_view_providers.dart` — 같은 방식:

```dart
  final source = ref.watch(passedClipFeedSourceProvider);
  // ...
        load: (cursor) => source.loadPage(query, before: cursor));
```

- [ ] **Step 5: 전체 확인 + 단독 커밋**

Run: `flutter analyze` → 에러 0 · `flutter test test/features/my_cage/` → PASS

```bash
git add lib/features/my_cage/presentation/ test/features/my_cage/passed_clip_feed_wiring_test.dart
git commit -m "feat(crecam): 전체 영상 목록을 하이라이트 규칙 통과분으로 교체"
```

---

### Task 7: 빈 목록 문구

**Context:**
- Depends on: Task 6
- Inputs: `assets/l10n/ko.json`의 `crecam_home_empty_all`("아직 촬영된 영상이 없어요")·`crecam_home_empty_day`("이 날짜에는 영상이 없어요"). 소비처 `widgets/clip_feed_slivers.dart:40-41`.
- Outputs: 문구 교체(키는 그대로)
- Must know: 이제 "영상이 없다"가 아니라 "기준을 넘은 영상이 없다"다. 촬영은 됐는데 안 보이는 걸 고장으로 읽지 않게 이유를 밝힌다(프로젝트 규칙 "화면에서 이유를 밝힌다"). 전역 글자 1.15배라 한 줄이 길면 줄바꿈된다 — 두 줄 이내.
- Acceptance: `grep -n "crecam_home_empty" assets/l10n/ko.json`에 새 문구, `flutter test test/features/my_cage/crecam_home_test.dart` PASS(문구를 직접 비교하는 테스트가 있으면 새 문구로 맞춘다)

- [ ] **Step 1: 문구 교체**

```json
  "crecam_home_empty_all": "아직 움직임이 뚜렷한 영상이 없어요",
  "crecam_home_empty_day": "이 기간에는 움직임이 뚜렷한 영상이 없어요",
```

- [ ] **Step 2: 확인 + 커밋**

```bash
flutter test test/features/my_cage/crecam_home_test.dart
git add assets/l10n/ko.json test/
git commit -m "fix(crecam): 빈 목록 문구를 통과 기준에 맞게 수정"
```

---

### Task 8: 가드·문서·버전 + 시뮬레이터 확인

**Context:**
- Depends on: Task 1~7
- Must know: `lib/` 변경이라 버전 필수(feat → minor): `0.114.5+291` → **`0.115.0+292`**. CHANGELOG는 한글·결과 중심. 가드 테스트는 "지워서 우회 금지" — 새 표지를 **추가**한다. pre-push 훅이 무버전업 push를 막는다.
- Acceptance: `flutter analyze` 에러 0 · `flutter test` 전체 PASS · iOS/Android 시뮬에서 아래 3가지 실측

- [ ] **Step 1: 회귀 가드 추가** (`test/regression/redesign_baseline_guard_test.dart`, 기존 패턴대로 파일 내용 검사)

```dart
  test('하이라이트 정책 v2 — 전체 목록은 통과분, 하이라이트는 공개 게이트', () {
    final feed = File('lib/features/my_cage/presentation/clip_feed_controller.dart')
        .readAsStringSync();
    final player =
        File('lib/features/my_cage/presentation/player_view_providers.dart')
            .readAsStringSync();
    final providers =
        File('lib/features/my_cage/presentation/my_cage_providers.dart')
            .readAsStringSync();
    expect(feed, contains('passedClipFeedSourceProvider'));
    expect(player, contains('passedClipFeedSourceProvider'));
    expect(providers, contains('applyNightPolicy('));
  });
```

- [ ] **Step 2: `pubspec.yaml` 버전** → `version: 0.115.0+292`

- [ ] **Step 3: `CHANGELOG.md` 최상단**

```markdown
## 0.115.0+292 — 2026-09-19

### 변경
- 카메라 탭 전체 영상 목록이 **움직임이 뚜렷한 영상(하이라이트 기준 통과분)만** 보여줍니다. 빈 화면·미세한 움직임 영상은 목록과 플레이어 넘김에서 빠집니다. 북마크한 영상과 활동시간 집계는 그대로입니다.
- 하이라이트는 **밤(20:00~다음 날 08:00) 촬영분만**, **촬영 다음다음 날 아침 8시**에 공개됩니다(예: 8/16 밤 → 8/18 08:00). 공개된 최신 밤에는 도착 배너가 뜨고, 하이라이트 카드 "업데이트 N일 전"은 공개 시각 기준입니다.
- 영상이 없을 때 안내 문구를 "움직임이 뚜렷한 영상이 없어요"로 바꿨습니다.
```

- [ ] **Step 4: `CLAUDE.md` 갱신** — "Final Design 사용자 변경 결정 (2026-09-14)" 절의 하이라이트 항목(`공개 하이라이트 배치의 실제 재생 진전으로…`) 끝에 이어 붙인다:

```markdown
 → **정책 v2(2026-09-19 사용자 확정, 위 추정·"도착을 만들지 않는다"를 대체):** ① 카메라 탭 전체 영상 목록 = **하이라이트 규칙 O 전부**(petcam-api `/highlights` cursor 페이지 → `PassedClipFeedSource`, 그리드·플레이어 필름스트립 공용 `passedClipFeedSourceProvider`). 미통과 영상은 완전히 숨김(북마크·커뮤니티·활동시간 집계는 무관). ② 하이라이트 = **밤 D 20:00~D+1 08:00 KST만, D+2일 08:00 KST 공개** — 앱이 시간으로 게이트하고 publication을 합성한다(`highlight_night_policy.dart` `applyNightPolicy`, KST=UTC+9 고정 계산). 검수 지연은 기다리지 않는다. ③ 시스템 푸시 `highlight.ready`는 petcam-lab 08:00 작업(0건이면 미발송) — 미배포 동안 앱 안 도착 배너만. SOT `docs/superpowers/specs/2026-09-19-highlight-policy-v2-design.md`. **미결: 어젯밤 리포트의 하이라이트 영역은 현행 유지(기획서 §6).**
```

- [ ] **Step 5: 전체 검증**

Run: `flutter analyze` → 에러 0 · `flutter test` → All tests passed!

- [ ] **Step 6: 시뮬레이터 실측** (iOS `xcrun simctl io booted screenshot <절대경로>`, Android `ANDROID_SERIAL=emulator-5554`)

1. 카메라 탭 그리드 개수가 운영 DB의 그 카메라 규칙 O 개수와 같은가(라벨링 웹 `하이라이트 O` 필터와 대조). 미통과 영상이 안 보이는가.
2. 그리드에서 영상 재생 → 좌/우 넘김이 그리드에 있는 영상만 도는가.
3. 하이라이트 화면: 어젯밤·오늘 밤 묶음이 없고 그저께 밤 이전만 보이는가. 최신 공개 밤에 도착 배너, 카드 "업데이트 오늘/N일 전"이 `D+2 08:00` 기준인가.

- [ ] **Step 7: 커밋 + push**

```bash
git add pubspec.yaml CHANGELOG.md CLAUDE.md test/regression/redesign_baseline_guard_test.dart
git commit -m "chore(release): 하이라이트 정책 v2 — 문서·가드·버전 (0.115.0+292)"
git push
```

- [ ] **Step 8: 사용자에게 `/code-review` 실행 요청** (Claude는 대신 실행 못 함)

---

### Task 9 (2단계 · 별도 승인): 알림 문구 정정

**Context:**
- Depends on: petcam-lab 요청 ① 배포 일정 확정
- Must know: `supabase/migrations/20260915000000_fcm_notifications.sql`의 `highlight.ready` 본문이 **"어젯밤 활동 하이라이트"**다 — D+2 공개에서는 그저께 밤이라 사실과 다르다. **운영 DB 함수 변경이므로 사용자 승인 후** 새 마이그레이션으로 적용한다(기존 마이그레이션 파일은 고치지 않는다). `_shared/notification-migration.test.mjs`가 문구를 검사하면 같이 고친다.
- Acceptance: 새 마이그레이션 파일 + Node 테스트 PASS + 사용자 승인 뒤 적용 기록

- [ ] **Step 1:** `supabase/migrations/20260920000000_notification_highlight_copy.sql` — 기존 트리거 함수 정의를 그대로 복사해 `highlight.ready` 두 줄만 교체:

```sql
      v_title := '새 하이라이트가 도착했어요';
      v_body := '엄선한 밤 활동 영상을 확인해 보세요.';
```

- [ ] **Step 2:** `cd supabase/functions && node --test _shared/` → PASS
- [ ] **Step 3:** 사용자 승인 → 적용 → `docs/handoffs/2026-09-15-fcm-deployment-checklist.md`에 적용 기록

---

## Self-Review 결과

- **Spec coverage:** §3.1 목록 대상·즉시 공개·미통과 숨김 → T3·5·6 / 예외(북마크·활동시간) → "건드리지 않는 것" / 빈 목록 → T7. §3.2 밤 구간·D+2 08:00·검수 미대기·앱 게이트·KST·서버 publication 우선 → T1·2 / 도착 표시·카드 → T2(화면 무수정, 합성 publication으로 기존 로직 활성). §3.3 배포 전 앱 안 표시 → T2 / 배포 후 → 앱 변경 없음 + T9. §5 `until` 선전송 → T3·5. §6 미결 → 범위 밖 명시.
- **Placeholder scan:** 코드 단계는 전부 실제 코드. 단 T2·T6 테스트의 **provider override 블록 2곳**은 기존 테스트 파일을 SOT로 복사하도록 지시했다(override 타입을 이 계획서에서 추측해 적으면 틀릴 수 있어서 — 해당 파일 경로를 명시).
- **Type consistency:** `MotionClipCursor.token`(T4) ↔ T5 `before?.token`·`nextCursor.token` / `PassedClipRefPage` 필드(T3) ↔ T5·T6 테스트 / `highlightClockProvider: Provider<DateTime Function()>`(T2) ↔ 테스트 `overrideWithValue(() => ...)` / `applyNightPolicy(List, DateTime)`(T1) ↔ T2 호출.
