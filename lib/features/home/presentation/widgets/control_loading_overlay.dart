import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/glass_palette.dart';

/// 제어 명령을 기기가 확인할 때까지 컨트롤 위에 흘리는 shimmer.
///
/// 문구를 바꾸지 않고 "처리 중"을 보여 준다(2026-09-22 사용자 결정 — 원형
/// 스피너는 프로젝트 금지). 아래 내용이 비치도록 옅은 막 위로 밝은 띠만
/// 지나가게 하고, 터치는 막는다(대기 중 다른 조작 금지).
class ControlLoadingOverlay extends StatelessWidget {
  const ControlLoadingOverlay({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return AbsorbPointer(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Shimmer.fromColors(
          baseColor: glass.skeletonBase.withValues(alpha: 0.35),
          highlightColor: glass.skeletonHighlight.withValues(alpha: 0.85),
          child: ColoredBox(color: glass.skeletonBase),
        ),
      ),
    );
  }
}
