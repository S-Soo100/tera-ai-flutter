# 어젯밤 리포트(하이라이트) Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 사용자 "승인" → flutter-dev가 task별 구현(GATE 4). Steps use checkbox (`- [ ]`).
> 작성일: 2026-07-08 · 대상: 홈 배지 + 새 화면 `/home/highlights` + 확인루프(HITL GT)

**Goal:** 밤새 VLM이 감지한 케어행동 하이라이트를 "어젯밤 리포트"로 보여주고, 사용자 확인(👍/정정/오탐)으로 GT를 쌓는다.

**Architecture:** 방금 납품된 **terra-api**(`EnvConfig.terraServerUrl`) 엔드포인트 `GET /clips/highlights`·`POST /clips/{id}/labels`로 **신규** 구축한다. ⚠️ 기존 `ClipRepository.getHighlights`/`HighlightsPage`는 **옛 petcam-lab 경로**(`_backendUrl`, 앱계정 0건, 스키마 다름)라 **재사용하지 않는다**(camera_clips vs motion_clips 비대칭과 동일). 썸네일은 이미 스왑된 `motionThumbnailProvider(clipId)` 재사용(하이라이트 `clip_id`=motion_clips.id 미러라 그대로 동작). 재생도 기존 `MotionClipPlayerScreen` 재사용.

**Tech Stack:** Flutter · Riverpod(StateNotifier) · http · go_router · easy_localization · (신규 패키지 없음)

**API 계약 (terra-api, base=terraServerUrl):**
- `GET /clips/highlights?since=<ISO8601>&limit=<n>` (JWT) → `{"highlights":[{clip_id, started_at, thumbnail_key, vlm_action, confidence, care_level, user_confirmed}]}`. `user_confirmed`: null(미확인) | true(확정) | false | 정정된 action 문자열. `care_level`: `care`|`enrichment`.
- `POST /clips/{id}/labels` (JWT) body `{action, lick_target?, note?}` → behavior_labels UPSERT. 👍=vlm_action 그대로 / 정정=선택 action / **👎(오탐)만은 호출 안 함**.

**범위 밖(후속):** 오탐 영구 숨김(현재 세션-로컬 dismiss, 서버 무기억) · 페이징(since 윈도우 내 전체, limit 50) · lick_target/note 입력(현재 미전송).

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `lib/features/my_cage/domain/nightly_highlight.dart` | Create | 하이라이트 모델 + `HighlightReview` enum + fromJson |
| `test/features/my_cage/nightly_highlight_test.dart` | Create | fromJson(user_confirmed 4형태) TDD |
| `lib/features/my_cage/data/highlight_repository.dart` | Create | terra-api list/submitLabel |
| `lib/features/my_cage/presentation/highlights_controller.dart` | Create | StateNotifier(load/confirm/correct/dismiss) + since 헬퍼 |
| `test/features/my_cage/last_night_since_test.dart` | Create | `lastNightSince` TDD |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | repo/notifier/badge provider 추가 |
| `lib/features/my_cage/presentation/nightly_report_screen.dart` | Create | 리포트 화면 + `_HighlightCard` + 정정 시트 |
| `lib/features/home/presentation/widgets/nightly_report_badge.dart` | Create | 홈 배지(0건 숨김) |
| `lib/features/home/presentation/home_screen.dart` | Modify | 배지 삽입(_LiveSection↔_ActivitySection) |
| `lib/core/router/app_router.dart` | Modify | `/home/highlights` + `/home/highlights/:clipId` |
| `assets/l10n/ko.json` | Modify | 신규 문자열 키 |

**테스트 전략:** 순수 로직만 TDD(`NightlyHighlight.fromJson`·`lastNightSince`). Repo/Notifier/화면은 http·Supabase·UI라 무테스트 + `flutter analyze` 0 + 통합검증.

---

## Task 1: NightlyHighlight 도메인 (TDD)

**Files:** Create `domain/nightly_highlight.dart`, `test/features/my_cage/nightly_highlight_test.dart`

- [ ] **Step 1: 실패 테스트**

`test/features/my_cage/nightly_highlight_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/nightly_highlight.dart';

void main() {
  Map<String, dynamic> base(Object? uc) => {
        'clip_id': 'c1',
        'started_at': '2026-07-07T13:07:00Z',
        'thumbnail_key': 'terra-clips/clips/x.jpg',
        'vlm_action': 'drinking',
        'confidence': 0.62,
        'care_level': 'care',
        'user_confirmed': uc,
      };

  group('NightlyHighlight.fromJson', () {
    test('user_confirmed=null → pending', () {
      final h = NightlyHighlight.fromJson(base(null));
      expect(h.clipId, 'c1');
      expect(h.vlmAction, 'drinking');
      expect(h.careLevel, 'care');
      expect(h.confidence, closeTo(0.62, 0.001));
      expect(h.review, HighlightReview.pending);
      expect(h.correctedAction, isNull);
    });
    test('user_confirmed=true → confirmed', () {
      expect(NightlyHighlight.fromJson(base(true)).review,
          HighlightReview.confirmed);
    });
    test('user_confirmed=false → pending(저장 안 된 상태로 취급)', () {
      expect(NightlyHighlight.fromJson(base(false)).review,
          HighlightReview.pending);
    });
    test('user_confirmed=문자열 → corrected + 정정action', () {
      final h = NightlyHighlight.fromJson(base('hand_feeding'));
      expect(h.review, HighlightReview.corrected);
      expect(h.correctedAction, 'hand_feeding');
    });
  });
}
```

- [ ] **Step 2: 실행 → 실패**

Run: `flutter test test/features/my_cage/nightly_highlight_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

`lib/features/my_cage/domain/nightly_highlight.dart`:
```dart
/// 확인 상태. pending=미확인, confirmed=AI행동 맞음, corrected=사용자가 다른 행동으로 정정.
enum HighlightReview { pending, confirmed, corrected }

/// terra-api GET /clips/highlights 항목. clip_id=motion_clips.id(미러 동일 UUID)라
/// 썸네일(motionThumbnailProvider)·재생(MotionClipPlayerScreen) 재사용 가능.
class NightlyHighlight {
  final String clipId;
  final DateTime startedAt;
  final String vlmAction; // 'drinking' | 'hand_feeding' | ...
  final double confidence; // 0~1
  final String careLevel; // 'care' | 'enrichment'
  final HighlightReview review;
  final String? correctedAction; // review==corrected일 때 정정된 action

  const NightlyHighlight({
    required this.clipId,
    required this.startedAt,
    required this.vlmAction,
    required this.confidence,
    required this.careLevel,
    required this.review,
    this.correctedAction,
  });

  NightlyHighlight copyWith(
      {HighlightReview? review, String? correctedAction}) {
    return NightlyHighlight(
      clipId: clipId,
      startedAt: startedAt,
      vlmAction: vlmAction,
      confidence: confidence,
      careLevel: careLevel,
      review: review ?? this.review,
      correctedAction: correctedAction ?? this.correctedAction,
    );
  }

  factory NightlyHighlight.fromJson(Map<String, dynamic> j) {
    final uc = j['user_confirmed'];
    HighlightReview review;
    String? corrected;
    if (uc == true) {
      review = HighlightReview.confirmed;
    } else if (uc is String && uc.isNotEmpty) {
      review = HighlightReview.corrected;
      corrected = uc;
    } else {
      review = HighlightReview.pending; // null / false
    }
    return NightlyHighlight(
      clipId: j['clip_id'] as String? ?? '',
      startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ??
          DateTime.now(),
      vlmAction: j['vlm_action'] as String? ?? 'unseen',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      careLevel: j['care_level'] as String? ?? 'care',
      review: review,
      correctedAction: corrected,
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/my_cage/nightly_highlight_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/domain/nightly_highlight.dart test/features/my_cage/nightly_highlight_test.dart`
```bash
git add lib/features/my_cage/domain/nightly_highlight.dart test/features/my_cage/nightly_highlight_test.dart
git commit -m "feat(my_cage): NightlyHighlight 도메인 + fromJson 테스트 (어젯밤 리포트)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: HighlightRepository (terra-api)

**Files:** Create `data/highlight_repository.dart`

- [ ] **Step 1: 구현**

`lib/features/my_cage/data/highlight_repository.dart`:
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nightly_highlight.dart';
import 'camera_exceptions.dart';

/// terra-api 하이라이트(어젯밤 리포트) + 라벨 확인(GT). motion_clip_repository와
/// 동일한 terra-api base + JWT 패턴.
class HighlightRepository {
  final String _terraApiUrl;
  final Future<String?> Function() _tokenProvider;

  HighlightRepository({
    required String terraApiUrl,
    required Future<String?> Function() tokenProvider,
  })  : _terraApiUrl = terraApiUrl,
        _tokenProvider = tokenProvider;

  /// [since] 이후 하이라이트 목록(최신순 가정, 서버 필터/억제셋 적용본).
  Future<List<NightlyHighlight>> list(
      {required DateTime since, int limit = 50}) async {
    final token = await _tokenProvider();
    final uri = Uri.parse('$_terraApiUrl/clips/highlights').replace(
      queryParameters: {
        'since': since.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    );
    final resp = await http.get(uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['highlights'] as List? ?? const []);
      return list
          .map((e) => NightlyHighlight.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (resp.statusCode == 404) return const [];
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 확인/정정 GT 제출 (POST /clips/{id}/labels, behavior_labels UPSERT).
  /// 👍=vlm_action 그대로, 정정=선택 action. 오탐(👎)은 호출하지 않는다.
  Future<void> submitLabel(String clipId, String action,
      {String? lickTarget, String? note}) async {
    final token = await _tokenProvider();
    final resp = await http.post(
      Uri.parse('$_terraApiUrl/clips/$clipId/labels'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        if (lickTarget != null) 'lick_target': lickTarget,
        if (note != null) 'note': note,
      }),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) return;
    throw BackendException(resp.statusCode, resp.body);
  }
}
```
> `BackendException(int, String)`은 `camera_exceptions.dart`에 존재(MotionClipRepository 사용). 시그니처 다르면 맞춰라.

- [ ] **Step 2: analyze**

Run: `flutter analyze lib/features/my_cage/data/highlight_repository.dart`
Expected: `No issues found!` (커밋은 Task 3과 함께)

---

## Task 3: Controller + Provider + since 헬퍼 (TDD)

**Files:** Create `presentation/highlights_controller.dart`, `test/features/my_cage/last_night_since_test.dart` · Modify `my_cage_providers.dart`

- [ ] **Step 1: 실패 테스트 (since 헬퍼)**

`test/features/my_cage/last_night_since_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/highlights_controller.dart';

void main() {
  group('lastNightSince', () {
    test('오전 → 어제 18:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 10)),
          DateTime(2026, 7, 7, 18));
    });
    test('늦은 밤 → 여전히 어제 18:00', () {
      expect(lastNightSince(DateTime(2026, 7, 8, 23)),
          DateTime(2026, 7, 7, 18));
    });
    test('월 경계', () {
      expect(lastNightSince(DateTime(2026, 8, 1, 9)),
          DateTime(2026, 7, 31, 18));
    });
  });
}
```

- [ ] **Step 2: 실행 → 실패**

Run: `flutter test test/features/my_cage/last_night_since_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: Controller + 헬퍼 구현**

`lib/features/my_cage/presentation/highlights_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/highlight_repository.dart';
import '../domain/nightly_highlight.dart';

/// "어젯밤" 시작 = 어제 18:00(로컬). now 기준.
DateTime lastNightSince(DateTime now) {
  final today18 = DateTime(now.year, now.month, now.day, 18);
  return today18.subtract(const Duration(days: 1));
}

/// 어젯밤 하이라이트 로드 + 확인/정정/오탐 로컬 반영. 홈 배지·리포트 화면 공용.
class HighlightsController
    extends StateNotifier<AsyncValue<List<NightlyHighlight>>> {
  HighlightsController(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final HighlightRepository _repo;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.list(since: lastNightSince(DateTime.now()));
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// 👍 확정 = vlm_action 그대로 GT 제출 + 로컬 confirmed.
  Future<void> confirm(NightlyHighlight h) async {
    await _repo.submitLabel(h.clipId, h.vlmAction);
    _patch(h.clipId,
        (x) => x.copyWith(review: HighlightReview.confirmed));
  }

  /// 정정 = 선택 action GT 제출 + 로컬 corrected.
  Future<void> correct(NightlyHighlight h, String action) async {
    await _repo.submitLabel(h.clipId, action);
    _patch(
        h.clipId,
        (x) => x.copyWith(
            review: HighlightReview.corrected, correctedAction: action));
  }

  /// 오탐 = 서버 저장 없이 목록에서 제거(세션-로컬).
  void dismiss(String clipId) {
    final cur = state.valueOrNull ?? const [];
    state = AsyncValue.data(
        cur.where((h) => h.clipId != clipId).toList());
  }

  void _patch(
      String clipId, NightlyHighlight Function(NightlyHighlight) f) {
    final cur = state.valueOrNull ?? const [];
    state = AsyncValue.data([
      for (final h in cur) h.clipId == clipId ? f(h) : h,
    ]);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/my_cage/last_night_since_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Provider 추가**

`my_cage_providers.dart` import에 추가:
```dart
import '../data/highlight_repository.dart';
import '../domain/nightly_highlight.dart';
import 'highlights_controller.dart';
```
`videoExportServiceProvider` 아래(파일 하단)에 추가:
```dart
// ── 어젯밤 리포트(하이라이트, terra-api) ──────────────────────────────────────

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository(
    terraApiUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

/// 어젯밤 하이라이트(로드+확인/정정/오탐). 홈 배지·리포트 화면 공용.
/// 계정 전환 시 재생성(이전 계정 노출 방지 — project_auth_provider_stale_pattern).
final nightlyHighlightsProvider = StateNotifierProvider.autoDispose<
    HighlightsController, AsyncValue<List<NightlyHighlight>>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return HighlightsController(ref.watch(highlightRepositoryProvider));
});

/// 홈 배지 카운트 = 미확인(pending) 하이라이트 수. 0이면 배지 숨김.
final highlightBadgeCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(nightlyHighlightsProvider).maybeWhen(
        data: (list) =>
            list.where((h) => h.review == HighlightReview.pending).length,
        orElse: () => 0,
      );
});
```
> `currentUserProvider`는 이 파일에 이미 import됨(camerasProvider 등에서 사용). `_tokenProviderProvider`·`EnvConfig`도 기존 존재.

- [ ] **Step 6: analyze + 커밋 (Task 2+3)**

Run: `flutter analyze lib/features/my_cage/data/highlight_repository.dart lib/features/my_cage/presentation/highlights_controller.dart lib/features/my_cage/presentation/my_cage_providers.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/data/highlight_repository.dart \
        lib/features/my_cage/presentation/highlights_controller.dart \
        test/features/my_cage/last_night_since_test.dart \
        lib/features/my_cage/presentation/my_cage_providers.dart
git commit -m "feat(my_cage): HighlightRepository + Controller + provider (어젯밤 리포트)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 리포트 화면 + 카드 + 정정 시트

**Files:** Create `presentation/nightly_report_screen.dart` · Modify `ko.json`

- [ ] **Step 1: ko.json 키 추가**

`assets/l10n/ko.json`에 추가:
```json
  "nightly_report_title": "어젯밤 리포트",
  "nightly_report_empty": "조용한 밤이었어요",
  "nightly_report_ai_estimate": "AI 추정",
  "nightly_report_care": "건강",
  "nightly_report_enrichment": "활동",
  "nightly_confirm_yes": "맞아요",
  "nightly_confirm_correct": "정정",
  "nightly_confirm_dismiss": "오탐",
  "nightly_confirm_done": "확정됨",
  "nightly_corrected_to": "{action}로 정정",
  "nightly_confirm_thanks": "확인 고마워요 — 정확도가 좋아져요",
  "nightly_correct_sheet_title": "올바른 행동을 골라주세요",
  "clip_action_basking": "일광욕",
  "clip_action_defecating": "배변",
```
> `clip_action_basking`/`_defecating`은 vlm_action 폴백용(기존 clip_action_* 미보유분). JSON 마지막 콤마 유의.

- [ ] **Step 2: 화면 구현**

`lib/features/my_cage/presentation/nightly_report_screen.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip_action.dart';
import '../domain/nightly_highlight.dart';
import 'my_cage_providers.dart';

/// vlm_action 라벨(clip_action_* 키, 없으면 원문 폴백).
String highlightActionLabel(String action) {
  final key = 'clip_action_$action';
  final t = key.tr();
  return t == key ? action : t;
}

class NightlyReportScreen extends ConsumerWidget {
  const NightlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(nightlyHighlightsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('nightly_report_title'.tr())),
      body: async.when(
        loading: () => ListView(
          padding: AppStyles.pagePadding,
          children: const [
            SkeletonCard(lineCount: 2, height: 120),
            SizedBox(height: 12),
            SkeletonCard(lineCount: 2, height: 120),
          ],
        ),
        error: (_, __) => Center(
          child: InlineRetry(
              onRetry: () =>
                  ref.read(nightlyHighlightsProvider.notifier).refresh()),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('nightly_report_empty'.tr(),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            );
          }
          return ListView.separated(
            padding: AppStyles.pagePadding,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HighlightCard(highlight: list[i]),
          );
        },
      ),
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.highlight});
  final NightlyHighlight highlight;

  Color _careColor(ColorScheme cs) =>
      highlight.careLevel == 'enrichment' ? cs.secondary : cs.primary;

  Future<void> _showCorrectSheet(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('nightly_correct_sheet_title'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...kClipActions.map((a) => ListTile(
                  title: Text(highlightActionLabel(a)),
                  onTap: () => Navigator.of(ctx).pop(a),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(nightlyHighlightsProvider.notifier).correct(highlight, action);
    messenger.showSnackBar(
        SnackBar(content: Text('nightly_confirm_thanks'.tr())));
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(nightlyHighlightsProvider.notifier).confirm(highlight);
    messenger.showSnackBar(
        SnackBar(content: Text('nightly_confirm_thanks'.tr())));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final careColor = _careColor(cs);
    final thumbAsync = ref.watch(motionThumbnailProvider(highlight.clipId));
    final reviewed = highlight.review != HighlightReview.pending;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: reviewed ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 썸네일 (탭 → 재생)
            InkWell(
              onTap: () =>
                  context.push('/home/highlights/${highlight.clipId}'),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbAsync.when(
                  data: (url) => url != null
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SkeletonLoading(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 0),
                          errorWidget: (_, __, ___) =>
                              _thumbFallback(cs),
                        )
                      : _thumbFallback(cs),
                  loading: () => const SkeletonLoading(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0),
                  error: (_, __) => _thumbFallback(cs),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 행동 칩 (care/enrichment 색)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: careColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          highlightActionLabel(highlight.correctedAction ??
                              highlight.vlmAction),
                          style: theme.textTheme.labelMedium
                              ?.copyWith(
                                  color: careColor,
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MM.dd HH:mm')
                            .format(highlight.startedAt.toLocal()),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                      const Spacer(),
                      // AI 추정 태그
                      Text(
                        '${'nightly_report_ai_estimate'.tr()} ${(highlight.confidence * 100).round()}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (reviewed)
                    Text(
                      highlight.review == HighlightReview.corrected
                          ? 'nightly_corrected_to'.tr(namedArgs: {
                              'action': highlightActionLabel(
                                  highlight.correctedAction ?? '')
                            })
                          : 'nightly_confirm_done'.tr(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: careColor),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: Text('nightly_confirm_yes'.tr()),
                            onPressed: () => _confirm(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text('nightly_confirm_correct'.tr()),
                            onPressed: () =>
                                _showCorrectSheet(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'nightly_confirm_dismiss'.tr(),
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(nightlyHighlightsProvider.notifier)
                              .dismiss(highlight.clipId),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_outline,
            color: cs.onSurface.withValues(alpha: 0.35), size: 40),
      );
}
```
> `SkeletonCard`·`SkeletonLoading`·`InlineRetry`는 기존 공유 위젯(camera_detail_screen에서 사용). import 경로는 그 파일과 동일하게 맞춰라(shared/widgets).

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/my_cage/presentation/nightly_report_screen.dart`
Expected: `No issues found!` (커밋은 Task 6과 함께)

---

## Task 5: 홈 배지

**Files:** Create `features/home/presentation/widgets/nightly_report_badge.dart` · Modify `home_screen.dart`

- [ ] **Step 1: 배지 위젯**

`lib/features/home/presentation/widgets/nightly_report_badge.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../my_cage/presentation/my_cage_providers.dart';

/// "어젯밤 리포트 · 하이라이트 N" 홈 배지. 미확인 0건이면 아무것도 안 그림.
class NightlyReportBadge extends ConsumerWidget {
  const NightlyReportBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(highlightBadgeCountProvider);
    if (count <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/home/highlights'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text('🦎', style: theme.textTheme.titleLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('nightly_report_title'.tr(),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        'nightly_report_badge_sub'
                            .tr(namedArgs: {'n': '$count'}),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ko.json 배지 서브텍스트 키**

`assets/l10n/ko.json`에 추가:
```json
  "nightly_report_badge_sub": "확인 안 한 하이라이트 {n}건",
```

- [ ] **Step 3: 홈 화면에 삽입**

`home_screen.dart` import에 추가:
```dart
import 'widgets/nightly_report_badge.dart';
```
홈 본문 Column에서 **_LiveSection과 _ActivitySection 사이**(현재 _LiveSection 위젯 뒤 spacing 다음)에 삽입:
```dart
            const NightlyReportBadge(),
```
> 정확한 위치: `_LiveSection(...)` 렌더 이후, `_ActivitySection` 이전. 기존 섹션 간 간격(SizedBox/spacing) 패턴을 따르되, 배지 위젯이 자체 `bottom:24` 패딩을 가지므로 0건일 때 빈 간격이 남지 않도록 배지가 `SizedBox.shrink()`를 반환하는 점을 고려(배지 앞뒤에 별도 큰 SizedBox 추가하지 말 것). 구현자: home_screen.dart의 해당 Column을 Read해 자연스러운 위치에 한 줄 삽입.

- [ ] **Step 4: analyze**

Run: `flutter analyze lib/features/home/presentation/widgets/nightly_report_badge.dart lib/features/home/presentation/home_screen.dart`
Expected: `No issues found!` (커밋은 Task 6과 함께)

---

## Task 6: 라우터 등록 + 통합

**Files:** Modify `app_router.dart` · 통합 analyze/test/build

- [ ] **Step 1: 라우트 등록**

`app_router.dart` import에 추가:
```dart
import '../../features/my_cage/presentation/nightly_report_screen.dart';
```
**`/home` 브랜치(StatefulShellBranch)의 하위 routes**에 추가한다. `/home` GoRoute의 `routes: [...]`에(없으면 새로 만들어) 아래를 넣는다:
```dart
              GoRoute(
                path: 'highlights',
                builder: (context, state) => const NightlyReportScreen(),
                routes: [
                  GoRoute(
                    path: ':clipId',
                    builder: (context, state) {
                      final id = state.pathParameters['clipId']!;
                      return MotionClipPlayerScreen(clipId: id);
                    },
                  ),
                ],
              ),
```
> `MotionClipPlayerScreen`은 이미 import돼 있을 것(motion-clips 라우트에서 사용). 없으면 import 추가. 재생 라우트를 `/home/highlights/:clipId`로 두는 이유: 홈 탭 안에서 재생해 **탭 전환 없이** 유지(카드 onTap이 `context.push('/home/highlights/${clipId}')`와 일치). `MotionClipPlayerScreen`은 라우트 위치와 무관하게 동작(clipId만 받음).
> 구현자: `app_router.dart`를 Read해 `/home` 브랜치의 정확한 구조를 확인하고, 정적 경로가 `:cameraId` 등 파라미터 경로보다 **먼저** 오도록 배치(GoRouter 매칭 순서).

- [ ] **Step 2: 전체 analyze**

Run: `flutter analyze`
Expected: 신규/수정 파일 이슈 0(기존 baseline info만).

- [ ] **Step 3: 테스트**

Run: `flutter test`
Expected: 전체 PASS(신규 nightly_highlight_test 4 + last_night_since_test 3 포함).

- [ ] **Step 4: 빌드 검증**

Run: `flutter build apk --debug`
Expected: 성공.

- [ ] **Step 5: 버전 bump + 커밋 (Task 4+5+6)**

`pubspec.yaml` version을 현재값에서 **minor+1**(feat) → 예상 `0.15.1+26` → `0.16.0+27`(현재값이 다르면 그에 맞춰 minor+1, build+1).
```bash
git add lib/features/my_cage/presentation/nightly_report_screen.dart \
        lib/features/home/presentation/widgets/nightly_report_badge.dart \
        lib/features/home/presentation/home_screen.dart \
        lib/core/router/app_router.dart assets/l10n/ko.json pubspec.yaml
git commit -m "feat(home,my_cage): 어젯밤 리포트 화면 + 홈 배지 + 확인루프(HITL GT) + vX

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (통합검증, 실기기)

- leegawnhun 로그인 → 홈에 "🦎 어젯밤 리포트 · N"(미확인>0 시) → 탭 → 카드 목록(썸네일·행동칩·AI추정%) → 맞아요/정정/오탐 동작(스낵바) → 썸네일 탭 재생(일시·워터마크·시크) → 뒤로 와도 확정상태 유지.
- 하이라이트 0건이면 배지 숨김 + 화면 "조용한 밤이었어요".
- ⚠️ terra-api `/clips/highlights`·`/clips/{id}/labels`가 terraServerUrl에 실재하는지 런타임 확인(썸네일 스왑과 동일 base 가정). 404/오류 시 화면은 빈/에러 폴백.

---

## Self-Review

**1. Spec 커버리지:**
- 홈 배지(어젯밤 리포트·N, 0건 숨김) → Task 5. 
- 리포트 화면(카드=썸네일·행동칩·care색·AI추정) → Task 4.
- 확인/정정/오탐(HITL GT, POST labels, 👎 미저장) → Task 2(submitLabel)+Task 3(confirm/correct/dismiss)+Task 4(버튼/시트).
- 재생 재사용(clip_id=motion_clips.id) → Task 6 라우트 `/home/highlights/:clipId` = MotionClipPlayerScreen.
- since=어제18:00 → Task 3(lastNightSince). 썸네일 재사용 → Task 4(motionThumbnailProvider).
- gap 없음. 옛 petcam-lab getHighlights 미사용 명시.

**2. Placeholder 스캔:** 실제 코드/명령만. "구현자: Read해 위치 확인"(Task 5 Step3·Task 6 Step1)은 배치 지시(코드 제공됨)라 placeholder 아님.

**3. 타입 일관성:**
- `NightlyHighlight{clipId,startedAt,vlmAction,confidence,careLevel,review,correctedAction?}` + `HighlightReview{pending,confirmed,corrected}` — Task 1 정의 = Task 2 fromJson = Task 3 patch(copyWith) = Task 4 카드 소비 일치. `copyWith(review,correctedAction)` 정의됨.
- `HighlightRepository{list({since,limit})→List<NightlyHighlight>, submitLabel(String,String,{lickTarget?,note?})→Future}` — Task 2 정의 = Task 3 Controller 호출 일치.
- `HighlightsController extends StateNotifier<AsyncValue<List<NightlyHighlight>>>{refresh,confirm(h),correct(h,action),dismiss(clipId)}` — Task 3 정의 = Task 4(`.notifier` 호출)·화면 `.when` 소비 일치.
- `nightlyHighlightsProvider`(StateNotifierProvider.autoDispose) · `highlightBadgeCountProvider`(→int) — Task 3 정의 = Task 4 화면 · Task 5 배지 일치.
- `lastNightSince(DateTime)→DateTime` — Task 3 정의 = 테스트 = Controller 사용 일치.
- `motionThumbnailProvider(String)→AsyncValue<String?>` — 기존(썸네일 스왑) = Task 4 카드 `thumbAsync.when(data:(url))` 일치.
- 라우트 `/home/highlights`·`/home/highlights/:clipId` — Task 5 배지 push · Task 4 카드 push · Task 6 등록 일치.

**주의(구현자):**
- terra-api base 가정(terraServerUrl). 썸네일 스왑이 같은 base라 일관. 런타임 미검증분은 통합검증에서.
- `home_screen.dart`·`app_router.dart`는 정확 구조를 Read 후 배치(줄번호 대신 내용 기준).
- 오탐 dismiss는 세션-로컬(서버 무기억) — 재진입 시 재출현 가능(범위 밖 명시).
- StateNotifier가 autoDispose라 홈 배지가 watch하는 동안 유지(홈 상주). 화면·배지가 동일 인스턴스 공유해 확정상태 일관.
```
