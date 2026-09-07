import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_palette.dart';

/// 솔리드 카드. 디자인 시스템 `Components / GlassCard`.
///
/// 이름의 "Glass"는 1차(Liquid Glass, 2026-08-13) 때의 역사적 명칭이다.
/// A안 2차(2026-08-14)부터 **불투명 솔리드 표면** + 아주 얇은 저대비 테두리,
/// B안(2026-08-14 저녁)부터는 radius 16·그림자 없음·divider 톤 테두리다.
/// blur·반투명 오버레이는 없다 — [WallpaperBackground](정적 단색) 위에 올린다.
///
/// 색은 전부 [GlassPalette] 토큰이다(`context.glass`) — 다크/라이트가 값만
/// 다르다. 화면별로 색을 새로 만들지 말 것.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppTheme.glassTileRadius,
    this.overlay,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    @Deprecated('솔리드 전환(2026-08-14)으로 blur 없음 — 넘겨도 무시된다') this.blur = false,
  });

  final Widget child;

  /// 모서리. 기본은 타일 radius(16, B `cardRadius`). 배지처럼 작은 조각은 8~12를 준다.
  final double radius;

  /// 표면색. null이면 [GlassPalette.overlay],
  /// 독·시트처럼 또렷해야 하는 곳은 [GlassPalette.overlayStrong]을 넘긴다.
  final Color? overlay;

  final EdgeInsetsGeometry padding;

  /// 주면 InkWell로 감싼다 — 카드 전체가 탭 대상이 된다.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 호환용 no-op. 1차에서 BackdropFilter를 켜던 스위치였고 2차에서 경로가
  /// 제거됐다. 호출부(독)가 아직 넘기므로 파라미터만 남겼다.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final glass = context.glass;
    final overlay = this.overlay ?? glass.overlay;

    final Widget body;
    if (onTap == null && onLongPress == null) {
      body = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: overlay,
          borderRadius: borderRadius,
          border: Border.all(color: glass.border, width: 0.5),
        ),
        // 안에 InkWell을 두는 카드(독·서브탭·세그먼트)의 리플이 앉을 면.
        // 이게 없으면 잉크가 카드 뒤 불투명 바닥에 그려져 안 보인다.
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
              border: Border.all(color: glass.border, width: 0.5),
            ),
            child: child,
          ),
        ),
      );
    }

    return ClipRRect(borderRadius: borderRadius, child: body);
  }
}
