import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import 'management_widgets.dart';

/// 카메라 상세(세로 확대)의 '카메라 초점 가이드' — Figma 1813:8229,
/// 메모 "카메라 초점 가이드는 항상 노출"(2026-11-10).
///
/// 제목 16/600 #949090 → 8 → 회색 면(#F4F4F4, r16, 패딩 12) 안에
/// 14/500 줄높이 21 #3C3C3C 세 문장, 문장 사이 8. 높이는 글자에 맞춰 늘어난다.
class CameraFocusGuide extends StatelessWidget {
  const CameraFocusGuide({super.key});

  static const boxKey = Key('camera_focus_guide_box');

  static const _lines = [
    'camera_focus_guide_1',
    'camera_focus_guide_2',
    'camera_focus_guide_3',
  ];

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final body =
        managementStyle(context, size: 14).copyWith(height: 21 / 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('camera_focus_guide_title'.tr(),
            style: managementStyle(context,
                weight: FontWeight.w600, color: glass.textTertiary)),
        const SizedBox(height: 8),
        Container(
          key: boxKey,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: glass.overlay, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Text(_lines[i].tr(), style: body),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
