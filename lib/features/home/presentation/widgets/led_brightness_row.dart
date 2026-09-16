import 'dart:ui' as ui show TextDirection;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';

/// LED 밝기 행 — Figma 1106:4127(제어 시트) / 1107:8758(예약 편집기) 공용.
/// 345×48 r16 흰색, 퍼센트 18/600 좌 12(폭 51 + 12), 트랙 6 #E3E3E3·채움
/// LED색, 흰 52×32 썸. 값은 20~100, 10% 단위.
class LedBrightnessRow extends StatelessWidget {
  const LedBrightnessRow(
      {super.key,
      required this.value,
      required this.onChanged,
      this.valueKey,
      this.sliderKey});

  final double value;

  /// null이면 잠금(전송 중).
  final ValueChanged<double>? onChanged;
  final Key? valueKey;
  final Key? sliderKey;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
          color: glass.surfaceHeader, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        SizedBox(
            width: 51,
            child: Text('unit_percent_fmt'.tr(args: ['${value.round()}']),
                key: valueKey,
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    height: 21.48046875 / 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.36,
                    color: glass.textSecondary))),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: glass.deviceLed,
              inactiveTrackColor: glass.border,
              disabledActiveTrackColor: glass.deviceLed,
              disabledInactiveTrackColor: glass.border,
              thumbShape: const PillThumbShape(),
              // 원본 트랙에는 눈금이 없다(시뮬 확인 2026-09-16).
              tickMarkShape: SliderTickMarkShape.noTickMark,
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              min: 20,
              max: 100,
              divisions: 8,
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Figma 밝기 썸 — 흰 52×32 r16, 옅은 그림자.
class PillThumbShape extends SliderComponentShape {
  const PillThumbShape();
  static const Size _size = Size(52, 32);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _size;

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required ui.TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: _size.width, height: _size.height),
        const Radius.circular(16));
    final canvas = context.canvas;
    canvas.drawRRect(
        rect.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(rect, Paint()..color = Colors.white);
  }
}
