import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/pinch_zoom_view.dart';

void main() {
  Future<PinchZoomViewState> pump(WidgetTester tester,
      {ValueChanged<int>? onSwipe,
      ValueChanged<bool>? onLock,
      TransformationController? controller,
      Key? key,
      bool doubleTapToReset = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 300,
                height: 200,
                child: PinchZoomView(
                    key: key,
                    controller: controller,
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

  testWidgets('짧고 빠른 넘기기(25px)도 넘긴다 — 예전 가로 드래그 거리 기준', (tester) async {
    final swipes = <int>[];
    await pump(tester, onSwipe: swipes.add);
    await tester.fling(find.byType(PinchZoomView), const Offset(-25, 0), 800);
    await tester.pumpAndSettle();
    expect(swipes, [1]);
  });

  testWidgets('제자리 탭은 넘기기가 아니다', (tester) async {
    final swipes = <int>[];
    await pump(tester, onSwipe: swipes.add);
    await tester.tap(find.byType(PinchZoomView));
    await tester.pumpAndSettle();
    expect(swipes, isEmpty);
  });

  testWidgets('두 손가락 뒤 한 손가락을 떼고 남은 손가락을 밀어도 넘기지 않는다',
      (tester) async {
    final swipes = <int>[];
    final state = await pump(tester, onSwipe: swipes.add);
    final c = tester.getCenter(find.byType(PinchZoomView));
    final a = await tester.startGesture(c - const Offset(40, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(40, 0), pointer: 2);
    await tester.pump();
    // 오므리기 — 1배 밑으로는 안 줄어 배율은 1 그대로.
    for (var i = 0; i < 3; i++) {
      await a.moveBy(const Offset(8, 0));
      await b.moveBy(const Offset(-8, 0));
      await tester.pump();
    }
    await b.up();
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await a.up();
    await tester.pumpAndSettle();
    expect(state.scale, 1);
    expect(swipes, isEmpty);
  });

  testWidgets('바깥 컨트롤러면 다시 만들어져도 배율이 남고 잠금을 다시 알린다', (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final locks = <bool>[];
    await pump(tester,
        controller: controller, onLock: locks.add, key: const ValueKey(1));
    await pinchOut(tester);
    final zoomed = controller.value.getMaxScaleOnAxis();
    expect(zoomed, greaterThan(1.5));

    // 재연결처럼 면을 새로 만든다 — 해체(false)·새 면(true)이 빌드 뒤에 온다.
    locks.clear();
    final state = await pump(tester,
        controller: controller, onLock: locks.add, key: const ValueKey(2));
    await tester.pump();
    expect(state.scale, zoomed);
    expect(locks.last, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빌드 중 바깥에서 1배로 되돌려도 오류 없이 다음 프레임에 잠금을 푼다',
      (tester) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final locks = <bool>[];
    await pump(tester, controller: controller, onLock: locks.add);
    await pinchOut(tester);
    expect(locks.last, isTrue);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      controller.value = Matrix4.identity(); // 빌드 중 변경
      return Center(
          child: SizedBox(
              width: 300,
              height: 200,
              child: PinchZoomView(
                  controller: controller,
                  onGestureLockChanged: locks.add,
                  child: const ColoredBox(color: Colors.black))));
    })));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(locks.last, isFalse);
  });
}
