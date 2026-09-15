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
  _Pets(this.pet);
  final Pet pet;
  @override
  List<Pet> getAllPets() => [pet];
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

Future<void> _open(WidgetTester tester, String name,
    Future<void> Function(Pet) onDelete) async {
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
                        (ref) => PetListNotifier(_Pets(pet), null))
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      home: PetManagementScreen(onDelete: onDelete))))));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('개체 삭제'));
  await tester.pumpAndSettle();
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
}
