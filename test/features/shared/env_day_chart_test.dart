import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/presentation/widgets/env_day_chart.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/shared/domain/axis_bounds.dart';
import 'package:vivnanaut/shared/domain/control_log.dart';
import 'package:vivnanaut/shared/domain/env_chart_data.dart';

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
    humidPoints:
        empty ? const [] : const [(x: 0.1, y: 0.4), (x: 0.5, y: 0.6)],
  );
}

void main() {
  group('resolveMarkerCenters — 겹침 보정', () {
    test('겹치지 않으면 그대로', () {
      final out = resolveMarkerCenters([50, 100, 200], min: 14, max: 510);
      expect(out, [50, 100, 200]);
    });

    test('같은 위치는 최소 22pt 간격으로 벌린다', () {
      final out = resolveMarkerCenters([100, 100, 105], min: 14, max: 510);
      expect(out, [100, 122, 144]);
    });

    test('왼쪽 끝은 min으로 클램프', () {
      final out = resolveMarkerCenters([0, 2], min: 14, max: 510);
      expect(out.first, 14);
      expect(out[1] - out[0], greaterThanOrEqualTo(22));
    });

    test('오른쪽 끝을 넘치면 되밀어 max 안에 담는다', () {
      final out = resolveMarkerCenters([505, 508, 510], min: 14, max: 510);
      expect(out.last, lessThanOrEqualTo(510));
      expect(out[2] - out[1], closeTo(22, 0.001));
      expect(out[1] - out[0], closeTo(22, 0.001));
      expect(out.first, greaterThanOrEqualTo(14));
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
      expect(find.byIcon(Icons.wind_power), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb), findsNothing); // 창 밖
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
        box.left + EnvDayChart.yLabelWidth + 0.3 * EnvDayChart.contentWidth,
        box.top + EnvDayChart.markerBand + 50,
      ));
      await tester.pump();
      expect(scrubbed, isNotNull);
      expect(scrubbed, closeTo(0.3, 0.05));
    });
  });
}
