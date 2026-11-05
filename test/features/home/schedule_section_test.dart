import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/features/home/presentation/widgets/schedule_editor_sheet.dart';

void main() {
  // Figma 제어 시트(1106:4111·1107:7996·1107:8134·1635:6168)와 예약 상세
  // (1106:7234·1107:8758·1107:9131)의 섹션 라벨("작동 시간"·"종료"·"밝기"·
  // "시작"·"반복")은 모두 16/600 #949090이다(2026-11-05 글자 대조 — 앱은 500).
  testWidgets('섹션 라벨은 Figma 16/600 #949090', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: ScheduleSection(label: '작동 시간', child: SizedBox()))));
    final style = tester.widget<Text>(find.text('작동 시간')).style!;
    expect(style.fontSize, 16);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.letterSpacing, closeTo(-0.32, 1e-9));
    expect(style.color, VivaColors.labelQuaternary);
  });
}
