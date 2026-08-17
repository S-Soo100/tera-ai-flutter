import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 화면 바닥. 디자인 시스템 `Components / WallpaperBackground`.
///
/// A안 2차(2026-08-14, 솔리드)부터는 **정적 단색**이다 — 그라데이션·glow는
/// 유리가 "비쳐 보일" 거리를 만들려고 있었고, 유리를 걷어낸 지금은 차분한
/// 단색 바닥이 표면([GlassCard] 등)을 가장 또렷하게 받쳐 준다.
/// 이름의 "Wallpaper"는 1차(Liquid Glass) 때의 역사적 명칭이다.
///
/// 쓰는 법: 화면 `Stack` 맨 아래에 `Positioned.fill`로 깐다.
/// ```dart
/// Stack(children: [
///   const Positioned.fill(child: WallpaperBackground()),
///   ...콘텐츠,
/// ])
/// ```
class WallpaperBackground extends StatelessWidget {
  const WallpaperBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.glassWallpaperTop,
      child: child,
    );
  }
}
