import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/domain/activity_axis.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/activity_day_chart.dart';

ActivityBucket _bucket(double? seconds) => ActivityBucket(
    window: ActivityWindow(
        startUtc: DateTime.utc(2026, 9, 19), endUtc: DateTime.utc(2026, 9, 20)),
    seconds: seconds,
    state: ActivityObservation.complete,
    isEstimated: false);

Future<void> _pump(WidgetTester tester, ActivityAxis axis) async {
  await tester.binding.setSurfaceSize(const Size(393, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ActivityBars(
                  buckets: [for (var i = 0; i < 7; i++) _bucket(60)],
                  axis: axis,
                  weekly: true,
                  labels: const ['월', '화', '수', '목', '금', '토', '일'])))));
}

/// 축 라벨이 두 줄로 접히면 눈금을 못 읽는다 — 분 라벨("60m")은 시간
/// 라벨("3h")보다 넓어서 Figma 원본의 26pt 컬럼에 안 들어간다
/// (2026-09-21 시뮬 실측: "60 / m"으로 접혔다).
void main() {
  testWidgets('분 축 라벨은 한 줄로 들어간다', (tester) async {
    await _pump(tester, ActivityAxis.forPeak(600));

    final labels = find.byKey(const Key('activity_axis_label'));
    expect(labels, findsNWidgets(7));
    for (final widget in tester.widgetList<Text>(labels)) {
      expect(widget.maxLines, 1);
    }
    // 한 줄 높이 — 두 줄이면 이 값의 두 배가 된다.
    final lineHeight = 12 * 1.193359375;
    for (var i = 0; i < 7; i++) {
      expect(tester.getSize(labels.at(i)).height, closeTo(lineHeight, 1),
          reason: '$i번째 라벨이 접혔다');
    }
  });

  testWidgets('시간 축도 한 줄로 들어간다', (tester) async {
    await _pump(tester, ActivityAxis.forPeak(3 * 3600));

    final labels = find.byKey(const Key('activity_axis_label'));
    for (var i = 0; i < 7; i++) {
      expect(tester.getSize(labels.at(i)).height, closeTo(12 * 1.193359375, 1),
          reason: '$i번째 라벨이 접혔다');
    }
  });

  testWidgets('축 컬럼을 넓혀도 막대 영역이 화면을 넘지 않는다', (tester) async {
    await _pump(tester, ActivityAxis.forPeak(600));
    expect(tester.takeException(), isNull);
  });
}
