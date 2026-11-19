import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/pinch_zoom_view.dart';

void main() {
  Future<PinchZoomViewState> pump(WidgetTester tester,
      {ValueChanged<int>? onSwipe,
      ValueChanged<bool>? onLock,
      bool doubleTapToReset = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 300,
                height: 200,
                child: PinchZoomView(
                    onSwipe: onSwipe,
                    onGestureLockChanged: onLock,
                    doubleTapToReset: doubleTapToReset,
                    child: const ColoredBox(color: Colors.black))))));
    return tester.state<PinchZoomViewState>(find.byType(PinchZoomView));
  }

  Future<void> pinchOut(WidgetTester tester) async {
    final c = tester.getCenter(find.byType(PinchZoomView));
    final a = await tester.startGesture(c - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(20, 0), pointer: 2);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  testWidgets('두 손가락으로 벌리면 확대되고 스크롤 잠금을 알린다', (tester) async {
    final locks = <bool>[];
    final state = await pump(tester, onLock: locks.add);
    expect(state.scale, 1);
    await pinchOut(tester);
    expect(state.scale, greaterThan(1.5));
    expect(locks.first, isTrue);
    expect(locks.last, isTrue, reason: '확대가 남아 있으면 잠금 유지');
  });

  testWidgets('1배에서 좌우로 넘기면 방향을 알린다', (tester) async {
    final swipes = <int>[];
    await pump(tester, onSwipe: swipes.add);
    await tester.fling(
        find.byType(PinchZoomView), const Offset(-150, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PinchZoomView), const Offset(150, 0), 1000);
    await tester.pumpAndSettle();
    expect(swipes, [1, -1]);
  });

  testWidgets('확대 중 한 손가락 이동은 넘기기가 아니다', (tester) async {
    final swipes = <int>[];
    await pump(tester, onSwipe: swipes.add);
    await pinchOut(tester);
    await tester.fling(
        find.byType(PinchZoomView), const Offset(-150, 0), 1000);
    await tester.pumpAndSettle();
    expect(swipes, isEmpty);
  });

  testWidgets('두 번 탭하면 1배로 돌아가고 잠금이 풀린다', (tester) async {
    final locks = <bool>[];
    final state =
        await pump(tester, onLock: locks.add, doubleTapToReset: true);
    await pinchOut(tester);
    expect(state.scale, greaterThan(1.5));
    final c = tester.getCenter(find.byType(PinchZoomView));
    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(c);
    await tester.pumpAndSettle();
    expect(state.scale, 1);
    expect(locks.last, isFalse);
  });
}
