import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/am_pm_time.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/motion_clip.dart';
import '../../domain/clip_playlist_args.dart';
import '../../domain/motion_clip_page.dart';
import '../clip_feed_controller.dart';
import 'clip_grid.dart';
import 'crecam_states.dart';
import 'favorite_bookmark_badge.dart';
import 'motion_clip_thumb.dart';

/// Flatten into hour headers and three-cell rows, so an hour with hundreds of
/// clips is still built one visible row at a time.
class ClipFeedSlivers extends ConsumerWidget {
  const ClipFeedSlivers({super.key, required this.query});
  final ClipFeedQuery? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = query;
    if (key == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final state = ref.watch(clipFeedProvider(key));
    final controller = ref.read(clipFeedProvider(key).notifier);
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: state.initialLoading
            ? const SkeletonLoading(width: double.infinity, height: 120)
            : state.pageError != null
                ? CrecamErrorRetry(onRetry: controller.refresh)
                : Center(
                    child: Text(
                        (key.range == null
                                ? 'crecam_home_empty_all'
                                : 'crecam_home_empty_day')
                            .tr(),
                        style: TextStyle(color: context.glass.textTertiary))),
      ));
    }
    final groups = <DateTime, List<MotionClip>>{};
    for (final clip in state.items) {
      final time = clip.startedAt.toLocal();
      final hour = DateTime(time.year, time.month, time.day, time.hour);
      groups.putIfAbsent(hour, () => []).add(clip);
    }
    // 시간 헤더는 피드를 읽기 쉽게 나누는 시각적 그룹이다. 플레이어는
    // 현재 카메라·현재 기간의 전체 피드를 사진 앱처럼 하나로 탐색한다.
    final playlist = state.items.map((clip) => clip.id).toList(growable: false);
    final rows = <WidgetBuilder>[];
    DateTime? previousDate;
    for (final group in groups.entries) {
      final date = DateTime(group.key.year, group.key.month, group.key.day);
      final label =
          previousDate != date ? DateFormat('yyyy. M. d').format(date) : null;
      previousDate = date;
      rows.add((context) => Padding(
            key: ValueKey('clip_hour_${group.key.toIso8601String()}'),
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              Expanded(
                  child: Text(formatAmPmTime(group.key),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.glass.textSecondary))),
              if (label != null)
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.glass.textTertiary)),
            ]),
          ));
      for (var start = 0; start < group.value.length; start += 3) {
        final rowOffset = start ~/ 3;
        final clips = group.value.skip(start).take(3).toList(growable: false);
        rows.add((context) => Padding(
              key: ValueKey('clip_row_${clips.first.id}'),
              padding: const EdgeInsets.only(bottom: ClipGrid.cellGap),
              child: ClipGrid<MotionClip>(
                  items: clips,
                  rowOffset: rowOffset,
                  totalItems: group.value.length,
                  cellBuilder: (clip) => GestureDetector(
                        key: ValueKey('crecam_clip_${clip.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/crecam/player/${clip.id}',
                            extra: ClipPlaylistArgs(
                                playlist: playlist,
                                source: ClipPlaybackSource.feed,
                                cameraId: clip.cameraId,
                                rangeStart: key.range?.start,
                                rangeEndExclusive: key.range?.endExclusive,
                                nextCursor: state.nextCursor,
                                hasMore: state.hasMore)),
                        child: Stack(fit: StackFit.expand, children: [
                          MotionClipThumb(
                              clipId: clip.id,
                              cameraId: clip.cameraId,
                              thumbnailVersion: clip.thumbnailKey ?? 'original',
                              fallbackIcon: Icons.videocam_rounded,
                              fallbackColor: context.glass.overlayFaint),
                          Positioned(
                              left: 0,
                              bottom: 0,
                              child: FavoriteBookmarkBadge(clipId: clip.id)),
                        ]),
                      )),
            ));
      }
    }
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      if (index < rows.length) return rows[index](context);
      if (state.pageError != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CrecamErrorRetry(
              onRetry: () => state.nextCursor == null
                  ? controller.refresh()
                  : controller.loadMore()),
        );
      }
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: state.loadingMore || state.refreshing
              ? const SkeletonLoading(width: double.infinity, height: 32)
              : const SizedBox(height: 16));
    }, childCount: rows.length + 1));
  }
}

/// A live renderer must survive being scrolled out of the lazy viewport.
class KeepAliveCameraHeader extends StatefulWidget {
  const KeepAliveCameraHeader({super.key, required this.child});
  final Widget child;
  @override
  State<KeepAliveCameraHeader> createState() => _KeepAliveCameraHeaderState();
}

class _KeepAliveCameraHeaderState extends State<KeepAliveCameraHeader>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
