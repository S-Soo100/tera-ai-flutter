import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/clip.dart';
import 'clip_thumbnail.dart';

/// 3열 그리드용 클립 카드.
///
/// - 16:9 AspectRatio 썸네일
/// - 우상단: "HH:mm" 오버레이 (검정 반투명 배경)
/// - 좌상단: hasMotion이면 주황 8px dot
class ClipGridCard extends ConsumerWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onTap,
  });

  final Clip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeLabel = DateFormat('HH:mm').format(clip.startedAt.toLocal());

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipThumbnail(clip: clip),

              // 시간 오버레이 (우상단)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // 움직임 dot (좌상단)
              if (clip.hasMotion)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
