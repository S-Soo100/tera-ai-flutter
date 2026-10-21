import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/am_pm_time.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip_playlist_args.dart';
import '../../domain/motion_clip.dart';
import '../../domain/motion_clip_page.dart';
import '../../domain/recording_item.dart';
import '../clip_feed_controller.dart';
import '../clip_selection_providers.dart';
import 'clip_selection_widgets.dart';
import 'clip_grid.dart';
import 'crecam_states.dart';
import 'favorite_bookmark_badge.dart';
import 'motion_clip_thumb.dart';
import 'player_entry_thumb.dart';
import 'recording_badges.dart';

/// Flatten into hour headers and three-cell rows, so an hour with hundreds of
/// clips is still built one visible row at a time.
///
/// 칸은 일반 영상과 그 카메라의 직접 녹화([clipFeedEntriesProvider], 2026-10-21)
/// — 녹화 칸은 "직접 녹화 · 0:42" 배지, 올리는 중이면 흐리게·누를 수 없음
/// (재생목록·묶음 체크·꾹 눌러 끌기에서도 건너뛴다).
class ClipFeedSlivers extends ConsumerWidget {
  const ClipFeedSlivers({super.key, required this.query});
  final ClipFeedQuery? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = query;
    if (key == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final state = ref.watch(clipFeedProvider(key));
    final controller = ref.read(clipFeedProvider(key).notifier);
    final entries = ref.watch(clipFeedEntriesProvider(key));
    if (entries.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: state.initialLoading
            ? const SkeletonLoading(width: double.infinity, height: 120)
            : state.pageError != null
                ? CrecamErrorRetry(onRetry: controller.refresh)
                : Center(
                    child: Text(
                        // 정책 v2: 통과분만 보이므로 빈 이유를 밝힌다.
                        // empty_day는 북마크·하이라이트가 공유해 따로 둔다.
                        (key.range == null
                                ? 'crecam_home_empty_all'
                                : 'crecam_home_empty_range')
                            .tr(),
                        style: TextStyle(color: context.glass.textTertiary))),
      ));
    }
    final groups = <DateTime, List<FeedEntry>>{};
    for (final entry in entries) {
      final time = entry.startedAt.toLocal();
      final hour = DateTime(time.year, time.month, time.day, time.hour);
      groups.putIfAbsent(hour, () => []).add(entry);
    }
    // 시간 헤더는 피드를 읽기 쉽게 나누는 시각적 그룹이다. 플레이어는
    // 현재 카메라·현재 기간의 전체 피드를 사진 앱처럼 하나로 탐색한다
    // (직접 녹화 포함, 올리는 중인 녹화 제외).
    final playlist = [
      for (final e in entries)
        if (feedEntrySelectable(e)) e.key
    ];
    // 불러온 가장 오래된 일반 영상 — 플레이어가 다음 페이지에 녹화를 끼우는 경계.
    final floor = state.items.isEmpty ? null : state.items.last.startedAt;
    final rows = <WidgetBuilder>[];
    DateTime? previousDate;
    for (final group in groups.entries) {
      final date = DateTime(group.key.year, group.key.month, group.key.day);
      final label =
          previousDate != date ? DateFormat('yyyy. M. d').format(date) : null;
      previousDate = date;
      final firstGroup = rows.isEmpty;
      final groupIds = [
        for (final e in group.value)
          if (feedEntrySelectable(e)) e.key
      ];
      rows.add((context) => Padding(
            key: ValueKey('clip_hour_${group.key.toIso8601String()}'),
            padding: EdgeInsets.only(top: firstGroup ? 0 : 16, bottom: 8),
            child: Row(children: [
              Expanded(
                  child: Text(formatAmPmTime(group.key),
                      style: TextStyle(
                          fontSize: 16,
                          height: 19 / 16,
                          letterSpacing: -.32,
                          fontWeight: FontWeight.w600,
                          color: context.glass.textSecondary))),
              if (label != null)
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        height: 17 / 14,
                        letterSpacing: -.28,
                        fontWeight: FontWeight.w600,
                        color: context.glass.textTertiary)),
              // Figma 1497:13355 — 선택 모드엔 날짜 오른쪽에 시간 묶음 전체 선택.
              ClipSelectGroupCheck(
                  key: ValueKey(
                      'clip_group_check_${group.key.toIso8601String()}'),
                  scope: ClipSelectionScope.feed,
                  ids: groupIds),
            ]),
          ));
      for (var start = 0; start < group.value.length; start += 3) {
        final rowOffset = start ~/ 3;
        final hasNextRow = start + 3 < group.value.length;
        final clips = group.value.skip(start).take(3).toList(growable: false);
        rows.add((context) => Padding(
              key: ValueKey('clip_row_${clips.first.key}'),
              padding:
                  EdgeInsets.only(bottom: hasNextRow ? ClipGrid.cellGap : 0),
              child: ClipGrid<FeedEntry>(
                  items: clips,
                  rowOffset: rowOffset,
                  totalItems: group.value.length,
                  cellBuilder: (entry) {
                    void open() => context.push(
                        '/crecam/player/${Uri.encodeComponent(entry.key)}',
                        extra: ClipPlaylistArgs(
                            playlist: playlist,
                            source: ClipPlaybackSource.feed,
                            cameraId: key.cameraId,
                            rangeStart: key.range?.start,
                            rangeEndExclusive: key.range?.endExclusive,
                            nextCursor: state.nextCursor,
                            hasMore: state.hasMore,
                            feedFloor: floor));
                    final MotionClip clip;
                    switch (entry) {
                      case RecordingFeedEntry(:final item):
                        return RecordingFeedCell(item: item, onOpen: open);
                      case ClipFeedEntry(clip: final c):
                        clip = c;
                    }
                    // 선택 모드에선 탭 = 고르기, 영상 보기는 확대 버튼.
                    return ClipSelectableThumb(
                        key: ValueKey('crecam_clip_${clip.id}'),
                        scope: ClipSelectionScope.feed,
                        clipId: clip.id,
                        onOpen: open,
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
                        ]));
                  }),
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

/// 카메라 탭 3열 칸의 직접 녹화 — 썸네일 + 왼쪽 아래 "직접 녹화 · 0:42"(보관함
/// 카드 배지의 작은 판) + 업로드 상태(왼쪽 위, 대기·실패도 표시만). 올리는
/// 중이면 흐리게·누를 수 없음 — 선택 표지([ClipDragCell])도 달지 않아 꾹
/// 눌러 끌기·묶음 체크가 건너뛴다.
class RecordingFeedCell extends StatelessWidget {
  const RecordingFeedCell(
      {super.key, required this.item, required this.onOpen});

  final RecordingItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = recordingUploadLabelKey(item.uploadBadge);
    final face = Stack(fit: StackFit.expand, children: [
      RecordingItemThumb(
          item: item,
          fallback: ClipThumbFallback(
              icon: Icons.videocam_rounded,
              color: context.glass.overlayFaint)),
      Positioned(
          left: 4,
          right: 36,
          bottom: 4,
          child: Align(
              alignment: Alignment.bottomLeft,
              child: RecordingChip(recordingLengthLabel(item.duration),
                  compact: true))),
      if (label != null)
        Positioned(
            left: 4,
            top: 4,
            right: 36,
            child: Align(
                alignment: Alignment.topLeft,
                child: RecordingChip(label.tr(),
                    compact: true,
                    key: ValueKey('crecam_rec_upload_${item.key}')))),
    ]);
    if (item.uploading) {
      return IgnorePointer(
          key: ValueKey('crecam_rec_${item.key}'),
          child: Opacity(opacity: kRecordingUploadingOpacity, child: face));
    }
    return ClipSelectableThumb(
        key: ValueKey('crecam_rec_${item.key}'),
        scope: ClipSelectionScope.feed,
        clipId: item.key,
        onOpen: onOpen,
        child: face);
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
