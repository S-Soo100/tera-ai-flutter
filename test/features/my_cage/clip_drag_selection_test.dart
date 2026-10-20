import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/clip_selection.dart';

List<String> _ids(int n) => [for (var i = 0; i < n; i++) 'c$i'];

void main() {
  final ordered = _ids(30);
  const empty = ClipSelection(active: true);

  test('앞으로 끌면 처음 누른 영상부터 손가락까지 범위를 고른다', () {
    final r = dragSelection(
        base: empty, ordered: ordered, anchor: 'c2', current: 'c6', select: true);
    expect(r.selection.ids, ['c2', 'c3', 'c4', 'c5', 'c6']);
    expect(r.limited, isFalse);
  });

  test('뒤로 끌어도 같은 범위, 처음 누른 영상부터 차례로', () {
    final r = dragSelection(
        base: empty, ordered: ordered, anchor: 'c6', current: 'c3', select: true);
    expect(r.selection.ids, ['c6', 'c5', 'c4', 'c3']);
  });

  test('되돌아오면 지나쳤던 영상은 끌기 전 상태로', () {
    const base = ClipSelection(active: true, ids: ['c10']);
    final far = dragSelection(
        base: base, ordered: ordered, anchor: 'c2', current: 'c8', select: true);
    expect(far.selection.ids.length, 8);
    final back = dragSelection(
        base: base, ordered: ordered, anchor: 'c2', current: 'c4', select: true);
    expect(back.selection.ids, ['c10', 'c2', 'c3', 'c4']);
  });

  test('골라진 영상에서 시작하면 범위를 뺀다', () {
    const base = ClipSelection(active: true, ids: ['c1', 'c2', 'c3', 'c9']);
    final r = dragSelection(
        base: base, ordered: ordered, anchor: 'c2', current: 'c5', select: false);
    expect(r.selection.ids, ['c1', 'c9']);
  });

  test('20개에서 멈추고 알린다', () {
    final r = dragSelection(
        base: empty, ordered: ordered, anchor: 'c0', current: 'c29', select: true);
    expect(r.selection.count, ClipSelection.maxCount);
    expect(r.limited, isTrue);
    expect(r.selection.ids.first, 'c0');
  });

  test('목록에 없는 영상이면 그대로', () {
    const base = ClipSelection(active: true, ids: ['c1']);
    final r = dragSelection(
        base: base, ordered: ordered, anchor: 'zz', current: 'c3', select: true);
    expect(r.selection.ids, ['c1']);
  });
}
