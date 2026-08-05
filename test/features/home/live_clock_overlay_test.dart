import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/presentation/widgets/live_clock_overlay.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';

Future<void> _pump(WidgetTester tester, Stream<DateTime> ticks) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [nowTickProvider.overrideWith((ref) => ticks)],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: LiveClockOverlay())),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('tick 값을 그대로 표시한다', (tester) async {
    await _pump(tester, Stream.value(DateTime(2026, 8, 5, 18, 33)));
    expect(find.text('2026.08.05 18:33'), findsOneWidget);
  });

  testWidgets('tick이 갱신되면 시각도 따라 바뀐다 — 시계가 멈추지 않는다',
      (tester) async {
    final controller = StreamController<DateTime>();
    addTearDown(controller.close);

    await _pump(tester, controller.stream);
    controller.add(DateTime(2026, 8, 5, 18, 33));
    await tester.pump();
    await tester.pump();
    expect(find.text('2026.08.05 18:33'), findsOneWidget);

    controller.add(DateTime(2026, 8, 5, 18, 35));
    await tester.pump();
    await tester.pump();
    expect(find.text('2026.08.05 18:35'), findsOneWidget);
    expect(find.text('2026.08.05 18:33'), findsNothing);
  });

  testWidgets('tick 도착 전에도 렌더된다 (빈 화면으로 죽지 않음)', (tester) async {
    await _pump(tester, const Stream<DateTime>.empty());
    expect(find.byKey(LiveClockOverlay.clockKey), findsOneWidget);
  });
}
