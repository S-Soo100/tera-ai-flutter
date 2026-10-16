import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/keep_screen_on.dart';

void main() {
  late List<bool> calls;
  late ScreenWakeLock lock;

  setUp(() {
    calls = [];
    lock = ScreenWakeLock(toggle: (enable) async => calls.add(enable));
  });

  Widget host({required bool visible, bool second = false}) => ProviderScope(
        overrides: [screenWakeLockProvider.overrideWithValue(lock)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            TickerMode(
              enabled: visible,
              child: const KeepScreenOn(child: SizedBox()),
            ),
            if (second) const KeepScreenOn(child: SizedBox()),
          ]),
        ),
      );

  testWidgets('보이면 켜고 사라지면 끈다', (tester) async {
    await tester.pumpWidget(host(visible: true));
    expect(calls, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(calls, [true, false]);
    expect(lock.isHeld, isFalse);
  });

  testWidgets('다른 탭·덮인 화면(TickerMode 꺼짐)이면 놓는다', (tester) async {
    await tester.pumpWidget(host(visible: false));
    expect(calls, isEmpty);
    await tester.pumpWidget(host(visible: true));
    expect(calls, [true]);
    await tester.pumpWidget(host(visible: false));
    expect(calls, [true, false]);
  });

  testWidgets('여러 화면이 잡으면 마지막이 놓을 때만 끈다', (tester) async {
    await tester.pumpWidget(host(visible: true, second: true));
    expect(calls, [true]);
    await tester.pumpWidget(host(visible: false, second: true));
    expect(calls, [true], reason: '두 번째가 아직 잡고 있다');
    expect(lock.isHeld, isTrue);
    await tester.pumpWidget(host(visible: false));
    expect(calls, [true, false]);
  });
}
