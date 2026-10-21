import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 원본 progress_activity 글리프(3/4 원호)를 도는 커스텀 스피너. Material
/// CircularProgressIndicator를 쓰지 않는다(프로젝트 금지) — 디자인이 지정한
/// 그림을 그대로 그린다. 플레이어 저장·영상 선택 일괄 작업 공용.
class ArcSpinner extends StatefulWidget {
  const ArcSpinner({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<ArcSpinner> createState() => _ArcSpinnerState();
}

class _ArcSpinnerState extends State<ArcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _turn,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ArcPainter(color: widget.color),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 10;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 1.5,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
