import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_tag.dart';
import '../../domain/clip_action.dart';
import '../../domain/motion_clip.dart';

/// 모션 클립 그리드 카드. 썸네일 엔드포인트 미확정이라 아이콘 placeholder.
/// (후속: thumbnail_key presigned 확정 시 상단 영역 교체.)
/// (후속: 분류 태그 확정 시 하단 Row에 태그 칩 추가.)
class MotionClipCard extends StatelessWidget {
  const MotionClipCard({super.key, required this.clip, required this.onTap});

  final MotionClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());
    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_outline,
                  color: cs.onSurface.withValues(alpha: 0.35),
                  size: 40,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(timeLabel,
                        style: theme.textTheme.bodySmall),
                  ),
                  AppTag(
                    label: clip.action == null
                        ? 'clip_action_unlabeled'.tr()
                        : clipActionKey(clip.action!).tr(),
                    color: clip.action == null
                        ? cs.outline
                        : cs.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    durationLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
