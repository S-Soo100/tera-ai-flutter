import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/pet_management_screen.dart';

class _Pets extends PetRepository {
  _Pets(this.pet, [this.count = 1]);
  final Pet pet;
  final int count;
  @override
  List<Pet> getAllPets() => count == 1
      ? [pet]
      : [
          for (var i = 0; i < count; i++)
            Pet(
                id: 'p$i',
                name: pet.name,
                speciesId: pet.speciesId,
                speciesName: pet.speciesName),
        ];
  @override
  Future<void> clearPets() async {}
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _open(
    WidgetTester tester, String name, Future<void> Function(Pet) onDelete,
    {int count = 1,
    bool openMenu = true,
    VoidCallback? onAdd,
    ValueChanged<Pet>? onEdit}) async {
  final pet =
      Pet(id: 'p', name: name, speciesId: 'crested', speciesName: '크레스티드 게코');
  await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('ko')],
      startLocale: const Locale('ko'),
      path: 'assets/l10n',
      assetLoader: const _Strings(),
      child: Builder(
          builder: (context) => ProviderScope(
                  overrides: [
                    petListProvider.overrideWith(
                        (ref) => PetListNotifier(_Pets(pet, count), null))
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      home: PetManagementScreen(
                          onDelete: onDelete,
                          onAdd: onAdd,
                          onEdit: onEdit))))));
  await tester.pumpAndSettle();
  if (openMenu) {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개체 삭제'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
      'cancel never deletes; confirm passes the pet once and blocks retry',
      (tester) async {
    final calls = <String>[];
    final pending = Completer<void>();
    await _open(tester, '크랑이', (pet) {
      calls.add(pet.id);
      return pending.future;
    });
    expect(find.text('크랑이를 삭제하시겠습니까?\n크레 활동 데이터, 그래프도 삭제됩니다.'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개체 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(calls, ['p']);
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isFalse);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isTrue);
  });

  for (final entry in [
    ('도롱', '도롱을'),
    ('크레 2', '크레 2를'),
    ('Camera', 'Camera을(를)')
  ]) {
    testWidgets('uses the matching object particle for ${entry.$1}',
        (tester) async {
      await _open(tester, entry.$1, (_) async => fail('must not delete'));
      expect(find.textContaining('${entry.$2} 삭제하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
      'add stays fixed and last pet edit remains reachable after scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var adds = 0;
    final edited = <String>[];
    await _open(tester, '크랑이', (_) async => fail('must not delete'),
        count: 12,
        openMenu: false,
        onAdd: () => adds++,
        onEdit: (pet) => edited.add(pet.id));
    final add = find.byKey(const Key('pet_management_add'));
    final before = tester.getRect(add);
    final last = find.byKey(const ValueKey('pet_management_menu_p11'));
    await tester.scrollUntilVisible(last, 500,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.getRect(add), before);
    await tester.tap(last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('개체 정보 수정'));
    await tester.pumpAndSettle();
    expect(edited, ['p11']);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(adds, 1);
  });

  testWidgets('popup menu grows to fit "개체 정보 수정" on one line (2026-09-16)',
      (tester) async {
    await _open(tester, '크랑이', (_) async => fail('must not delete'),
        openMenu: false);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    final label = find.text('개체 정보 수정');
    final labelRect = tester.getRect(label);
    final cell = tester.getRect(
        find.ancestor(of: label, matching: find.byType(Container)).first);
    // 한 줄(28pt)이고, 글자가 셀 안에 다 들어간다 — tightFor(140)이면 넘친다.
    expect(labelRect.height, 28);
    expect(labelRect.right, lessThanOrEqualTo(cell.right - 12 + 0.5));
  });
}
