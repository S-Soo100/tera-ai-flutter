/// A안 공용 유리 조각 — 홈/통계/마이크레/커뮤니티 4탭이 같은 문법을 쓴다.
/// `AppTheme` 참조 금지(랩 격리) — [VariantATokens]만 쓴다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens/variant_a_tokens.dart';

/// 하단 플로팅 독 여유(px) — 리스트 마지막 항목이 셸의 독에 가려지지 않게
/// 스크롤 끝에 남겨 두는 높이. 4탭이 같은 값을 쓴다.
const double aDockClearance = 120;

/// A안 탭 화면 공통 프레임 — 월페이퍼 + `SafeArea(bottom: false)` +
/// ListView(가로 [VariantATokens.screenHPad], 하단 [aDockClearance]).
///
/// 홈은 CustomScrollView(슬리버 핀 헤더)라 이 프레임을 못 쓰고
/// [aDockClearance]만 공유한다.
class AScreenScaffold extends StatelessWidget {
  const AScreenScaffold({super.key, this.title, required this.children});

  /// 대형 헤더 타이틀. null이면 타이틀 없이 children부터 시작.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantATokens.wallpaperTop,
      body: Stack(
        children: [
          const Positioned.fill(child: AWallpaper()),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                VariantATokens.screenHPad,
                12,
                VariantATokens.screenHPad,
                aDockClearance,
              ),
              children: [
                if (title != null) ...[
                  Text(title!, style: VariantATokens.headerTitle),
                  const SizedBox(height: 16),
                ],
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.25), size.width * 0.7, glow);

    final glow2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6,
        [const Color(0x244AA8FF), const Color(0x004AA8FF)],
      );
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.7), size.width * 0.6, glow2);
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
          for (var i = 0; i < labels.length; i++) Expanded(child: _segment(i)),
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

/// 값 목록을 자체 min~max로 정규화한 폴리라인 경로.
///
/// 홈 미니 차트·통계 일간 차트가 같은 수식을 쓴다 — 복사해 두면 한쪽만
/// 고쳐진 채 남는다. [inset]은 위아래 여백 비율(0~0.5): 곡선이 카드
/// 모서리에 닿지 않게 세로 범위를 `inset ~ 1-inset`으로 좁힌다.
Path aPolylinePath(Size size, List<double> values, {double inset = 0}) {
  final min = values.reduce(math.min);
  final max = values.reduce(math.max);
  final span = (max - min) == 0 ? 1 : max - min;

  final path = Path();
  for (var i = 0; i < values.length; i++) {
    final x = size.width * i / (values.length - 1);
    final y = size.height *
        (inset + (1 - 2 * inset) * (1 - (values[i] - min) / span));
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path;
}

/// 차트 가로 격자선 — 유리 테두리 색의 얇은 선을 고른 간격으로 [rows]+1개.
void aChartGrid(Canvas canvas, Size size, {int rows = 3}) {
  final paint = Paint()
    ..color = VariantATokens.glassBorder
    ..strokeWidth = 0.5;
  for (var i = 0; i <= rows; i++) {
    final y = size.height * i / rows;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}
