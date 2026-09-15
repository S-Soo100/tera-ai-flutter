import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';

class _MemoryPets extends PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [];
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, Object>> load(String path, Locale locale) async => {
        'pet_form_title': '개체 정보 입력',
        'pet_form_name': '이름*',
        'pet_form_species': '종*',
        'pet_form_crested': '크레스티드 게코',
        'pet_form_morph': '모프',
        'pet_form_none': '선택 안함',
        'pet_form_sex': '성별',
        'pet_form_sex_male': '수컷',
        'pet_form_sex_female': '암컷',
        'pet_form_sex_unknown': '미구분',
        'pet_form_birth': '생년월일',
        'pet_form_adoption': '입양일',
        'pet_form_weight': '체중 (g)',
        'pet_form_group': '그룹',
        'pet_form_group_settings': '그룹 설정',
        'pet_form_no_group': '그룹 없음',
        'pet_form_memo': '메모',
        'pet_form_save': '저장',
        'pet_form_back': '뒤로',
        'pet_form_photo_add': '사진 추가',
        'pet_form_discard_title': '입력을 취소할까요?',
        'pet_form_discard_body': '저장하지 않은 변경사항이 사라집니다.',
        'pet_form_keep': '계속 입력',
        'pet_form_discard': '나가기',
        'pet_form_save_failed': '저장하지 못했습니다.',
        'pet_form_required': '필수항목을 입력해 주세요',
        'pet_form_name_length': '이름은 10자 이내로 입력해 주세요',
      };
}

Future<void> _pump(WidgetTester tester,
    {Pet? original, bool failSave = false}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        petListProvider
            .overrideWith((ref) => PetListNotifier(_MemoryPets(), null)),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'test',
        assetLoader: const _Strings(),
        startLocale: const Locale('ko'),
        child: Builder(
            builder: (context) => MaterialApp(
                  theme: AppTheme.light,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Builder(
                      builder: (context) => Scaffold(
                          body: TextButton(
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                      builder: (_) => PetFormScreen(
                                          original: original,
                                          onSave: (_, __) async {
                                            if (failSave) {
                                              throw Exception('offline');
                                            }
                                          }))),
                              child: const Text('open')))),
                )),
      )));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('dirty back keeps input on cancel and leaves only after discard',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('pet-form-name')), '도도');
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('입력을 취소할까요?'), findsOneWidget);
    await tester.tap(find.text('계속 입력'));
    await tester.pumpAndSettle();
    expect(find.text('도도'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(PetFormScreen), findsNothing);
  });

  testWidgets('name counter supports graphemes and shows overflow inline',
      (tester) async {
    await _pump(tester);
    await tester.enterText(
        find.byKey(const ValueKey('pet-form-name')), '👩‍👩‍👧‍👦' * 10);
    await tester.pump();
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('이름은 10자 이내로 입력해 주세요'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('pet-form-name')), '한' * 11);
    await tester.pump();
    expect(find.text('11/10'), findsOneWidget);
    expect(find.text('이름은 10자 이내로 입력해 주세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save remains on form with changed input', (tester) async {
    await _pump(tester,
        original: Pet(
            id: 'one',
            name: '원본',
            speciesId: 'crested-gecko',
            speciesName: '크레스티드 게코'),
        failSave: true);
    await tester.enterText(find.byKey(const ValueKey('pet-form-name')), '수정');
    await tester.scrollUntilVisible(find.text('저장'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했습니다.'), findsOneWidget);
    expect(find.byType(PetFormScreen), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pet-form-name')), -400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('수정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
