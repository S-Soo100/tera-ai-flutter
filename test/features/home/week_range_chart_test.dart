import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/features/home/presentation/widgets/week_range_chart.dart';
import 'package:vivanaut/shared/domain/week_range.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

/// Figma 1081:5052 실측 — 차트 369×256(+최저값 여유줄 32 = 288), 격자 32 간격, 열 폭 341/7.
void main() {
  final week = WeekRange.containing(DateTime(2026, 9, 14));
  final rows = [
    for (var i = 0; i < 7; i++)
      DayMinMax(
        day: week.days[i],
        min: i == 3 || i == 4 ? 23 : 25.0,
        max: i == 1 ? 33 : 30.0,
      ),
  ];

  Future<GlassPalette> pump(WidgetTester tester,
      {List<DayMinMax>? data}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    late GlassPalette glass;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) {
          glass = context.glass;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: WeekRangeChart(
              rows: data ?? rows,
              accent: glass.tempAccent,
              valueColor: VivaColors.mainDark,
              iconAsset: 'redesign_v2/env_temperature',
              headerFormat: (v) => '$v°C',
              axisFormat: (v, d) => '${v.toStringAsFixed(d)}°',
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    return glass;
  }

  Finder grid() => find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      w.painter.runtimeType.toString() == '_WeekGridPainter');

  testWidgets('axis labels sit on grid lines, weekdays left-aligned in grey',
      (tester) async {
    final glass = await pump(tester);
    final chart = tester.getRect(grid());
    expect(chart.width, closeTo(341, 0.01));
    expect(chart.height, 288);

    // 값 23~33 → 칸 2, 눈금 22..34 (7개). 맨 위 라벨은 y=32 선에 아래 정렬.
    final top = tester.getRect(find.text('34°'));
    expect(top.bottom, closeTo(chart.top + 32, 0.5));
    expect(top.left, closeTo(chart.right + 2, 0.01));
    final bottom = tester.getRect(find.text('22°'));
    expect(bottom.bottom, closeTo(chart.top + 224, 0.5));
    final axisStyle = tester.widget<Text>(find.text('34°')).style!;
    expect(axisStyle.color, glass.deviceOff);
    expect(axisStyle.fontSize, 12);

    // 요일: 열 왼쪽 +4, y=266(여유줄 바닥 256 + 10), 최고 요일도 회색·500.
    final tue = find.text('home_weekday_2');
    final tueRect = tester.getRect(tue);
    expect(tueRect.left, closeTo(chart.left + 341 / 7 + 4, 0.01));
    expect(tueRect.top, closeTo(chart.top + 266, 0.01));
    final tueStyle = tester.widget<Text>(tue).style!;
    expect(tueStyle.color, glass.deviceOff);
    expect(tueStyle.fontWeight, FontWeight.w500);
    expect(tester.getRect(find.text('home_weekday_1')).left,
        closeTo(chart.left + 4, 0.01));
  });

  testWidgets('최저값이 축 바닥에 붙어도 라벨이 요일과 겹치지 않는다', (tester) async {
    // 2026-09-21 제보 — 습도 40.7(축 40%) 라벨이 '월'을 덮었다.
    await pump(tester, data: [
      DayMinMax(day: week.days[0], min: 40.7, max: 96.9),
      for (var i = 1; i < 7; i++) DayMinMax(day: week.days[i]),
    ]);
    final low = tester.getRect(find.text('40.7'));
    final mon = tester.getRect(find.text('home_weekday_1'));
    expect(low.bottom, lessThanOrEqualTo(mon.top));
  });

  testWidgets('max bar and both of its labels use the accent colours',
      (tester) async {
    final glass = await pump(tester);
    final chart = tester.getRect(grid());

    final bars = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == glass.tempAccent);
    expect(bars, findsOneWidget);
    final bar = tester.getRect(bars);
    expect(bar.width, 10);
    // 열 가운데(341/7 * 1.5), 최고 33 → y=32 선(가장 위 눈금 34 아래 한 칸).
    expect(bar.center.dx, closeTo(chart.left + 341 / 7 * 1.5, 0.01));
    expect(bar.top, closeTo(chart.top + 32 + 32 * 0.5, 0.01));

    final maxLabel = find.text('33');
    expect(tester.widget<Text>(maxLabel).style!.color, VivaColors.mainDark);
    expect(tester.widget<Text>(maxLabel).style!.fontSize, 14);
    expect(tester.getRect(maxLabel).bottom, closeTo(bar.top - 4, 0.5));
    // 최고 막대의 아래 수치도 강조색.
    final tueMin = find.byWidgetPredicate((w) =>
        w is Text && w.data == '25' && w.style?.color == VivaColors.mainDark);
    expect(tueMin, findsOneWidget);
    expect(tester.getRect(tueMin).top, closeTo(bar.bottom + 4, 0.5));

    // 다른 막대 수치는 #626262, 최저 막대는 #B4AEAE.
    final neutral = tester.widget<Text>(find.text('30').first).style!;
    expect(neutral.color, glass.bodySecondary);
    final minBars = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == VivaColors.fillIcon);
    expect(minBars, findsNWidgets(2));

    // 헤더: 원본 복합색 아이콘 28, 최고값 강조색.
    final icon = tester.widget<FigmaIcon>(find.byType(FigmaIcon));
    expect(icon.name, 'redesign_v2/env_temperature');
    expect(icon.color, isNull);
    expect(icon.size, 28);
    expect(tester.widget<Text>(find.text('33.0°C')).style!.color,
        VivaColors.mainDark);
    expect(tester.widget<Text>(find.text('23.0°C')).style!.color,
        glass.textTertiary);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
