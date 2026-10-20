import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/favorite_clip.dart';
import 'my_cage_providers.dart';
import 'clip_visibility_providers.dart';
import 'clip_memo_providers.dart';
import 'widgets/clip_memo_card.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'widgets/crecam_states.dart';
import 'widgets/motion_clip_thumb.dart';
import 'clip_selection_providers.dart';
import 'widgets/clip_selection_flow.dart';
import 'widgets/clip_selection_widgets.dart';

const _scope = ClipSelectionScope.bookmarks;

/// 북마크 날짜 필터(클립 startedAt 기준, 자정 경계). null = 전체.
/// autoDispose — 화면 이탈 시 리셋.
final bookmarksDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 북마크 상세 (Figma 668:717, 카메라 탭 재설계 T3).
///
/// 세로 리스트: 카드 = 시각 헤더 + 풀폭 썸네일(369:180). 데이터는
/// [allFavoriteClipsProvider](favoritedAt desc — repository 정렬 그대로),
/// 표시 시각은 클립 startedAt. 카드 탭 → 세로 플레이어(재생목록 = 현재
/// 필터·정렬 순서의 북마크 전체).
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  /// Figma 콘텐츠 좌우 마진.
  static const double _margin = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clipVisibilityEntryRefreshProvider('bookmarks'));
    final glass = context.glass;
    final favoritesAsync = ref.watch(allFavoriteClipsProvider);
    final day = ref.watch(bookmarksDayFilterProvider);
    final selection = ref.watch(clipSelectionProvider(_scope));
    final batch = ref.watch(clipBatchProvider(_scope));
    final flow = ClipSelectionFlow(ref, _scope);
    // 날짜 필터가 바뀌면 안 보이게 된 영상이 골라진 채 남지 않게 비운다.
    ref.listen(bookmarksDayFilterProvider, (_, __) {
      ref.read(clipSelectionProvider(_scope).notifier).clearIds();
    });
    Future<void> leave() async {
      if (await flow.confirmLeave(context) && context.mounted) context.pop();
    }

    final scaffold = Scaffold(
      backgroundColor: glass.wallpaper,
      // Figma 1493:9274 — 선택 모드엔 아래에 선택 동작 바.
      bottomNavigationBar: selection.active
          ? flow.actionBar(context,
              all: () => [
                    for (final f in _visible(
                        ref.read(allFavoriteClipsProvider).valueOrNull ??
                            const [],
                        ref.read(bookmarksDayFilterProvider)))
                      f.clipId
                  ])
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma Rectangle 113 — status bar까지 surfaceHeader + 헤어라인.
          CrecamDetailHeaderArea(
            child: CrecamDetailTopBar(
              title: selection.active
                  ? 'clip_select_count'
                      .tr(namedArgs: {'count': '${selection.count}'})
                  : 'crecam_bookmarks_title'.tr(),
              onCalendarTap: () => _pickDay(context, ref, day),
              onBack: selection.active ? leave : null,
              trailing: selection.active
                  ? ClipSelectHeaderButton.exit(
                      onPressed: () => ref
                          .read(clipSelectionProvider(_scope).notifier)
                          .exit())
                  : ClipSelectHeaderButton.enter(
                      onPressed: () => ref
                          .read(clipSelectionProvider(_scope).notifier)
                          .enter()),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day != null)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(_margin, 8, _margin, 0),
                      child: CrecamDateFilterChip(
                        day: day,
                        onClear: () => ref
                            .read(bookmarksDayFilterProvider.notifier)
                            .state = null,
                      ),
                    ),
                  Expanded(
                    child: favoritesAsync.when(
                      // 진입 직후 숨김 목록 갱신이 이 목록을 다시 계산한다 — 그동안
                      // 이전 목록을 유지해야 스켈레톤 깜빡임·스크롤 초기화가 없다.
                      skipLoadingOnReload: true,
                      loading: () => const _ListSkeleton(),
                      error: (_, __) => CrecamErrorRetry(
                        onRetry: () {
                          ref.invalidate(
                              clipVisibilityEntryRefreshProvider('bookmarks'));
                          ref.invalidate(allFavoriteClipsProvider);
                        },
                      ),
                      data: (favorites) => _list(context, favorites, day),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return ClipSelectionBackGuard(
      scope: _scope,
      onLeave: leave,
      child: Stack(children: [
        scaffold,
        if (batch != null)
          ClipBatchOverlay(
              job: batch,
              onCancel: ref.read(clipBatchProvider(_scope).notifier).cancel),
      ]),
    );
  }

  /// 화면에 보이는 순서(북마크한 최신순 + 날짜 필터).
  static List<FavoriteClip> _visible(
      List<FavoriteClip> favorites, DateTime? day) {
    final sorted = [...favorites]
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
    return day == null
        ? sorted
        : sorted.where((f) {
            final t = f.startedAt.toLocal();
            return t.year == day.year &&
                t.month == day.month &&
                t.day == day.day;
          }).toList();
  }

  Future<void> _pickDay(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showCrecamDayPicker(context, current);
    if (picked == null || !context.mounted) return;
    ref.read(bookmarksDayFilterProvider.notifier).state = picked;
  }

  Widget _list(
      BuildContext context, List<FavoriteClip> favorites, DateTime? day) {
    final filtered = _visible(favorites, day);

    if (filtered.isEmpty) {
      // 북마크 자체가 없으면 기존 즐겨찾기 빈 문구, 필터 결과만 없으면 날짜 문구.
      return CrecamEmptyMessage(
        message: favorites.isEmpty
            ? 'clip_favorites_empty'.tr()
            : 'crecam_home_empty_day'.tr(),
      );
    }

    // 재생목록 = 현재 필터·정렬 순서의 북마크 clip id 전체.
    final playlist = [for (final f in filtered) f.clipId];

    return ListView.separated(
      // top 24 — Figma 668:717 상단바(4238)→첫 카드(4261) 실측 23≈24.
      padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, i) =>
          _BookmarkCard(clip: filtered[i], playlist: playlist),
    );
  }
}

/// 카드 한 장 — 헤더 "2026. 08. 12 · 오전 12:50" + 8 갭 + 썸네일(369:180, r12).
class _BookmarkCard extends ConsumerWidget {
  const _BookmarkCard({required this.clip, required this.playlist});

  final FavoriteClip clip;
  final List<String> playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final owner = ref.watch(clipMemoAccountProvider);
    final memoKey = (ownerId: clip.ownerId, clipId: clip.clipId);
    final memo = owner == clip.ownerId
        ? ref.watch(clipMemoProvider(memoKey)).valueOrNull
        : null;
    // 이 카드 몫만 구독 — 하나를 고를 때 모든 카드가 다시 그려지지 않게.
    final active =
        ref.watch(clipSelectionProvider(_scope).select((s) => s.active));
    final flow = ClipSelectionFlow(ref, _scope);
    void open() =>
        context.push('/crecam/player/${clip.clipId}', extra: playlist);
    final thumb = MotionClipThumb(
        clipId: clip.clipId, cameraId: clip.cameraId, fallbackIconSize: 28);
    final header = Text(
      _headerLabel(clip.startedAt.toLocal()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        height: 19.09375 / 16, // Figma 945:4351 Date h19 → 카드 y+27
        fontWeight: FontWeight.w600,
        letterSpacing: 16 * -0.02,
        color: glass.textSecondary,
      ),
    );

    return GestureDetector(
      key: ValueKey('bookmark_card_${clip.clipId}'),
      behavior: HitTestBehavior.opaque,
      // 선택 모드에선 카드 탭 = 고르기, 영상 보기는 확대 버튼(Figma 1493:9274).
      onTap: active ? () => flow.toggle(context, clip.clipId) : open,
      onLongPress: () => flow.longPress(context, clip.clipId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: header),
            ClipSelectItemCheck(scope: _scope, clipId: clip.clipId),
          ]),
          const SizedBox(height: 8),
          SizedBox(
              height: 180,
              child: Row(children: [
                Expanded(
                    child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Stack(fit: StackFit.expand, children: [
                    thumb,
                    if (active)
                      Positioned(
                          right: 4,
                          bottom: 4,
                          child: ClipSelectExpandButton(
                              clipId: clip.clipId, onTap: open)),
                  ]),
                )),
                if (memo != null) ...[
                  const SizedBox(width: 8),
                  ClipMemoCard(memo: memo, memoKey: memoKey),
                ],
              ])),
        ],
      ),
    );
  }

  /// "2026. 08. 12 · 오전 12:50" — 시각은 공용 [formatAmPmTime].
  static String _headerLabel(DateTime t) =>
      '${DateFormat('yyyy. MM. dd').format(t)} · ${formatAmPmTime(t)}';
}

/// 로딩 스켈레톤 — 카드 2장(헤더 줄 + 썸네일 면, shimmer, CPI 금지).
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          BookmarksScreen._margin, 24, BookmarksScreen._margin, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoading(width: 180, height: 16),
          SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 369 / 180,
            child: SkeletonLoading(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
