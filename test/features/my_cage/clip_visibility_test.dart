import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/domain/clip_visibility.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';

class _Repository implements ClipVisibilityRepository {
  final hidden = <String, Set<String>>{};
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<Set<String>> hiddenClipIds(String accountId) async =>
      {...?hidden[accountId]};
  @override
  Future<void> hide(String accountId, String clipId) async {
    await pending?.future;
    if (fail) throw StateError('table unavailable');
    (hidden[accountId] ??= {}).add(clipId);
  }
}

MotionClip _clip(String id) => MotionClip(
    id: id, cameraId: 'cam', startedAt: DateTime.utc(2026), durationSec: 10);
void main() {
  test('missing hidden pages keep advancing raw cursor until visible row',
      () async {
    var calls = 0;
    final page = await loadVisibleClipPage(
        hiddenIds: () => {'a', 'b'},
        load: (cursor) async {
          calls++;
          final id = ['a', 'b', 'c'][calls - 1];
          return (
            items: [_clip(id)],
            nextCursor:
                calls < 3 ? (startedAt: DateTime.utc(2026), id: id) : null,
            hasMore: calls < 3
          );
        });
    expect(calls, 3);
    expect(page.items.single.id, 'c');
    expect(page.hasMore, false);
  });
  test('repeated cursor fails instead of looping on hidden page', () async {
    final cursor = (startedAt: DateTime.utc(2026), id: 'a');
    await expectLater(
        loadVisibleClipPage(
            before: cursor,
            hiddenIds: () => {'a'},
            load: (_) async =>
                (items: [_clip('a')], nextCursor: cursor, hasMore: true)),
        throwsStateError);
  });
  test(
      'hide failure preserves visible clip and successful retry persists only owner hide',
      () async {
    final repository = _Repository()..fail = true;
    final controller = ClipVisibilityController(
        repository: repository, accountId: 'a', isCurrent: () => true);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(await controller.hide('clip'), false);
    expect(controller.state.hiddenIds, isEmpty);
    expect(controller.state.saveError, isNotNull);
    repository.fail = false;
    expect(await controller.hide('clip'), true);
    expect(controller.state.hiddenIds, {'clip'});
    expect(await repository.hiddenClipIds('b'), isEmpty);
    final secondDevice = ClipVisibilityController(
        repository: repository, accountId: 'a', isCurrent: () => true);
    addTearDown(secondDevice.dispose);
    await secondDevice.refresh();
    expect(secondDevice.state.hiddenIds, {'clip'});
  });
  test('account change during hide never publishes old account result',
      () async {
    final repository = _Repository()..pending = Completer<void>();
    var active = true;
    final controller = ClipVisibilityController(
        repository: repository, accountId: 'a', isCurrent: () => active);
    addTearDown(controller.dispose);
    await controller.refresh();
    final result = controller.hide('clip');
    active = false;
    repository.pending!.complete();
    expect(await result, false);
    expect(controller.state.hiddenIds, isEmpty);
    expect(await repository.hiddenClipIds('b'), isEmpty);
  });
}
