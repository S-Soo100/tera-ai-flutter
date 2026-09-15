import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';
import 'package:vivanaut/features/my_cage/domain/clip_memo.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_card.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_editor.dart';

final _account = StateProvider<String?>((ref) => 'a');
const _key = (ownerId: 'a', clipId: 'clip');

class _Repository implements ClipMemoRepository {
  final memos = <String, ClipMemo>{};
  bool fail = false;
  Completer<void>? pendingRead;
  @override
  Future<ClipMemo?> read(String account, String clip) async {
    await pendingRead?.future;
    return memos['$account/$clip'];
  }

  @override
  Future<void> save(String account, String clip, String text) async {
    if (fail) throw StateError('disk full');
    memos['$account/$clip'] = ClipMemo(
        clipId: clip, text: text, colorIndex: 2, updatedAt: DateTime.utc(2026));
  }

  @override
  Future<void> remove(String account, String clip) async =>
      memos.remove('$account/$clip');
}

Future<ProviderContainer> _pump(WidgetTester tester, _Repository repository,
    {Future<bool> Function()? bookmark}) async {
  final container = ProviderContainer(overrides: [
    clipMemoAccountProvider.overrideWith((ref) => ref.watch(_account)),
    clipMemoRepositoryProvider.overrideWith((ref) async => repository),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showClipMemoEditor(context,
                          key: _key, saveBookmark: bookmark),
                      child: const Text('open')))))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('failure keeps draft, retry saves and closes editor',
      (tester) async {
    final repository = _Repository()..fail = true;
    await _pump(tester, repository);
    await tester.enterText(
        find.byKey(const Key('clip_memo_input')), 'keep my draft');
    await tester.pump();
    await tester.tap(find.text('clip_memo_save'));
    await tester.pumpAndSettle();
    expect(find.text('clip_memo_failed'), findsOneWidget);
    expect(find.text('keep my draft'), findsOneWidget);
    expect(repository.memos, isEmpty);
    repository.fail = false;
    await tester.tap(find.text('clip_memo_save'));
    await tester.pumpAndSettle();
    expect(repository.memos['a/clip']?.text, 'keep my draft');
    expect(find.byType(ClipMemoEditor), findsNothing);
  });
  testWidgets('skip saves bookmark without modifying existing memo',
      (tester) async {
    final repository = _Repository();
    await repository.save('a', 'clip', 'existing');
    var bookmarked = false;
    await _pump(tester, repository, bookmark: () async {
      bookmarked = true;
      return true;
    });
    expect(bookmarked, false);
    await tester.enterText(
        find.byKey(const Key('clip_memo_input')), 'unsaved edit');
    await tester.pump();
    await tester.tap(find.text('clip_memo_skip'));
    await tester.pumpAndSettle();
    expect(bookmarked, true);
    expect(repository.memos['a/clip']?.text, 'existing');
  });
  testWidgets('changing account closes private draft immediately',
      (tester) async {
    final repository = _Repository();
    final container = await _pump(tester, repository);
    await tester.enterText(
        find.byKey(const Key('clip_memo_input')), 'account a private');
    container.read(_account.notifier).state = 'b';
    await tester.pumpAndSettle();
    expect(find.byType(ClipMemoEditor), findsNothing);
    expect(find.text('account a private'), findsNothing);
    expect(repository.memos, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow editor with keyboard and large text remains scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, _Repository(), bookmark: () async => true);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('clip_memo_skip'));
    await tester.tap(find.text('clip_memo_skip'));
    await tester.pumpAndSettle();
    expect(find.byType(ClipMemoEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('memo card stays 112 by 180 with long large text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: Center(
                    child: ClipMemoCard(
                        memo: ClipMemo(
                            clipId: 'clip',
                            text: List.filled(100, '긴 메모').join(),
                            colorIndex: 5,
                            updatedAt: DateTime.utc(2026)),
                        memoKey: _key))))));
    expect(tester.getSize(find.byType(ClipMemoCard)), const Size(112, 180));
    expect(tester.takeException(), isNull);
  });
  test('late reader result cannot expose previous account memo', () async {
    final repository = _Repository();
    await repository.save('a', 'clip', 'private');
    repository.pendingRead = Completer<void>();
    final container = ProviderContainer(overrides: [
      clipMemoAccountProvider.overrideWith((ref) => ref.watch(_account)),
      clipMemoRepositoryProvider.overrideWith((ref) async => repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(clipMemoProvider(_key), (_, __) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    container.read(_account.notifier).state = 'b';
    repository.pendingRead!.complete();
    await container.pump();
    expect(await container.read(clipMemoProvider(_key).future), isNull);
  });
}
