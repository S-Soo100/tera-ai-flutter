import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/fan_timer_duration.dart';
import 'package:vivnanaut/features/home/presentation/widgets/fan_duration_sheet.dart';

void main() {
  testWidgets('시간 선택은 시트를 유지하고 시작 연타는 결과 한 번만 반환한다', (tester) async {
    var completions = 0;
    (FanTimerDuration?,)? result;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          result = await showModalBottomSheet<(FanTimerDuration?,)>(
            context: context, builder: (_) => const FanDurationSheet());
          completions++;
        }, child: const Text('open'))),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fan_timer_60')));
    await tester.pump();
    expect(completions, 0);
    expect(find.byType(FanDurationSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('fan_start')));
    await tester.tap(find.byKey(const Key('fan_start')));
    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(result, (FanTimerDuration.h1,));
  });

  testWidgets('시간을 선택한 뒤 닫으면 실행 결과가 없다', (tester) async {
    (FanTimerDuration?,)? result;
    var completed = false;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          result = await showModalBottomSheet<(FanTimerDuration?,)>(
            context: context, builder: (_) => const FanDurationSheet());
          completed = true;
        }, child: const Text('open'))),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fan_timer_10')));
    await tester.pump();
    Navigator.of(tester.element(find.byType(FanDurationSheet))).pop();
    await tester.pumpAndSettle();
    expect(completed, true);
    expect(result, isNull);
  });
}
