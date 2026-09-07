import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/favorite_clip.dart';
import 'my_cage_providers.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'widgets/crecam_states.dart';
import 'widgets/motion_clip_thumb.dart';

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
    final glass = context.glass;
    final favoritesAsync = ref.watch(allFavoriteClipsProvider);
    final day = ref.watch(bookmarksDayFilterProvider);

    return Scaffold(
      backgroundColor: glass.wallpaper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CrecamDetailTopBar(
              title: 'crecam_bookmarks_title'.tr(),
              onCalendarTap: () => _pickDay(context, ref, day),
            ),
            if (day != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(_margin, 8, _margin, 0),
                child: CrecamDateFilterChip(
                  day: day,
                  onClear: () =>
                      ref.read(bookmarksDayFilterProvider.notifier).state =
                          null,
                ),
              ),
            Expanded(
              child: favoritesAsync.when(
                loading: () => const _ListSkeleton(),
                error: (_, __) => CrecamErrorRetry(
                  onRetry: () => ref.invalidate(allFavoriteClipsProvider),
                ),
                data: (favorites) => _list(context, favorites, day),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showCrecamDayPicker(context, current);
    if (picked == null || !context.mounted) return;
    ref.read(bookmarksDayFilterProvider.notifier).state = picked;
  }

  Widget _list(
      BuildContext context, List<FavoriteClip> favorites, DateTime? day) {
    final filtered = day == null
        ? favorites
        : favorites.where((f) {
            final t = f.startedAt.toLocal();
            return t.year == day.year &&
                t.month == day.month &&
                t.day == day.day;
          }).toList();

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
    final thumb =
        MotionClipThumb(clipId: clip.clipId, fallbackIconSize: 28);

    return GestureDetector(
      key: ValueKey('bookmark_card_${clip.clipId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.push('/crecam/player/${clip.clipId}', extra: playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _headerLabel(clip.startedAt.toLocal()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 16 * -0.02,
              color: glass.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: AspectRatio(aspectRatio: 369 / 180, child: thumb),
          ),
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
