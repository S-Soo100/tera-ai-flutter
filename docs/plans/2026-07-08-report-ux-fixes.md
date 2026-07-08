# 리포트/재생 UX 최종 수정 기획서 (실기기 피드백 반영)

> **구현 방식 (CAOF):** Critical(리포트 전면 개편 포함). flutter-dev가 task별 구현. Steps use checkbox.
> 작성일: 2026-07-08 · 근거: 실기기 테스트 피드백 + 사용자 방향 확정(대화).

**Goal:** 실기기 피드백 5건 반영 — ①재생 버튼 가시성 ②재생바 탭 시크 ③어젯밤 범위 22~06시 ④GT 라벨 전면 제거 ⑤리포트를 "마이 크레" 탭에 통합한 **어젯밤 요약**(활동시간+행동횟수)+하이라이트로 개편.

**핵심 결정(대화 확정):**
- **GT 라벨(맞아요/정정/오탐) 앱에서 완전 제거** — 라벨링은 관리자 라벨러 웹 몫. 하이라이트는 **보기+재생 전용**.
- **리포트/하이라이트모음 → 하나로 통합**: 마이 크레 탭 = `[개체 목록 | 리포트]`(하이라이트 모음 탭 제거). 리포트 탭 = **어젯밤 요약 카드 + 하이라이트 카드**.
- **홈 배지 → 마이 크레 리포트 탭으로 이동**(별도 `/home/highlights` 폐기). 배지는 밤 활동 있으면 항상 노출(하이라이트 0이면 "조용한 밤" 문구).
- **범위 22~06시**. 행동 카운트 = 물(drinking) · 밥(hand_feeding+eating_paste+eating_prey) · **탈피(shedding, count>0일 때만 — 백엔드 억제로 현재 0)**. 카운트는 AI 샘플 감지분("AI가 포착한").
- 스코프 = 내 전체 카메라 합산.

**Tech Stack:** Flutter · Riverpod · video_player · go_router · easy_localization (신규 패키지 없음)

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `presentation/widgets/video_controls.dart` | Modify | 진행바 → Slider 시크(탭 점프) |
| `presentation/motion_clip_player_screen.dart` | Modify | 앱바 버튼 흰색+반투명 원형 |
| `presentation/highlights_controller.dart` | Modify | `lastNightSince`=22시 + `lastNightEnd` + GT 컨트롤러 제거 |
| `test/features/my_cage/last_night_since_test.dart` | Modify | 22시로 |
| `domain/nightly_highlight.dart` | Modify | GT 필드(review/correctedAction/user_confirmed) 제거 |
| `test/features/my_cage/nightly_highlight_test.dart` | Modify | GT 케이스 제거 |
| `data/highlight_repository.dart` | Modify | `submitLabel` 제거 |
| `domain/nightly_report.dart` | Create | 요약(활동초+하이라이트+카운트 getter) |
| `presentation/nightly_report_view.dart` | Create | 리포트 탭 내용(요약카드+하이라이트카드, GT 없음) |
| `presentation/nightly_report_screen.dart` | Delete | 홈 별도화면 폐기 |
| `presentation/widgets/nightly_report_badge.dart` (home) | Modify | 리포트 탭으로 이동 + 적응 문구 |
| `presentation/my_cage_providers.dart` | Modify | GT provider 제거 + `nightlyReportProvider` |
| `my_pets/presentation/my_pets_screen.dart` | Modify | 2탭 + 리포트 탭=NightlyReportView |
| `my_pets/presentation/my_pets_providers.dart` | Modify | `myPetsTabProvider`(배지→탭) |
| `core/router/app_router.dart` | Modify | `/home/highlights*` 제거 + `/my-pets/clips/:clipId` 추가 |
| `assets/l10n/ko.json` | Modify | GT 키 제거 + 요약 키 추가 |

**테스트 전략:** 순수 로직만 TDD(`lastNightSince`/`lastNightEnd`, `NightlyHighlight.fromJson`, `NightlyReport` 카운트 getter). 나머지 analyze+build+통합검증.

---

## Task 1: 재생 버튼 가시성

**Files:** Modify `motion_clip_player_screen.dart`

- [ ] **Step 1:** 앱바 leading/actions 아이콘을 **흰색 + 반투명 검은 원형 배경**으로. 파일 상단(또는 하단)에 헬퍼 위젯 추가:
```dart
/// 검은 영상 위에서 잘 보이는 원형 반투명 아이콘 버튼.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton(
      {required this.icon, required this.onPressed, this.color, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon,
              color: onPressed == null
                  ? Colors.white38
                  : (color ?? Colors.white)),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
```
- [ ] **Step 2:** 앱바에서 back/favorite/download/share를 `_GlassIconButton`으로 교체:
  - `leading:` → `_GlassIconButton(icon: Icons.arrow_back, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => context.pop())` (leading 폭이 좁으면 `leadingWidth: 56` 지정).
  - actions 즐겨찾기 → `_GlassIconButton(icon: isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white, tooltip: 'clip_favorite_add'.tr(), onPressed: _busy ? null : () => _toggleFavorite(clip))`
  - actions 저장 → `_GlassIconButton(icon: Icons.download_outlined, tooltip: 'clip_save'.tr(), onPressed: _busy ? null : _save)`
  - actions 공유 → `_GlassIconButton(icon: Icons.ios_share, tooltip: 'clip_share'.tr(), onPressed: _busy ? null : _share)`
  - AppBar는 `backgroundColor: Colors.black`(투명 대신 유지) — 아이콘 원형이 대비를 주므로 충분.

- [ ] **Step 3:** analyze. (커밋은 Task 2와 함께)
Run: `flutter analyze lib/features/my_cage/presentation/motion_clip_player_screen.dart`

---

## Task 2: 재생바 Slider 시크 (탭 점프)

**Files:** Modify `presentation/widgets/video_controls.dart`

- [ ] **Step 1:** `VideoProgressIndicator`를 **Slider**로 교체(탭한 지점 즉시 점프 + 드래그). `_VideoControlsState.build`의 Column children에서 `VideoProgressIndicator(...)` 블록을 아래로 교체:
```dart
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _sliderValue(v),
              onChanged: (val) {
                final dur = v.duration.inMilliseconds;
                if (dur > 0) {
                  ctrl.seekTo(Duration(milliseconds: (val * dur).round()));
                }
              },
            ),
          ),
```
그리고 `_VideoControlsState`에 헬퍼 추가(0~1 클램프, duration 0 방어):
```dart
  double _sliderValue(VideoPlayerValue v) {
    final dur = v.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (v.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }
```
> Slider는 탭 시 해당 위치로 값이 바뀌며 `onChanged` 호출 → 즉시 seek. 드래그도 동일. 시간 라벨(0:17/0:32) Row와 10초 버튼 Row는 그대로 유지.

- [ ] **Step 2:** analyze + 커밋(Task 1+2).
Run: `flutter analyze lib/features/my_cage/presentation/widgets/video_controls.dart lib/features/my_cage/presentation/motion_clip_player_screen.dart`
```bash
git add lib/features/my_cage/presentation/widgets/video_controls.dart \
        lib/features/my_cage/presentation/motion_clip_player_screen.dart
git commit -m "fix(my_cage): 재생 버튼 가시성(반투명 원형) + 재생바 Slider 탭 시크"
```

---

## Task 3: 범위 22~06시 + GT 컨트롤러/필드/엔드포인트 제거

**Files:** Modify `highlights_controller.dart`, `last_night_since_test.dart`, `nightly_highlight.dart`, `nightly_highlight_test.dart`, `highlight_repository.dart`

- [ ] **Step 1: `highlights_controller.dart` — 범위 헬퍼만 남기고 GT 컨트롤러 삭제**

파일을 아래로 교체(HighlightsController 클래스 통째 삭제, 범위 헬퍼 2개만):
```dart
/// "어젯밤" 시작 = 어제 22:00(로컬).
DateTime lastNightSince(DateTime now) =>
    DateTime(now.year, now.month, now.day, 22)
        .subtract(const Duration(days: 1));

/// "어젯밤" 끝 = 오늘 06:00. 단 지금이 06시 이전이면 현재 시각(밤 진행 중).
DateTime lastNightEnd(DateTime now) {
  final six = DateTime(now.year, now.month, now.day, 6);
  return now.isBefore(six) ? now : six;
}
```
> import(`flutter_riverpod`, repository, domain)도 불필요해지면 제거. 이 파일은 이제 순수 헬퍼만.

- [ ] **Step 2: `last_night_since_test.dart` — 22시로 + end 테스트 추가**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/highlights_controller.dart';

void main() {
  group('lastNightSince (어제 22:00)', () {
    test('오전 → 어제 22:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 10)),
          DateTime(2026, 7, 7, 22));
    });
    test('월 경계', () {
      expect(lastNightSince(DateTime(2026, 8, 1, 3)),
          DateTime(2026, 7, 31, 22));
    });
  });
  group('lastNightEnd', () {
    test('06시 이후 → 오늘 06:00', () {
      expect(lastNightEnd(DateTime(2026, 7, 8, 15)),
          DateTime(2026, 7, 8, 6));
    });
    test('06시 이전 → 현재 시각', () {
      final now = DateTime(2026, 7, 8, 3, 30);
      expect(lastNightEnd(now), now);
    });
  });
}
```
Run: `flutter test test/features/my_cage/last_night_since_test.dart` → PASS.

- [ ] **Step 3: `nightly_highlight.dart` — GT 필드 제거**

`HighlightReview` enum 삭제. 클래스를 아래로(clipId/startedAt/vlmAction/confidence/careLevel만):
```dart
/// terra-api GET /clips/highlights 항목(보기 전용). clip_id=motion_clips.id(미러)라
/// 썸네일(motionThumbnailProvider)·재생(MotionClipPlayerScreen) 재사용.
class NightlyHighlight {
  final String clipId;
  final DateTime startedAt;
  final String vlmAction;
  final double confidence;
  final String careLevel; // 'care' | 'enrichment'

  const NightlyHighlight({
    required this.clipId,
    required this.startedAt,
    required this.vlmAction,
    required this.confidence,
    required this.careLevel,
  });

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
    return NightlyHighlight(
      clipId: j['clip_id'] as String? ?? '',
      startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ??
          DateTime.now(),
      vlmAction: j['vlm_action'] as String? ?? 'unseen',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      careLevel: j['care_level'] as String? ?? 'care',
    );
  }
}
```

- [ ] **Step 4: `nightly_highlight_test.dart` — GT 케이스 제거**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';

void main() {
  test('NightlyHighlight.fromJson 매핑', () {
    final h = NightlyHighlight.fromJson({
      'clip_id': 'c1',
      'started_at': '2026-07-07T13:07:00Z',
      'vlm_action': 'drinking',
      'confidence': 0.62,
      'care_level': 'care',
    });
    expect(h.clipId, 'c1');
    expect(h.vlmAction, 'drinking');
    expect(h.careLevel, 'care');
    expect(h.confidence, closeTo(0.62, 0.001));
  });
  test('필드 누락 → 방어 기본값', () {
    final h = NightlyHighlight.fromJson(<String, dynamic>{});
    expect(h.clipId, '');
    expect(h.vlmAction, 'unseen');
    expect(h.careLevel, 'care');
  });
}
```
Run: `flutter test test/features/my_cage/nightly_highlight_test.dart` → PASS.

- [ ] **Step 5: `highlight_repository.dart` — submitLabel 삭제**

`submitLabel` 메서드 전체 삭제. `list`만 남긴다. (import 정리)

- [ ] **Step 6:** analyze (커밋은 Task 4와 함께 — provider 정리가 이어짐)
Run: `flutter analyze lib/features/my_cage/presentation/highlights_controller.dart lib/features/my_cage/domain/nightly_highlight.dart lib/features/my_cage/data/highlight_repository.dart`

---

## Task 4: 리포트 뷰(마이 크레 통합) + 요약 + 홈배지 + 라우트

**Files:** Create `domain/nightly_report.dart`, `presentation/nightly_report_view.dart` · Delete `nightly_report_screen.dart` · Modify `my_cage_providers.dart`, `nightly_report_badge.dart`, `my_pets_screen.dart`, `my_pets_providers.dart`, `app_router.dart`, `ko.json`

- [ ] **Step 1: NightlyReport 도메인 (TDD)**

`test/features/my_cage/nightly_report_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_report.dart';

NightlyHighlight h(String a) => NightlyHighlight(
    clipId: a, startedAt: DateTime(2026, 7, 7, 23), vlmAction: a,
    confidence: 0.7, careLevel: 'care');

void main() {
  test('행동 카운트 분류', () {
    final r = NightlyReport(activitySeconds: 3600, highlights: [
      h('drinking'), h('drinking'),
      h('hand_feeding'), h('eating_paste'), h('eating_prey'),
      h('shedding'),
      h('unseen'),
    ]);
    expect(r.drinkCount, 2);
    expect(r.eatCount, 3); // hand_feeding+eating_paste+eating_prey
    expect(r.shedCount, 1);
    expect(r.activityMinutes, 60);
  });
}
```
`lib/features/my_cage/domain/nightly_report.dart`:
```dart
import 'nightly_highlight.dart';

/// 어젯밤(22~06시) 요약 = 활동 시간 + 하이라이트 목록 + 행동 카운트(파생).
/// 카운트는 AI 샘플 감지분(전수 아님).
class NightlyReport {
  final int activitySeconds; // 밤 구간 motion_clips duration 합(전 카메라)
  final List<NightlyHighlight> highlights;

  const NightlyReport(
      {required this.activitySeconds, required this.highlights});

  static const _eat = {'hand_feeding', 'eating_paste', 'eating_prey'};

  int get activityMinutes => (activitySeconds / 60).round();
  int _count(bool Function(String) f) =>
      highlights.where((h) => f(h.vlmAction)).length;
  int get drinkCount => _count((a) => a == 'drinking');
  int get eatCount => _count(_eat.contains);
  int get shedCount => _count((a) => a == 'shedding');
  bool get isQuiet => highlights.isEmpty;
}
```
Run: `flutter test test/features/my_cage/nightly_report_test.dart` → PASS.

- [ ] **Step 2: provider 정리 + nightlyReportProvider**

`my_cage_providers.dart`에서 **GT provider 제거**: `nightlyHighlightsProvider`(StateNotifier)·`highlightBadgeCountProvider`를 삭제하고, `highlightsController.dart`가 이제 헬퍼만이므로 관련 import 정리. import에 `../domain/nightly_report.dart` 추가.
아래로 교체/추가:
```dart
// ── 어젯밤 리포트 (terra-api, 보기 전용) ──────────────────────────────────────

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository(
    terraApiUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

/// 어젯밤(22~06시) 요약 — 하이라이트(전 카메라) + 활동시간 합. 계정 전환 시 재조회.
final nightlyReportProvider =
    FutureProvider.autoDispose<NightlyReport>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final now = DateTime.now();
  final start = lastNightSince(now);
  final end = lastNightEnd(now);
  final all = await ref.watch(highlightRepositoryProvider).list(since: start);
  // 창 [start,end]로 클램프(늦은 저녁 오늘밤 조기 하이라이트 제외)
  final highlights = all
      .where((h) => h.startedAt.isAfter(start) && h.startedAt.isBefore(end))
      .toList();
  // 활동시간 = 전 카메라 motionSeconds 합
  final cameras = await ref.watch(camerasProvider.future);
  final motionRepo = ref.watch(motionClipRepositoryProvider);
  var sec = 0;
  for (final c in cameras) {
    sec += await motionRepo.motionSeconds(c.id, start, end);
  }
  return NightlyReport(activitySeconds: sec, highlights: highlights);
});
```
> `highlights_controller.dart`의 `lastNightSince`/`lastNightEnd` import 추가. `camerasProvider`·`motionClipRepositoryProvider`·`currentUserProvider`는 이 파일에 이미 존재.

- [ ] **Step 3: ko.json — GT 키 제거 + 요약 키**

제거: `nightly_confirm_*`, `nightly_corrected_to`, `nightly_correct_sheet_title`, `nightly_report_ai_estimate`(카드에서 confidence 노출 뺄지는 유지 가능 — 남겨도 무방). 추가:
```json
  "nightly_report_window": "어젯밤 (22~06시)",
  "nightly_activity": "활동",
  "nightly_count_drink": "물",
  "nightly_count_eat": "밥",
  "nightly_count_shed": "탈피",
  "nightly_count_unit": "{n}회",
  "nightly_quiet": "조용한 밤이었어요",
  "nightly_report_badge_quiet": "조용한 밤이었어요",
```
> `nightly_report_badge_sub`("확인 안 한 하이라이트 {n}건")는 문구 교체: `"nightly_report_badge_sub": "하이라이트 {n}건"`.

- [ ] **Step 4: NightlyReportView (리포트 탭 내용, GT 없음)**

`lib/features/my_cage/presentation/nightly_report_view.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/nightly_highlight.dart';
import '../domain/nightly_report.dart';
import 'my_cage_providers.dart';

/// vlm_action 라벨(clip_action_* 키, 없으면 원문 폴백).
String reportActionLabel(String action) {
  final key = 'clip_action_$action';
  final t = key.tr();
  return t == key ? action : t;
}

/// 마이 크레 > 리포트 탭 내용. 어젯밤 요약 + 하이라이트(보기/재생).
class NightlyReportView extends ConsumerWidget {
  const NightlyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nightlyReportProvider);
    return async.when(
      loading: () => ListView(
        padding: AppStyles.pagePadding,
        children: const [
          SkeletonCard(lineCount: 2, height: 90),
          SizedBox(height: 12),
          SkeletonCard(lineCount: 2, height: 120),
        ],
      ),
      error: (_, __) => Center(
        child: InlineRetry(
            onRetry: () => ref.invalidate(nightlyReportProvider)),
      ),
      data: (report) => ListView(
        padding: AppStyles.pagePadding,
        children: [
          _SummaryCard(report: report),
          const SizedBox(height: 16),
          if (report.highlights.isEmpty)
            _QuietBox()
          else
            ...report.highlights
                .map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HighlightCard(highlight: h),
                    )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final NightlyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = report.activityMinutes ~/ 60;
    final m = report.activityMinutes % 60;
    final activity = h > 0 ? '${h}h ${m}m' : '${m}m';
    final stats = <(String, String, String)>[
      ('⏱️', 'nightly_activity'.tr(), activity),
      ('💧', 'nightly_count_drink'.tr(),
          'nightly_count_unit'.tr(namedArgs: {'n': '${report.drinkCount}'})),
      ('🍽️', 'nightly_count_eat'.tr(),
          'nightly_count_unit'.tr(namedArgs: {'n': '${report.eatCount}'})),
      if (report.shedCount > 0)
        ('🐍', 'nightly_count_shed'.tr(),
            'nightly_count_unit'.tr(namedArgs: {'n': '${report.shedCount}'})),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('nightly_report_window'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: stats
                .map((s) => Expanded(
                      child: Column(
                        children: [
                          Text(s.$1,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(s.$2,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.outline)),
                          const SizedBox(height: 2),
                          Text(s.$3,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QuietBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text('nightly_quiet'.tr(),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline)),
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.highlight});
  final NightlyHighlight highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final careColor =
        highlight.careLevel == 'enrichment' ? cs.secondary : cs.primary;
    final thumb = ref.watch(motionThumbnailProvider(highlight.clipId));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/my-pets/clips/${highlight.clipId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: thumb.when(
                data: (url) => url != null
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonLoading(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0),
                        errorWidget: (_, __, ___) => _fallback(cs),
                      )
                    : _fallback(cs),
                loading: () => const SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0),
                error: (_, __) => _fallback(cs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: careColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(reportActionLabel(highlight.vlmAction),
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: careColor, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM.dd HH:mm')
                        .format(highlight.startedAt.toLocal()),
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                  const Spacer(),
                  Icon(Icons.play_circle_outline, color: cs.outline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_outline,
            color: cs.onSurface.withValues(alpha: 0.35), size: 40),
      );
}
```

- [ ] **Step 5: `nightly_report_screen.dart` 삭제**
Run: `git rm lib/features/my_cage/presentation/nightly_report_screen.dart`

- [ ] **Step 6: my_pets 탭 = [개체목록 | 리포트], 리포트=NightlyReportView**

`my_pets_providers.dart`에 추가(배지→탭 이동용):
```dart
/// 마이 크레 선택 탭: 0=개체목록, 1=리포트. 홈 배지가 1로 세팅 후 이동.
final myPetsTabProvider = StateProvider<int>((ref) => 0);
```
`my_pets_screen.dart`:
- `enum _MyPetsTab { list, report, highlights }` → `{ list, report }`(highlights 제거).
- `_tabContent`의 `report` 케이스를 `const NightlyReportView()`로, `highlights` 케이스 삭제.
- `_TabChips` items에서 highlights 항목 제거.
- 선택 상태를 `myPetsTabProvider`와 연동: `_selected` 로컬 대신 `final idx = ref.watch(myPetsTabProvider); final selected = idx == 1 ? _MyPetsTab.report : _MyPetsTab.list;`, 칩 onTap은 `ref.read(myPetsTabProvider.notifier).state = (t == _MyPetsTab.report ? 1 : 0)`. (ConsumerStatefulWidget 유지, `_selected` 필드 제거)
- import: `import '../../my_cage/presentation/nightly_report_view.dart';`
> `my_pets_report_placeholder`·`my_pets_highlights_placeholder`·`my_pets_tab_highlights` 키는 미사용이 되지만 ko.json에서 삭제하지 않아도 무방(정리 선택).

- [ ] **Step 7: 홈 배지 재타겟 + 적응 문구**

`nightly_report_badge.dart`:
- `highlightBadgeCountProvider`(삭제됨) 대신 `nightlyReportProvider`를 watch.
- 표시 규칙: 로딩/에러/카메라0 → `SizedBox.shrink()`. data면:
  - `report.highlights.isEmpty && report.activitySeconds == 0` → 숨김(밤 활동 전무).
  - else 노출. 서브문구 = 하이라이트>0면 `nightly_report_badge_sub`(하이라이트 N건), 아니면 `nightly_report_badge_quiet`.
- onTap: `ref.read(myPetsTabProvider.notifier).state = 1; context.go('/my-pets');`
```dart
    final async = ref.watch(nightlyReportProvider);
    final report = async.valueOrNull;
    if (report == null) return const SizedBox.shrink();
    if (report.highlights.isEmpty && report.activitySeconds == 0) {
      return const SizedBox.shrink();
    }
    final n = report.highlights.length;
    final sub = n > 0
        ? 'nightly_report_badge_sub'.tr(namedArgs: {'n': '$n'})
        : 'nightly_report_badge_quiet'.tr();
    // onTap:
    //   ref.read(myPetsTabProvider.notifier).state = 1;
    //   context.go('/my-pets');
```
> import: `import '../../../my_pets/presentation/my_pets_providers.dart';`. 나머지 카드 레이아웃(로고 이모지+제목+서브+chevron)은 기존 유지.

- [ ] **Step 8: 라우터 — /home/highlights* 제거, /my-pets/clips/:clipId 추가**

`app_router.dart`:
- `/home` 브랜치의 `highlights`(+`:clipId`) GoRoute **삭제**.
- `/my-pets` 브랜치에 재생 라우트 추가(리포트 카드 탭 → 재생, 마이크레 탭 유지):
```dart
              GoRoute(
                path: 'clips/:clipId',
                builder: (context, state) => MotionClipPlayerScreen(
                    clipId: state.pathParameters['clipId']!),
              ),
```
- `NightlyReportScreen` import 제거, `MotionClipPlayerScreen` import는 유지(있으면).
> 정적경로가 `:petId` 등 파라미터 경로보다 먼저 오도록. 구현자: `/my-pets` 브랜치 구조 Read 후 배치.

- [ ] **Step 9: 전체 analyze + test + build + 버전 bump + 커밋(Task 3+4)**

Run: `flutter analyze` (신규/수정 에러 0)
Run: `flutter test` (전체 PASS — nightly_report/nightly_highlight/last_night_since 포함)
Run: `flutter build apk --debug` (성공)
버전 minor bump(현재 → minor+1, build+1).
```bash
git add -A
git commit -m "feat(report): GT 제거 + 어젯밤 요약 리포트를 마이크레 탭에 통합 + 22~06시 + vX"
```

---

## 완료 후 (통합검증, 실기기 — 사용자)

- 재생화면: ←/♡/⬇/⤴ 원형으로 또렷, 재생바 **탭하면 그 지점으로 점프**.
- 마이 크레 → 리포트 탭: 상단 요약(활동 Xh Ym·물 N·밥 N, 탈피는 감지시), 하단 하이라이트 카드 탭 재생. **GT 버튼 없음**.
- 홈 배지 탭 → 마이 크레 리포트 탭으로 이동. 하이라이트 0이면 "조용한 밤" 문구.
- 어젯밤 범위 22~06시 반영.

## Self-Review

**1. Spec 커버리지:** ①버튼(T1) ②Slider 시크(T2) ③22~06시(T3 lastNightSince/End) ④GT 제거(T3: 컨트롤러/필드/submitLabel/provider/ko키 + T4: 화면 GT 없음) ⑤리포트 통합(T4: NightlyReport+View+my_pets 2탭+요약+배지 재타겟+라우트). gap 없음.

**2. Placeholder 스캔:** 실제 코드/삭제 명령. "구현자 Read 후 배치"(T4 S8)는 배치 지시.

**3. 타입 일관성:**
- `NightlyHighlight{clipId,startedAt,vlmAction,confidence,careLevel}`(GT 필드 제거) — T3 정의 = fromJson/test = NightlyReport 카운트(vlmAction) = View 카드(vlmAction/careLevel/startedAt) 일치.
- `NightlyReport{activitySeconds,highlights}` + getter(activityMinutes/drinkCount/eatCount/shedCount/isQuiet) — T4S1 정의 = test = View `_SummaryCard` 소비 일치.
- `nightlyReportProvider`(FutureProvider→NightlyReport) — T4S2 정의 = View·배지 소비 일치. GT provider(nightlyHighlightsProvider/highlightBadgeCountProvider) 제거 → 참조부(옛 화면/배지) 전부 교체.
- `lastNightSince/lastNightEnd(DateTime)→DateTime` — T3 정의 = test = provider 사용.
- `myPetsTabProvider`(StateProvider<int>) — T4S6 정의 = my_pets_screen watch = 배지 set 일치.
- 라우트 `/my-pets/clips/:clipId`=MotionClipPlayerScreen(clipId) — 카드 push와 일치. `/home/highlights*` 제거로 참조 없음(배지가 유일 진입이었고 재타겟).
- `motionClipRepositoryProvider.motionSeconds(String,DateTime,DateTime)→Future<int>` 재사용(확인됨).

**주의(구현자):**
- GT 제거로 미사용 될 ko 키/ import 정리. `nightly_report_screen.dart` 삭제 후 라우터/‏import 잔여 참조 0 확인.
- 배지 onTap `context.go('/my-pets')`는 바텀냅 탭 전환(StatefulShellRoute) — go 사용(push 아님).
- 리포트 활동시간=전 카메라 합. 카메라 0이면 배지 숨김 조건에 걸림.
- 탈피는 백엔드 억제로 현재 0 → shedCount>0일 때만 슬롯 노출(의도).
