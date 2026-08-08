import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../my_cage/domain/clip_action.dart';
import '../../../my_cage/domain/motion_clip.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../home_timeline_providers.dart';

/// `03m 20s` 형식. PRD §3.5 목업 표기.
String formatClipDuration(double seconds) {
  final total = seconds.round();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '${m}m ${s}s';
}

/// PRD §3.5 비디오 클립 피드.
///
/// **sliver를 반환한다** — `CustomScrollView`의 slivers에 넣어야 한다.
/// 예전엔 `shrinkWrap: true` ListView였는데, shrinkWrap은 높이를 재려고
/// 전체 항목을 즉시 레이아웃한다. 클립이 200건이면 [ClipFeedRow] 200개가
/// 한꺼번에 만들어지고 각자 presigned 썸네일 URL을 요청해 진입 즉시 수백 건의
/// 네트워크 호출이 터진다. SliverList는 보이는 만큼만 만든다.
class TimelineClipFeed extends ConsumerWidget {
  const TimelineClipFeed({super.key});

  static const emptyKey = Key('timeline_clip_feed_empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips =
        ref.watch(filteredTimelineClipsProvider).valueOrNull ?? const [];
    if (clips.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          key: emptyKey,
          padding: AppStyles.pagePadding,
          child: EmptyState(
            title: 'home_timeline_empty_title'.tr(),
            description: 'home_timeline_empty_desc'.tr(),
          ),
        ),
      );
    }
    return SliverList.builder(
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
      // 상단 라이브 영역에서 인라인 재생하지 않는다. 그 영역은 16:9 한 조각이라
      // 영상이 손톱만 하게 보이고, 저장·공유·즐겨찾기·시크가 전부 빠진
      // 반쪽짜리 플레이어를 따로 유지해야 했다. 전체화면 가로 플레이어로 보낸다.
      onTap: () => context.push('/crecam/motion-clips/${clip.id}'),
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
