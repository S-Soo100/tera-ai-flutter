import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/presentation/widgets/control_log_list.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';
import 'package:vivnanaut/shared/domain/control_log.dart';

Future<void> _pump(WidgetTester tester, List<ControlLogEntry> entries) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ControlLogList(entries: entries)),
      ),
    ),
  );
}

void main() {
  testWidgets('델타 로우 — off + 델타는 부호 붙은 델타를 그린다', (tester) async {
    await _pump(tester, [
      ControlLogEntry(
        kind: MarkerKind.fan,
        state: ControlLogState.on,
        at: DateTime(2026, 8, 30, 10, 0),
        temperature: 30,
        humidity: 50,
      ),
      ControlLogEntry(
        kind: MarkerKind.fan,
        state: ControlLogState.off,
        at: DateTime(2026, 8, 30, 12, 30),
        temperature: 25,
        humidity: 52,
        deltaTemperature: -5,
        deltaHumidity: 2,
      ),
    ]);

    // 미초기화 tr()은 키를 반환한다 — 로우 라벨·델타는 키로 검증.
    expect(find.text('env_detail_on'), findsOneWidget);
    expect(find.text('env_detail_off'), findsOneWidget);
    // 델타 로우: temp·humid 델타가 공백으로 이어 붙는다.
    expect(
      find.text('env_detail_delta_temp env_detail_delta_humid'),
      findsOneWidget,
    );
    // on 로우는 캡션.
    expect(find.text('env_detail_at_operation'), findsOneWidget);
    // 온습도 값 열은 두 로우 모두.
    expect(find.text('env_detail_env_value'), findsNWidgets(2));
  });

  testWidgets('캡션 로우 — ran(분무)·델타 없는 off는 캡션', (tester) async {
    await _pump(tester, [
      ControlLogEntry(
        kind: MarkerKind.mist,
        state: ControlLogState.ran,
        at: DateTime(2026, 8, 30, 9, 0),
        temperature: 28,
        humidity: 60,
      ),
      // 짝 없는 off — 델타 없음 → 캡션.
      ControlLogEntry(
        kind: MarkerKind.led,
        state: ControlLogState.off,
        at: DateTime(2026, 8, 30, 11, 0),
        temperature: 29,
        humidity: 58,
      ),
    ]);

    expect(find.text('env_detail_ran'), findsOneWidget);
    expect(find.text('env_detail_off'), findsOneWidget);
    expect(find.text('env_detail_at_operation'), findsNWidgets(2));
  });

  testWidgets('온습도 미상 로우 — 우측 열 생략', (tester) async {
    await _pump(tester, [
      ControlLogEntry(
        kind: MarkerKind.heater,
        state: ControlLogState.on,
        at: DateTime(2026, 8, 30, 3, 0),
      ),
    ]);

    expect(find.text('env_detail_on'), findsOneWidget);
    expect(find.text('env_detail_env_value'), findsNothing);
    expect(find.text('env_detail_at_operation'), findsNothing);
  });

  testWidgets('빈 목록 — 빈 상태 문구', (tester) async {
    await _pump(tester, const []);
    expect(find.text('env_detail_empty_log'), findsOneWidget);
  });
}
