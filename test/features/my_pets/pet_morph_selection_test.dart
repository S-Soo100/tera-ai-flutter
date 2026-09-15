import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/wiki/domain/morph_genetics.dart';
import 'package:vivanaut/features/wiki/presentation/wiki_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';

class _Pets extends PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [
        Pet(
            id: 'existing',
            name: '도도도',
            speciesId: 'crested-gecko',
            speciesName: '크레스티드 게코')
      ];
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });
  testWidgets(
      'morph route has no reset, searches Korean and English, back preserves selection',
      (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    Future<void> pump(double height, {bool empty = false}) async {
      await tester.binding.setSurfaceSize(Size(393, height));
      await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            morphDataProvider('crested-gecko').overrideWith((ref) async =>
                MorphGeneticsData.fromJson(jsonDecode(
                    File('assets/data/morphs/crested-gecko.json')
                        .readAsStringSync()))),
            petListProvider
                .overrideWith((ref) => PetListNotifier(_Pets(), null))
          ],
          child: EasyLocalization(
              supportedLocales: const [Locale('ko')],
              startLocale: const Locale('ko'),
              path: 'assets/l10n',
              assetLoader: const _Strings(),
              child: Builder(
                  builder: (c) => MaterialApp(
                      theme: AppTheme.light,
                      locale: c.locale,
                      supportedLocales: c.supportedLocales,
                      localizationsDelegates: c.localizationDelegates,
                      builder: (c, child) => RepaintBoundary(
                          key: boundary,
                          child: MediaQuery(
                              data: MediaQuery.of(c).copyWith(
                                  padding: const EdgeInsets.only(
                                      top: 62, bottom: 34)),
                              child: child!)),
                      home: PetFormScreen(
                          original: empty
                              ? null
                              : Pet(
                                  id: 'review27',
                                  name: '도도도',
                                  speciesId: 'crested-gecko',
                                  speciesName: '크레스티드 게코',
                                  sex: 'male'),
                          onSave: (_, __) async {}))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pump(852, empty: true);
    final field = find.text('선택 안함').first;
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('모프 선택'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('선택 안함'), findsNothing);

    final search = find.byType(TextField);
    expect(tester.widget<TextField>(search).autofocus, isFalse);
    await tester.enterText(search, '릴리');
    await tester.pumpAndSettle();

    final result = find.text('릴리 화이트');
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('릴리 화이트'), findsOneWidget);

    await tester.tap(find.text('릴리 화이트'));
    await tester.pumpAndSettle();
    expect(find.text('선택 안함'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
        isEmpty);
    await tester.enterText(find.byType(TextField), 'Lilly White');
    await tester.pumpAndSettle();
    expect(find.text('릴리 화이트'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('릴리 화이트'), findsOneWidget);

    // P01 — initial-consonant search drops sections and highlights matches.
    await tester.tap(find.text('릴리 화이트'));
    await tester.pumpAndSettle();
    final clear = find.byKey(const ValueKey('pet-form-morph-clear'));
    expect(clear, findsNothing);
    await tester.enterText(find.byType(TextField), 'ㄹ');
    await tester.pumpAndSettle();
    Finder header(String jamo) =>
        find.byWidgetPredicate((w) => w is Text && w.data == jamo);
    expect(header('ㄹ'), findsNothing);
    expect(find.text('루왁'), findsOneWidget);
    expect(find.text('릴리 화이트'), findsOneWidget);
    expect(find.text('노말'), findsNothing);
    final rich = tester.widget<Text>(find.text('루왁')).textSpan! as TextSpan;
    expect(rich.children!.first.style!.color, VivaColors.mainDark);
    expect(rich.children!.first.toPlainText(), '루');
    expect(rich.children![1].style?.color, isNull);
    expect(find.text('라벤더'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('trait:lavender'))),
        const Offset(12, 188));
    expect(tester.getSize(find.byKey(const ValueKey('trait:lavender'))),
        const Size(369, 44));
    expect(tester.getTopLeft(find.text('라벤더')).dx, 24);
    final clearIcon =
        find.descendant(of: clear, matching: find.byType(FigmaIcon));
    expect(tester.getTopLeft(clearIcon), const Offset(340, 139.5));
    expect(tester.getSize(clearIcon), const Size(24, 24));

    await tester.enterText(find.byType(TextField), '없는모프검색');
    await tester.pumpAndSettle();
    final empty = find.text('일치하는 모프가 없습니다');
    expect(empty, findsOneWidget);
    expect(tester.getTopLeft(empty), const Offset(24, 200));
    expect(tester.getSize(empty), const Size(345, 19));
    expect(find.byKey(const ValueKey('trait:lavender')), findsNothing);
    expect(find.byKey(const ValueKey('morph:normal')), findsNothing);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(clear, findsNothing);
    expect(header('ㄴ'), findsOneWidget);
    expect(find.text('노말'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('릴리 화이트'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });
}
