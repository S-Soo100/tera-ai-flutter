import 'package:flutter/painting.dart';

import '../../core/theme/glass_palette.dart';

/// Figma 떠 있는 면(토스트·더보기 메뉴·확인 모달)의 공통 그림자 —
/// Drop shadow X0 Y0 Blur 20 #919497 30%(`menuShadow`).
///
/// Figma blur는 가우시안 표준편차의 2배(σ = 10)이고 Flutter `blurRadius`는
/// σ = r × 0.57735 + 0.5로 바뀌므로 σ 10 ↔ r ≈ 16.45. Material `elevation`은
/// 아래로 치우친 검은 그림자라 원본과 다르다 — 쓰지 말 것.
const double kVivaFloatingShadowBlur = 16.45;

BoxShadow vivaFloatingShadow(GlassPalette glass) =>
    BoxShadow(color: glass.menuShadow, blurRadius: kVivaFloatingShadowBlur);
