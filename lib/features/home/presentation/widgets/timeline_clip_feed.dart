import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/clip_action.dart';
import '../../../my_cage/domain/motion_clip.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../home_timeline_providers.dart';

/// 상단 Top Fixed 영역에서 인라인 재생할 클립. null = 라이브 표시.
///
/// PRD §3.5: "썸네일 터치 시 상단 Top Fixed Live 비디오 영역에서 해당 녹화
/// 클립 즉시 재생" — 새 화면으로 이동하지 않는다.
final inlinePlayingClipProvider = StateProvider<MotionClip?>((ref) => null);

/// `03m 20s` 형식. PRD §3.5 목업 표기.
String formatClipDuration(double seconds) {
  final total = seconds.round();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '${m}m ${s}s';
}

/// PRD §3.5 비디오 클립 피드 (List View).
class TimelineClipFeed extends ConsumerWidget {
  const TimelineClipFeed({super.key});

  static const emptyKey = Key('timeline_clip_feed_empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips =
        ref.watch(filteredTimelineClipsProvider).valueOrNull ?? const [];
    if (clips.isEmpty) {
      return Padding(
        key: emptyKey,
        padding: AppStyles.pagePadding,
        child: Center(child: Text('home_timeline_empty'.tr())),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clips.length,
      itemBuilder: (_, i) => ClipFeedRow(clip: clips[i]),
    );
  }
}

/// 클립 한 줄 — 썸네일 · 시각 · 이벤트명 · 녹화 길이.
class ClipFeedRow extends ConsumerWidget {
  const ClipFeedRow({super.key, required this.clip});

  final MotionClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(motionThumbnailProvider(clip.id)).valueOrNull;
    final label = clip.action == null
        ? 'clip_action_unlabeled'.tr()
        : clipActionKey(clip.action!).tr();

    return ListTile(
      onTap: () => ref.read(inlinePlayingClipProvider.notifier).state = clip,
      leading: SizedBox(
        width: 64,
        height: 40,
        child: thumb == null
            ? Container(color: Theme.of(context).dividerColor)
            : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
      ),
      title: Text('$label (${formatClipDuration(clip.durationSec)})'),
      subtitle: Text(DateFormat('HH:mm:ss').format(clip.startedAt)),
    );
  }
}
