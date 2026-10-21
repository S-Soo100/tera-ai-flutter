import 'package:flutter/painting.dart';

import '../../core/theme/glass_palette.dart';

/// Figma 떠 있는 면(토스트·더보기 메뉴·확인 모달·헤더 드롭다운)의 공통 그림자 —
/// Drop shadow X0 Y0 Blur 20 #919497 30%(`menuShadow`).
///
/// Figma blur는 가우시안 표준편차의 2배(σ = 10)이고 Flutter `blurRadius`는
/// σ = r × 0.57735 + 0.5로 바뀌므로 σ 10 ↔ r ≈ 16.45. Material `elevation`은
/// 아래로 치우친 검은 그림자라 원본과 다르다 — 쓰지 말 것.
const double kVivaFloatingShadowBlur = 16.45;

BoxShadow vivaFloatingShadow(GlassPalette glass) =>
    BoxShadow(color: glass.menuShadow, blurRadius: kVivaFloatingShadowBlur);

/// 그림자를 직접 그리는 둥근 사각 테두리 — 면을 직접 꾸밀 수 없는
/// `PopupMenuButton`(헤더 드롭다운) 메뉴에 쓴다. `elevation: 0`과 함께 쓸 것.
///
/// Material은 테두리를 내용 **위**에 그리므로 그림자는 면 바깥에만 칠한다
/// (안쪽까지 칠하면 메뉴 글자 위로 그림자색이 덮인다).
class VivaShadowRoundedBorder extends RoundedRectangleBorder {
  const VivaShadowRoundedBorder(
      {required this.shadow, super.borderRadius, super.side});

  final BoxShadow shadow;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    final reach = shadow.blurSigma * 3 +
        shadow.spreadRadius.abs() +
        shadow.offset.distance;
    canvas
      ..save()
      ..clipPath(Path.combine(PathOperation.difference,
          Path()..addRect(rect.inflate(reach)), Path()..addRRect(rrect)))
      ..drawRRect(rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
          shadow.toPaint())
      ..restore();
    super.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) =>
      other is VivaShadowRoundedBorder &&
      other.shadow == shadow &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, shadow);
}
