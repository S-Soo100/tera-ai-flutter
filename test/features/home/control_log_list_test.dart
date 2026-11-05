import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/auto_env.dart';
import 'package:vivanaut/features/home/presentation/widgets/control_log_list.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';

import '../notification/notification_test_host.dart';

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

  // Figma 1610:5526 — 시각·"작동 시점 온습도"·델타는 14/500 자간 −0.28.
  // 지정이 빠지면 Material 기본 +0.25가 들어갔다(2026-11-04 글자 대조).
  testWidgets('작은 글자(시각·캡션·델타) 자간은 Figma −0.28', (tester) async {
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
    final small = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontSize == 14)
        .toList();
    // 시각 2 + 캡션 1 + 델타 1.
    expect(small, hasLength(4));
    for (final t in small) {
      expect(t.style!.letterSpacing, closeTo(-0.28, 1e-9), reason: t.data);
    }
  });

  testWidgets('분무는 캡션, 델타 없는 off는 미상 변화량', (tester) async {
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
    expect(find.text('env_detail_at_operation'), findsOneWidget);
    expect(find.byKey(const ValueKey('control-delta-unknown')), findsOneWidget);
  });

  testWidgets('온습도 미상 로우 — 우측 열을 --로 유지', (tester) async {
    await _pump(tester, [
      ControlLogEntry(
        kind: MarkerKind.heater,
        state: ControlLogState.on,
        at: DateTime(2026, 8, 30, 3, 0),
      ),
    ]);

    expect(find.text('env_detail_on'), findsOneWidget);
    expect(find.text('env_detail_env_value'), findsOneWidget);
    expect(find.text('env_detail_at_operation'), findsOneWidget);
  });

  testWidgets('빈 목록 — 빈 상태 문구', (tester) async {
    await _pump(tester, const []);
    expect(find.text('env_detail_empty_log'), findsOneWidget);
  });

  // ⚠️ 이 묶음은 ko.json을 실제로 불러온다(Localization 싱글턴이 남는다) —
  // 키를 그대로 단언하는 위 테스트들보다 **뒤에** 둘 것.
  group('서버 자동 명령(실제 문구)', () {
    setUpAll(initializeNotificationLocalization);

    Future<void> pumpLog(WidgetTester t, List<ControlLogEntry> entries) async {
      await t.pumpWidget(localizedNotificationHost((context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: SingleChildScrollView(
                  child: ControlLogList(entries: entries)),
            ),
          )));
      await t.pumpAndSettle();
    }

    ControlLogEntry entry({
      required MarkerKind kind,
      required ControlLogState state,
      bool auto = false,
      AutoEnvReason? reason,
      int? sprayMs,
    }) =>
        ControlLogEntry(
          kind: kind,
          state: state,
          at: DateTime(2026, 11, 5, 13, 30),
          temperature: 28,
          humidity: 82,
          auto: auto,
          reason: reason,
          sprayMs: sprayMs,
        );

    testWidgets('자동 환기 줄', (t) async {
      await pumpLog(t, [
        entry(
            kind: MarkerKind.fan,
            state: ControlLogState.on,
            auto: true,
            reason: AutoEnvReason.ventHumidHigh)
      ]);
      expect(find.text('자동 환기 켜짐'), findsOneWidget);
      expect(find.textContaining('· 습도 높음'), findsOneWidget);
    });

    testWidgets('자동 환기 꺼짐 + 적정 범위 도달', (t) async {
      await pumpLog(t, [
        entry(
            kind: MarkerKind.fan,
            state: ControlLogState.off,
            auto: true,
            reason: AutoEnvReason.ventEnd)
      ]);
      expect(find.text('자동 환기 꺼짐'), findsOneWidget);
      expect(find.textContaining('· 적정 범위 도달'), findsOneWidget);
    });

    testWidgets('자동 분무 — 초를 알면 초, 모르면 추측하지 않는다', (t) async {
      await pumpLog(t, [
        entry(
            kind: MarkerKind.mist,
            state: ControlLogState.ran,
            auto: true,
            reason: AutoEnvReason.mist,
            sprayMs: 3000),
        entry(kind: MarkerKind.mist, state: ControlLogState.ran, auto: true),
      ]);
      expect(find.text('자동 분무 3초 작동'), findsOneWidget);
      expect(find.text('자동 분무 작동'), findsOneWidget);
      expect(find.textContaining('· 습도 낮음'), findsOneWidget);
    });

    testWidgets('원인이 없으면 시각만, 사용자 명령은 기존 제목', (t) async {
      await pumpLog(t, [
        entry(kind: MarkerKind.fan, state: ControlLogState.on, auto: true),
        entry(kind: MarkerKind.fan, state: ControlLogState.off),
      ]);
      expect(find.text('자동 환기 켜짐'), findsOneWidget);
      expect(find.text('환기팬 꺼짐'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });
}
