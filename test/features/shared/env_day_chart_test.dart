import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_day_chart.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/axis_bounds.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/env_chart_data.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

EnvChartData _data({bool empty = false}) {
  final tempAxis = AxisBounds.forValues([20, 30]);
  final humidAxis = AxisBounds.forValues([50, 70]);
  return EnvChartData(
    from: DateTime(2026, 8, 30),
    to: DateTime(2026, 8, 31),
    tempAxis: empty ? null : tempAxis,
    humidAxis: empty ? null : humidAxis,
    tempPoints: empty
        ? const []
        : const [(x: 0.1, y: 0.2), (x: 0.3, y: 0.5), (x: 0.5, y: 0.9)],
    humidPoints: empty ? const [] : const [(x: 0.1, y: 0.4), (x: 0.5, y: 0.6)],
  );
}

void main() {
  test('missing half-hour buckets break each metric line', () {
    final points = [
      (x: 0.0, y: .5),
      (x: 1 / 48, y: .6),
      (x: 3 / 48, y: .7),
      (x: 4 / 48, y: .8)
    ];
    final segments = environmentLineSegments(points, maxGap: 1 / 48);
    expect(segments.map((part) => part.length), [2, 2]);
    expect(segments.first.last.x, 1 / 48);
    expect(segments.last.first.x, 3 / 48);
  });
  testWidgets('same day refresh preserves user horizontal scroll',
      (tester) async {
    Widget chart(double fraction) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 393,
                child: EnvDayChart(data: _data(), initialFraction: fraction))));
    await tester.pumpWidget(chart(0));
    await tester.pump();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-120, 0));
    await tester.pumpAndSettle();
    final before =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(before, greaterThan(0));
    await tester.pumpWidget(chart(1));
    await tester.pumpAndSettle();
    expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        before);
  });
  group('resolveMarkerCenters — 시각 자리 유지 + 살짝 겹침', () {
    test('멀리 떨어지면 그대로', () {
      final out = resolveMarkerCenters([50, 100, 200], min: 14, max: 510);
      expect(out, [50, 100, 200]);
    });

    test('가까운 것은 평균 자리 중심으로 8pt 간격 겹침', () {
      final out = resolveMarkerCenters([100, 100, 106], min: 14, max: 510);
      expect(out[0], closeTo(94, 0.001));
      expect(out[1], closeTo(102, 0.001));
      expect(out[2], closeTo(110, 0.001));
    });

    test('연속 조작 10건도 실제 시각에서 멀리 밀리지 않는다', () {
      final out =
          resolveMarkerCenters(List.filled(10, 200.0), min: 14, max: 510);
      expect(out.first, greaterThanOrEqualTo(200 - 14));
      expect(out.last, lessThanOrEqualTo(200 + 14));
    });

    test('왼쪽 끝은 min 안에 담는다', () {
      final out = resolveMarkerCenters([0, 2], min: 14, max: 510);
      expect(out.first, 14);
      expect(out[1], 22);
    });

    test('오른쪽 끝은 max 안에 담는다', () {
      final out = resolveMarkerCenters([505, 508, 510], min: 14, max: 510);
      expect(out.last, 510);
      expect(out.first, 494);
    });

    test('빈 목록은 빈 목록', () {
      expect(resolveMarkerCenters([], min: 14, max: 510), isEmpty);
    });
  });

  group('EnvDayChart — 스모크', () {
    testWidgets('렌더 + 마커 아이콘 + Y축 라벨 오버레이', (tester) async {
      final log = [
        ControlLogEntry(
          kind: MarkerKind.fan,
          state: ControlLogState.on,
          at: DateTime(2026, 8, 30, 10),
        ),
        ControlLogEntry(
          kind: MarkerKind.mist,
          state: ControlLogState.ran,
          at: DateTime(2026, 8, 30, 14),
        ),
        // 창 밖 마커는 그리지 않는다.
        ControlLogEntry(
          kind: MarkerKind.led,
          state: ControlLogState.on,
          at: DateTime(2026, 8, 31, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvDayChart(data: _data(), log: log),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(EnvDayChart.chartKey), findsOneWidget);
      Finder icon(String name) =>
          find.byWidgetPredicate((w) => w is FigmaIcon && w.name == name);
      expect(
          icon(FigmaIcons.fanBadge(on: true, compact: true)), findsOneWidget);
      expect(icon('redesign_v2/2828/humidity_high_glyph'), findsOneWidget);
      expect(icon(FigmaIcons.ledBadge(on: true, compact: true)),
          findsNothing); // 창 밖
      // X축 눈금 4개 (오전 12시/6시/오후 12시/6시 — 미초기화 tr()은 키 반환).
      expect(find.text('home_chart_time_am'), findsNWidgets(2));
      expect(find.text('home_chart_time_pm'), findsNWidgets(2));
    });

    testWidgets('스크러버 — 탭하면 스냅된 위치가 콜백으로 온다', (tester) async {
      double? scrubbed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvDayChart(
              data: _data(),
              onScrubChanged: (x) => scrubbed = x,
            ),
          ),
        ),
      );
      await tester.pump();

      // 콘텐츠 좌표 0.3 근처를 탭 → 데이터 포인트(0.1/0.3/0.5)로 스냅.
      final box = tester.getRect(find.byKey(EnvDayChart.chartKey));
      await tester.tapAt(Offset(
        box.left + EnvDayChart.plotInset + 0.3 * EnvDayChart.contentWidth,
        box.top + EnvDayChart.markerBand + 50,
      ));
      await tester.pump();
      expect(scrubbed, isNotNull);
      expect(scrubbed, closeTo(0.3, 0.05));
    });
  });

  group('Figma 1610:6830 — 손가락 표시·격자', () {
    Widget host(double? scrubX) => MaterialApp(
          home: Scaffold(
            body: Padding(
              // 상자가 차트 위로 88 올라가므로 위 여백을 둔다.
              padding: const EdgeInsets.only(top: 120),
              child: SizedBox(
                width: 393,
                child: EnvDayChart(data: _data(), scrubX: scrubX),
              ),
            ),
          ),
        );

    testWidgets('상자는 테두리 없는 r12 회색 면, 차트 위 88pt, 세로선 가운데', (tester) async {
      await tester.pumpWidget(host(0.3));
      await tester.pump();

      final chart = tester.getRect(find.byKey(EnvDayChart.chartKey));
      final boxFinder = find.byKey(EnvDayChart.scrubBoxKey);
      expect(boxFinder, findsOneWidget);
      final box = tester.getRect(boxFinder);
      expect(box.top, closeTo(chart.top - EnvDayChart.scrubBoxLift, 0.01));
      final lineX =
          chart.left + EnvDayChart.plotInset + 0.3 * EnvDayChart.contentWidth;
      // 세로선 가운데, 단 좌우 12pt 안에서 멈춘다.
      final left = (lineX - box.width / 2).clamp(
          chart.left + EnvDayChart.plotInset,
          chart.right - EnvDayChart.plotInset - box.width);
      expect(box.left, closeTo(left, 0.5));
      expect(box.right, lessThanOrEqualTo(chart.right - EnvDayChart.plotInset));

      final deco =
          tester.widget<Container>(boxFinder).decoration as BoxDecoration;
      expect(deco.border, isNull);
      expect(deco.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('윗줄 시각, 아랫줄 온도·습도를 따로 쓴다', (tester) async {
      await tester.pumpWidget(host(0.3));
      await tester.pump();
      final box = find.byKey(EnvDayChart.scrubBoxKey);
      expect(
          find.descendant(
              of: box, matching: find.text('env_detail_scrub_temp')),
          findsOneWidget);
      expect(
          find.descendant(
              of: box, matching: find.text('env_detail_scrub_humid')),
          findsOneWidget);
    });

    testWidgets('세로선이 보이는 구간 밖으로 스크롤되면 상자도 숨는다', (tester) async {
      await tester.pumpWidget(host(0.1));
      await tester.pump();
      expect(find.byKey(EnvDayChart.scrubBoxKey), findsOneWidget);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(EnvDayChart.scrubBoxKey), findsNothing);
    });

    testWidgets('scrubX가 없으면 상자도 없다', (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pump();
      expect(find.byKey(EnvDayChart.scrubBoxKey), findsNothing);
    });

    test('격자선은 0.5pt', () {
      expect(EnvDayChart.gridStrokeWidth, 0.5);
    });
  });
}
