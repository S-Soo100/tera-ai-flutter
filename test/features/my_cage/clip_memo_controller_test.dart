import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivanaut/features/my_cage/presentation/bookmark_controller.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';

void main() {
  late Directory directory;
  late Box<String> box;
  late ClipMemoRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('memo-controller-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('memo');
    repository = HiveClipMemoRepository(box: box);
  });
  tearDown(() async {
    if (box.isOpen) await box.close();
    await directory.delete(recursive: true);
  });
  test(
      'account switch during repository opening never writes another account draft',
      () async {
    final ready = Completer<ClipMemoRepository>();
    var active = true;
    var refreshes = 0;
    final controller = ClipMemoController(
        key: (ownerId: 'a', clipId: 'clip'),
        repository: () => ready.future,
        isCurrent: () => active,
        onChanged: () => refreshes++);
    addTearDown(controller.dispose);
    final save = controller.save('private draft');
    active = false;
    ready.complete(repository);
    expect(await save, false);
    expect(await repository.read('a', 'clip'), isNull);
    expect(await repository.read('b', 'clip'), isNull);
    expect(refreshes, 0);
  });
  test('storage failure reports error and retry persists the original text',
      () async {
    var failed = true;
    final controller = ClipMemoController(
        key: (ownerId: 'a', clipId: 'clip'),
        repository: () async {
          if (failed) throw StateError('disk unavailable');
          return repository;
        },
        isCurrent: () => true,
        onChanged: () {});
    addTearDown(controller.dispose);
    expect(await controller.save('original text'), false);
    expect(controller.state.hasError, true);
    failed = false;
    expect(await controller.save('original text'), true);
    expect((await repository.read('a', 'clip'))?.text, 'original text');
  });
  test('memo removal never calls bookmark persistence', () async {
    final bookmark = BookmarkController(initial: true, persist: (_) async {});
    addTearDown(bookmark.dispose);
    final controller = ClipMemoController(
        key: (ownerId: 'a', clipId: 'clip'),
        repository: () async => repository,
        isCurrent: () => true,
        onChanged: () {});
    addTearDown(controller.dispose);
    await controller.save('keep separately');
    bookmark.setDesired(false);
    await bookmark.settled;
    expect((await repository.read('a', 'clip'))?.text, 'keep separately');
    bookmark.setDesired(true);
    await bookmark.settled;
    expect(await controller.remove(), true);
    expect(await repository.read('a', 'clip'), isNull);
    expect(bookmark.state.persisted, true);
  });
}
