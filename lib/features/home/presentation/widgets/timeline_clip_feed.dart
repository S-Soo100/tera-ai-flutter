import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../my_cage/domain/clip_action.dart';
import '../../../my_cage/domain/motion_clip.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../../domain/day_window.dart';
import '../home_timeline_providers.dart';

/// `03m 20s` 형식. PRD §3.5 목업 표기.
String formatClipDuration(double seconds) {
  final total = seconds.round();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '${m}m ${s}s';
}

/// PRD §3.5 비디오 클립 피드 — B안 **수직 스텝 타임라인**(2026-08-18).
///
/// 체크인→탑승→이륙 문법: 왼쪽에 도트와 연결선, 오른쪽에 내용. 지나간 클립은
/// **그린 도트 + 실선**, 아직 오지 않은 것(오늘의 "아침 리포트")은 **회색
/// 빈 도트 + 점선**. 목록은 최신이 위(원 데이터 순서 그대로)라 미도래
/// 스텝이 맨 위에 선다.
///
/// **sliver를 반환한다** — `CustomScrollView`의 slivers에 넣어야 한다.
/// 예전엔 `shrinkWrap: true` ListView였는데, shrinkWrap은 높이를 재려고
/// 전체 항목을 즉시 레이아웃한다. 클립이 200건이면 [ClipFeedRow] 200개가
/// 한꺼번에 만들어지고 각자 presigned 썸네일 URL을 요청해 진입 즉시 수백 건의
/// 네트워크 호출이 터진다. SliverList는 보이는 만큼만 만든다.
///
/// 데이터·클립 재생 진입(`/crecam/motion-clips/:id`)은 A안과 같다.
class TimelineClipFeed extends ConsumerWidget {
  const TimelineClipFeed({super.key});

  static const emptyKey = Key('timeline_clip_feed_empty');
  static const pendingKey = Key('timeline_pending_step');

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

    // 오늘을 보고 있으면 맨 위에 "아침 리포트 07:00" 미도래 스텝을 둔다 —
    // 밤 기록이 어디로 모이는지(마이크레 리포트)와 언제 나오는지를 밝힌다.
    final date = ref.watch(timelineDateProvider);
    final window = DayWindow.forDate(date);
    final isToday = date == DayWindow.of(DateTime.now()).labelDate;
    final lead = isToday ? 1 : 0;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        0,
      ),
      sliver: SliverList.builder(
        itemCount: clips.length + lead,
        itemBuilder: (_, i) {
          if (lead == 1 && i == 0) {
            return _PendingStepRow(
              key: pendingKey,
              at: window.end,
              // 아래에 클립이 있으니 연결선은 있되 **점선** — 아직 안 온 구간.
              isLast: clips.isEmpty,
            );
          }
          final idx = i - lead;
          return ClipFeedRow(
            clip: clips[idx],
            isLast: idx == clips.length - 1,
          );
        },
      ),
    );
  }
}

/// 클립 한 줄 — 그린 도트 · 썸네일 · 이벤트명 · 녹화 길이 · 시각.
class ClipFeedRow extends ConsumerWidget {
  const ClipFeedRow({super.key, required this.clip, this.isLast = true});

  final MotionClip clip;

  /// 마지막 스텝이면 아래 연결선을 그리지 않는다.
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final thumb = ref.watch(motionThumbnailProvider(clip.id)).valueOrNull;
    final label = clip.action == null
        ? 'clip_action_unlabeled'.tr()
        : clipActionKey(clip.action!).tr();

    return _StepRow(
      done: true,
      isLast: isLast,
      // 아래 스텝은 항상 지나간 클립 — 실선.
      nextDone: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // 상단 라이브 영역에서 인라인 재생하지 않는다. 그 영역은 4:3 한 조각이라
        // 영상이 손톱만 하게 보이고, 저장·공유·즐겨찾기·시크가 전부 빠진
        // 반쪽짜리 플레이어를 따로 유지해야 했다. 전체화면 가로 플레이어로 보낸다.
        onTap: () => context.push('/crecam/motion-clips/${clip.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 40,
                  child: thumb == null
                      ? ColoredBox(color: glass.overlayFaint)
                      : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: AppStyles.spacing12),
              Expanded(
                child: Text(
                  '$label (${formatClipDuration(clip.durationSec)})',
                  style: glass.tileTitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppStyles.spacing8),
              Text(
                DateFormat('HH:mm:ss').format(clip.startedAt),
                style: glass.tileStatus.copyWith(
                  color: glass.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 미도래 스텝 — 오늘 창의 끝(익일 07:00)에 나올 아침 리포트.
class _PendingStepRow extends StatelessWidget {
  const _PendingStepRow({super.key, required this.at, required this.isLast});

  final DateTime at;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return _StepRow(
      done: false,
      isLast: isLast,
      nextDone: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'home_timeline_pending_report'.tr(),
                  style: glass.tileTitle
                      .copyWith(fontSize: 14, color: glass.textSecondary),
                ),
              ),
              Text(
                DateFormat('HH:mm').format(at),
                style: glass.tileStatus.copyWith(
                  color: glass.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스텝 한 줄의 골격 — 왼쪽 도트·연결선 + 오른쪽 내용.
///
/// [done]이면 그린 채움 도트, 아니면 회색 빈 도트. 연결선은 **다음 스텝**이
/// 지나간 것이면 실선, 아니면 점선 — 선은 두 스텝 사이 구간의 상태다.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.isLast,
    required this.nextDone,
    required this.child,
  });

  final bool done;
  final bool isLast;
  final bool nextDone;
  final Widget child;

  static const double _dot = 10;
  static const double _gutter = 12;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final dotColor = done ? glass.signalOk : glass.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _dot,
            child: Column(
              children: [
                Container(
                  width: _dot,
                  height: _dot,
                  margin: const EdgeInsets.only(top: 19),
                  decoration: BoxDecoration(
                    color: done ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: nextDone
                          ? Container(width: 2, color: glass.signalOk)
                          : CustomPaint(
                              size: const Size(2, double.infinity),
                              painter: _DashedLinePainter(
                                  color: glass.textTertiary),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: _gutter),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppStyles.spacing8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 4.0;
    const gap = 4.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}
