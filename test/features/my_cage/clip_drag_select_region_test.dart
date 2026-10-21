import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_selection_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_selection_widgets.dart';

const _scope = ClipSelectionScope.feed;
final _ids = [for (var i = 0; i < 12; i++) 'c$i'];

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.binding.setSurfaceSize(const Size(300, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
          home: Scaffold(body: Consumer(builder: (context, ref, _) {
    captured = ref;
    return ClipDragSelectRegion(
      scope: _scope,
      orderedIds: () => _ids,
      child: GridView.count(
        crossAxisCount: 3,
        children: [
          for (final id in _ids)
            ClipSelectableThumb(
                key: ValueKey('cell_$id'),
                scope: _scope,
                clipId: id,
                onOpen: () {},
                child: const ColoredBox(color: Colors.grey)),
        ],
      ),
    );
  })))));
  return captured;
}

List<String> _selected(WidgetRef ref) =>
    ref.read(clipSelectionProvider(_scope)).ids;

void main() {
  testWidgets('꾹 눌러 끌면 처음 영상부터 손가락 아래까지 골라진다', (tester) async {
    final ref = await _pump(tester);
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('cell_c0'))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(ref.read(clipSelectionProvider(_scope)).active, isTrue);
    expect(_selected(ref), ['c0']);
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_c4'))));
    await tester.pump();
    expect(_selected(ref), ['c0', 'c1', 'c2', 'c3', 'c4']);
    // 되돌아오면 줄어든다.
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_c1'))));
    await tester.pump();
    expect(_selected(ref), ['c0', 'c1']);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('골라진 영상에서 꾹 눌러 끌면 범위가 빠진다', (tester) async {
    final ref = await _pump(tester);
    ref.read(clipSelectionProvider(_scope).notifier)
      ..enter('c3')
      ..toggle('c4')
      ..toggle('c5')
      ..toggle('c8');
    await tester.pump();
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('cell_c3'))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_c5'))));
    await tester.pump();
    expect(_selected(ref), ['c8']);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('선택 모드에선 가로로 끌어도 고른다, 모드 밖에선 아님', (tester) async {
    final ref = await _pump(tester);
    await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('cell_c0'))),
        const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(ref.read(clipSelectionProvider(_scope)).active, isFalse);

    ref.read(clipSelectionProvider(_scope).notifier).enter();
    await tester.pump();
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('cell_c3'))));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_c5'))));
    await tester.pump();
    expect(_selected(ref), ['c3', 'c4', 'c5']);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('그냥 탭은 지금처럼 하나씩 고르기', (tester) async {
    final ref = await _pump(tester);
    ref.read(clipSelectionProvider(_scope).notifier).enter();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cell_c2')));
    await tester.pump();
    expect(_selected(ref), ['c2']);
  });
}
