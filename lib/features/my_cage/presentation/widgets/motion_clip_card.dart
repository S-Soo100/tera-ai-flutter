import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip_action.dart';
import '../../domain/motion_clip.dart';
import '../my_cage_providers.dart';

/// 모션 클립 그리드 카드. 상단은 서버 presigned 썸네일(로딩=스켈레톤, 실패=아이콘).
/// (후속: 분류 태그 확정 시 하단 Row에 태그 칩 — clip.action 이미 반영됨.)
class MotionClipCard extends ConsumerWidget {
  const MotionClipCard({super.key, required this.clip, required this.onTap});

  final MotionClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());
    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );
    final thumbAsync = ref.watch(motionThumbnailProvider(clip.id));

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbAsync.when(
                data: (url) => url != null
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => const SkeletonLoading(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0),
                        errorWidget: (_, __, ___) => _placeholder(cs),
                      )
                    : _placeholder(cs),
                loading: () => const SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0),
                error: (_, __) => _placeholder(cs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(timeLabel, style: theme.textTheme.bodySmall),
                  ),
                  AppTag(
                    label: clip.action == null
                        ? 'clip_action_unlabeled'.tr()
                        : clipActionKey(clip.action!).tr(),
                    color: clip.action == null ? cs.outline : cs.secondary,
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

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.play_circle_outline,
          color: cs.onSurface.withValues(alpha: 0.35), size: 40),
    );
  }
}
