import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// 캡슐 칩. 디자인 시스템 `Components / GlassChip` (A안 — 이름은 역사적,
/// 2차부터 솔리드 표면).
///
/// [GlassCard]의 캡슐(radius 100) 변형 — 세트 드롭다운, 센서 요약,
/// 세그먼트 트랙처럼 **한 줄짜리 알약** 자리에 쓴다.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    this.overlay = AppTheme.glassOverlay,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 표면색. [GlassCard.overlay]와 같은 규칙.
  final Color overlay;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 100,
      overlay: overlay,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}
