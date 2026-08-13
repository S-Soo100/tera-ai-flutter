import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Liquid Glass 월페이퍼. 디자인 시스템 `Components / WallpaperBackground`.
///
/// A안(Apple Home) 문법의 **바닥 레이어**다 — 유리([GlassCard] 등)는 반투명이라
/// 받쳐줄 콘텐츠가 없으면 그냥 회색 판이 된다. 은은한 빛 번짐(glow)을 함께
/// 그려 유리가 "비쳐 보일" 거리를 만든다.
///
/// 쓰는 법: 화면 `Stack` 맨 아래에 `Positioned.fill`로 깐다.
/// ```dart
/// Stack(children: [
///   const Positioned.fill(child: WallpaperBackground()),
///   ...유리 콘텐츠,
/// ])
/// ```
class WallpaperBackground extends StatelessWidget {
  const WallpaperBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.glassWallpaperTop,
            AppTheme.glassWallpaperMid,
            AppTheme.glassWallpaperBottom,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GlowPainter(),
        child: child,
      ),
    );
  }
}

/// 은은한 빛 번짐 — 유리가 받쳐 보일 바닥 콘텐츠.
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.8, size.height * 0.25),
        size.width * 0.7,
        [
          AppTheme.deviceFanTint.withValues(alpha: 0.18),
          AppTheme.deviceFanTint.withValues(alpha: 0),
        ],
      );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.25),
      size.width * 0.7,
      glow,
    );

    final glow2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6,
        [
          AppTheme.deviceMistTint.withValues(alpha: 0.14),
          AppTheme.deviceMistTint.withValues(alpha: 0),
        ],
      );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      size.width * 0.6,
      glow2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
