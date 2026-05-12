import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_tag.dart';
import '../../domain/clip.dart';
import 'clip_thumbnail.dart';

class ClipCard extends ConsumerWidget {
  const ClipCard({super.key, required this.clip, required this.onTap});

  final Clip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipThumbnail(clip: clip),
            ),

            // 하단 메타
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (clip.hasMotion) ...[
                    AppTag(
                      label: 'clip_motion_badge'.tr(),
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    durationLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
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
