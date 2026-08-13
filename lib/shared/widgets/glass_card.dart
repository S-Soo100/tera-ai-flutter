import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 유리 카드. 디자인 시스템 `Components / GlassCard` (A안 Liquid Glass).
///
/// blur + 흰 오버레이 + 얇은 테두리. **[WallpaperBackground] 같은 어두운 바닥
/// 위에 올린다** — 밝은 면 위에서는 흰 오버레이가 묻혀 유리로 안 읽힌다.
///
/// 색은 전부 `AppTheme` 글래스 토큰이다. 화면별로 색을 새로 만들지 말 것.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppTheme.glassTileRadius,
    this.overlay = AppTheme.glassOverlay,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;

  /// 모서리. 기본은 타일 radius(26). 배지처럼 작은 조각은 8~18을 준다.
  final double radius;

  /// 유리 농도. 기본 ~14%([AppTheme.glassOverlay]),
  /// 독·시트처럼 또렷해야 하는 곳은 [AppTheme.glassOverlayStrong].
  final Color overlay;

  final EdgeInsetsGeometry padding;

  /// 주면 InkWell로 감싼다 — 카드 전체가 탭 대상이 된다.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final Widget body;
    if (onTap == null && onLongPress == null) {
      body = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: overlay,
          borderRadius: borderRadius,
          border: Border.all(color: AppTheme.glassBorder, width: 0.5),
        ),
        // 안에 InkWell을 두는 카드(독·서브탭·세그먼트)의 리플이 앉을 면.
        // 이게 없으면 잉크가 카드 뒤 불투명 월페이퍼에 그려져 안 보인다.
        child: Material(type: MaterialType.transparency, child: child),
      );
    } else {
      body = Material(
        color: overlay,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: AppTheme.glassBorder, width: 0.5),
            ),
            child: child,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: AppTheme.glassBlurSigma,
          sigmaY: AppTheme.glassBlurSigma,
        ),
        child: body,
      ),
    );
  }
}
