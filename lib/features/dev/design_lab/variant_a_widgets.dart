/// A안 공용 유리 조각 — 홈/통계/마이크레/커뮤니티 4탭이 같은 문법을 쓴다.
/// `AppTheme` 참조 금지(랩 격리) — [VariantATokens]만 쓴다.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens/variant_a_tokens.dart';

/// 배경 월페이퍼 — 딥 그라데이션 + 은은한 빛 번짐.
/// 유리가 "받쳐 보일" 바닥 콘텐츠라 탭마다 깔아 준다.
class AWallpaper extends StatelessWidget {
  const AWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VariantATokens.wallpaperTop,
            VariantATokens.wallpaperMid,
            VariantATokens.wallpaperBottom,
          ],
        ),
      ),
      child: CustomPaint(painter: _GlowPainter()),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.8, size.height * 0.25),
        size.width * 0.7,
        [const Color(0x2E4FD8C4), const Color(0x004FD8C4)],
      );
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.25),
        size.width * 0.7, glow);

    final glow2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6,
        [const Color(0x244AA8FF), const Color(0x004AA8FF)],
      );
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6, glow2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 유리 타일 공통 — 흰 오버레이 + 얇은 테두리(+선택적 blur).
class AGlass extends StatelessWidget {
  const AGlass({
    super.key,
    required this.child,
    this.radius = VariantATokens.tileRadius,
    this.overlay = VariantATokens.glassOverlay,
    this.padding = EdgeInsets.zero,
    this.blur = false,
  });

  final Widget child;
  final double radius;
  final Color overlay;
  final EdgeInsetsGeometry padding;

  /// BackdropFilter blur를 깔지. **기본 false** — 배경이 정적 그라데이션이라
  /// 반투명 플랫 필과 시각 차이가 미미한데, BackdropFilter는 조각 수만큼
  /// saveLayer를 쌓아 스크롤 프레임을 잡아먹는다(프로덕션 GlassCard와 같은
  /// 결론). 뒤로 실제 콘텐츠가 지나가는 표면(셸의 독)만 true를 준다.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: overlay,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: VariantATokens.glassBorder, width: 0.5),
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: VariantATokens.blurSigma,
                sigmaY: VariantATokens.blurSigma,
              ),
              child: body,
            )
          : body,
    );
  }
}

/// 유리 캡슐(알약) — 칩·배지·드롭다운 헤더용.
class AGlassCapsule extends StatelessWidget {
  const AGlassCapsule({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AGlass(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: child,
    );
  }
}

/// 유리 세그먼트 컨트롤 — 캡슐 안에서 활성 칸만 흰 필이 뜬다.
///
/// [disabledFrom] 이후 인덱스는 흐리게 그리고 탭을 막는다('준비 중' 문법).
class AGlassSegment extends StatelessWidget {
  const AGlassSegment({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.disabledFrom,
    this.disabledHint,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// 이 인덱스부터는 비활성(흐림). null이면 전부 활성.
  final int? disabledFrom;

  /// 비활성 칸 아래에 붙는 작은 안내('준비 중').
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return AGlass(
      radius: 100,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(child: _segment(i)),
        ],
      ),
    );
  }

  Widget _segment(int i) {
    final disabled = disabledFrom != null && i >= disabledFrom!;
    final active = i == selected && !disabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onSelected(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? VariantATokens.activeTile : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? VariantATokens.textOnActive
                      : VariantATokens.textPrimary,
                ),
              ),
              if (disabled && disabledHint != null)
                Text(
                  disabledHint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: VariantATokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션 라벨 — 홈 '액세서리'와 같은 문법.
class ASectionLabel extends StatelessWidget {
  const ASectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: VariantATokens.sectionLabel),
    );
  }
}
