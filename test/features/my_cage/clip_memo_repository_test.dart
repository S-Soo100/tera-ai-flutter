import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';

void main() {
  late Directory directory;
  late Box<String> box;
  late ClipMemoRepository repository;
  var now = DateTime.utc(2026, 9, 15, 3);

  HiveClipMemoRepository buildRepository({int Function(int)? nextInt}) =>
      HiveClipMemoRepository(
        box: box,
        clock: () => now,
        nextInt: nextInt ?? (_) => 0,
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('clip-memo-test-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('clip-memos');
    now = DateTime.utc(2026, 9, 15, 3);
    repository = buildRepository();
  });

  tearDown(() async {
    if (box.isOpen) await box.close();
    await directory.delete(recursive: true);
  });

  test('memo text, color and timestamp survive closing and reopening Hive',
      () async {
    await repository.save('account-a', 'clip-1', '  첫 메모\n두 번째 줄 🦎  ');
    await box.close();
    box = await Hive.openBox<String>('clip-memos');
    repository = buildRepository();

    final memo = (await repository.read('account-a', 'clip-1'))!;
    expect(memo.clipId, 'clip-1');
    expect(memo.text, '  첫 메모\n두 번째 줄 🦎  ');
    expect(memo.colorIndex, 0);
    expect(memo.updatedAt, DateTime.utc(2026, 9, 15, 3));
    expect(memo.updatedAt.isUtc, isTrue);
  });

  test('account and clip keys stay isolated even with delimiter characters',
      () async {
    await repository.save('account:a', 'clip', '첫 계정');
    await repository.save('account', 'a:clip', '두 번째 계정');
    await repository.save('account:a', 'clip-2', '다른 영상');
    expect((await repository.read('account:a', 'clip'))!.text, '첫 계정');
    expect((await repository.read('account', 'a:clip'))!.text, '두 번째 계정');
    expect((await repository.read('account:a', 'clip-2'))!.text, '다른 영상');
    expect(await repository.read('other-account', 'clip'), isNull);
    expect(await repository.read('account:a', 'missing'), isNull);
  });

  test('first memo can use every one of the six colors', () async {
    for (var index = 0; index < 6; index++) {
      final repo = buildRepository(nextInt: (_) => index);
      await repo.save('account-$index', 'clip', '메모');
      expect((await repo.read('account-$index', 'clip'))!.colorIndex, index);
    }
  });

  test('new colors exclude the previous assignment within each account',
      () async {
    await repository.save('account-a', 'clip-1', '첫 메모');
    await repository.save('account-a', 'clip-2', '두 번째 메모');
    await repository.save('account-b', 'clip-1', '다른 계정의 첫 메모');
    expect((await repository.read('account-a', 'clip-1'))!.colorIndex, 0);
    expect((await repository.read('account-a', 'clip-2'))!.colorIndex, 1);
    expect((await repository.read('account-b', 'clip-1'))!.colorIndex, 0);
  });

  test('editing retains color and does not replace the last new assignment',
      () async {
    await repository.save('account-a', 'clip-1', '첫 메모');
    await repository.save('account-a', 'clip-2', '두 번째 메모');
    now = DateTime.utc(2026, 9, 16, 4);
    await repository.save('account-a', 'clip-1', '수정');
    final edited = (await repository.read('account-a', 'clip-1'))!;
    expect(edited.text, '수정');
    expect(edited.colorIndex, 0);
    expect(edited.updatedAt, now);
    await repository.save('account-a', 'clip-3', '세 번째 메모');
    expect((await repository.read('account-a', 'clip-3'))!.colorIndex, 0);
  });

  test('deleting and reopening retain last-color history for the account',
      () async {
    await repository.save('account-a', 'clip-1', '첫 메모');
    await repository.remove('account-a', 'clip-1');
    await box.close();
    box = await Hive.openBox<String>('clip-memos');
    repository = buildRepository();
    expect(await repository.read('account-a', 'clip-1'), isNull);
    await repository.save('account-a', 'clip-1', '새 메모');
    expect((await repository.read('account-a', 'clip-1'))!.colorIndex, 1);
  });

  test(
      'concurrent new saves share the color sequence across repository instances',
      () async {
    final otherRepository = buildRepository();
    await Future.wait(List.generate(20, (index) {
      final repo = index.isEven ? repository : otherRepository;
      return repo.save('account-a', 'clip-$index', '메모 $index');
    }));
    final memos = await Future.wait(List.generate(
        20, (index) => repository.read('account-a', 'clip-$index')));
    for (var index = 0; index < memos.length; index++) {
      expect(memos[index]!.text, '메모 $index');
      expect(memos[index]!.colorIndex, index.isEven ? 0 : 1);
    }
  });

  test('save, read and remove observe call order for the same account',
      () async {
    final saved = repository.save('account-a', 'clip-1', '메모');
    final read = repository.read('account-a', 'clip-1');
    final removed = repository.remove('account-a', 'clip-1');
    await saved;
    expect((await read)!.text, '메모');
    await removed;
    expect(await repository.read('account-a', 'clip-1'), isNull);
  });

  test('remove only deletes the chosen memo in the chosen account', () async {
    await repository.save('account-a', 'clip-1', '삭제 대상');
    await repository.save('account-a', 'clip-2', '남길 메모');
    await repository.save('account-b', 'clip-1', '다른 계정');
    await repository.remove('account-a', 'clip-1');
    await repository.remove('account-a', 'missing');
    expect(await repository.read('account-a', 'clip-1'), isNull);
    expect((await repository.read('account-a', 'clip-2'))!.text, '남길 메모');
    expect((await repository.read('account-b', 'clip-1'))!.text, '다른 계정');
  });

  test('blank account or clip IDs cannot read, save or remove shared records',
      () async {
    for (final ids in [('', 'clip'), (' \n', 'clip'), ('account', '')]) {
      await expectLater(repository.read(ids.$1, ids.$2), throwsArgumentError);
      await expectLater(
          repository.save(ids.$1, ids.$2, '메모'), throwsArgumentError);
      await expectLater(repository.remove(ids.$1, ids.$2), throwsArgumentError);
    }
    expect(box.isEmpty, isTrue);
  });

  test(
      'empty text is rejected without erasing an existing memo or color history',
      () async {
    await repository.save('account-a', 'clip-1', '원본');
    for (final text in ['', ' \n\t ']) {
      await expectLater(
          repository.save('account-a', 'clip-1', text), throwsArgumentError);
      await expectLater(
          repository.save('account-a', 'clip-2', text), throwsArgumentError);
    }
    expect((await repository.read('account-a', 'clip-1'))!.text, '원본');
    expect(await repository.read('account-a', 'clip-2'), isNull);
    await repository.save('account-a', 'clip-2', '유효한 입력');
    expect((await repository.read('account-a', 'clip-2'))!.colorIndex, 1);
  });
}
