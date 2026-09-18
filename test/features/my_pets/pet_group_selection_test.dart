import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/domain/pet_form_state.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

class _Pets extends PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [];
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

const _groups = [
  PetFormGroupOption(
      id: 'g1', name: '마뱀이네 집', number: 1, hasDevice: true, hasCamera: true),
  PetFormGroupOption(id: 'g2', name: '도도도의 집', number: 2, hasDevice: true),
];

/// Figma 1043:3649(그룹 선택) / 1035:2735(등록 완료) 실측 좌표.
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

  final saved = <(Pet, String?)>[];
  Future<void> pump(WidgetTester tester,
      {List<PetFormGroupOption> groups = _groups}) async {
    saved.clear();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          petListProvider.overrideWith((ref) => PetListNotifier(_Pets(), null))
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
                    builder: (c, child) => MediaQuery(
                        data: MediaQuery.of(c).copyWith(
                            padding:
                                const EdgeInsets.only(top: 62, bottom: 34)),
                        child: child!),
                    home: Builder(
                        builder: (context) => Scaffold(
                            body: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => PetFormScreen(groups: groups, onSave: (pet, group) async => saved.add((pet, group))))),
                                child: const Text('open')))))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openGroups(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('그룹 설정'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('그룹 설정'));
    await tester.pumpAndSettle();
  }

  testWidgets('group picker: full screen cards at Figma coordinates',
      (tester) async {
    await pump(tester);
    await openGroups(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final title = tester.getRect(find.text('도마뱀을 어느 환경에서 키울까요?'));
    expect(title.top, 228);
    expect(tester.getRect(find.text('도마뱀의 활동 리포트를 받아볼수 있어요')).top, 257);
    final card1 =
        tester.getRect(find.byKey(const ValueKey('pet-form-group-g1')));
    expect(card1, const Rect.fromLTWH(24, 300, 345, 78));
    expect(tester.getRect(find.byKey(const ValueKey('pet-form-group-g2'))).top,
        386);
    expect(tester.getRect(find.text('그룹 1')).topLeft, const Offset(40, 312));
    expect(tester.getRect(find.text('마뱀이네 집')).topLeft, const Offset(40, 347));
    // 사육장 → 카메라 아이콘 36 x241/285, 체크 24 x329 y+27.
    final icons = find.descendant(
        of: find.byKey(const ValueKey('pet-form-group-g1')),
        matching: find.byWidgetPredicate(
            (w) => w is FigmaIcon && w.name.contains('check_box')));
    expect(tester.getRect(icons).topLeft, const Offset(329, 327));
    final circles = find.descendant(
        of: find.byKey(const ValueKey('pet-form-group-g1')),
        matching: find.byWidgetPredicate((w) =>
            w is Container && w.constraints?.maxWidth == 36 ||
            (w is SizedBox && w.width == 36)));
    expect(circles, findsNWidgets(2));
    expect(tester.getRect(circles.at(0)).left, 241);
    expect(tester.getRect(circles.at(1)).left, 285);

    // 미선택은 CTA 비활성, 카드 선택 후 활성 → 폼에 그룹 이름 반영.
    final confirm = find.byKey(const ValueKey('pet-form-group-confirm'));
    expect(tester.getRect(confirm), const Rect.fromLTWH(12, 696, 369, 56));
    expect(
        tester.getRect(find.byKey(const ValueKey('pet-form-group-later'))).top,
        752);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: confirm, matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('pet-form-group-g1')));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('도마뱀을 어느 환경에서 키울까요?'), findsNothing);
    expect(find.text('마뱀이네 집'), findsOneWidget);

    // 나중에 하기는 변경 없이 닫힌다(기존 선택 유지).
    await openGroups(tester);
    await tester.tap(find.byKey(const ValueKey('pet-form-group-g2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pet-form-group-later')));
    await tester.pumpAndSettle();
    expect(find.text('마뱀이네 집'), findsOneWidget);
    expect(find.text('도도도의 집'), findsNothing);
    expect(saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new pet save shows the completion screen, edit just closes',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('pet-form-name')), '도도');
    await tester.tap(find.byKey(const ValueKey('pet-form-species')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('크레스티드 게코').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-form-save')));
    await tester.pumpAndSettle();
    expect(saved.length, 1);
    expect(find.byType(PetFormScreen), findsNothing);
    final icon = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == 'redesign_v2/check_circle');
    expect(tester.getRect(icon), const Rect.fromLTWH(164.5, 308, 64, 64));
    expect(tester.getRect(find.text('도마뱀 추가 완료')).top, 396);
    expect(tester.getRect(find.text('이어서 사육장과 카메라를 추가해 주세요')).top, 425);
    expect(tester.getRect(find.byKey(const ValueKey('pet-form-done-devices'))),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(
        tester.getRect(find.byKey(const ValueKey('pet-form-done-later'))).top,
        752);
    await tester.tap(find.byKey(const ValueKey('pet-form-done-later')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(saved.length, 1);
    expect(tester.takeException(), isNull);
  });

  const singleGroup = [
    PetFormGroupOption(
        id: 'g1',
        name: '마뱀이네 집',
        number: 1,
        hasDevice: true,
        hasCamera: true,
        deviceName: 'viva-iot-ㅁㅁㅁㅁ',
        cameraName: 'FB2_P4_CAM-ㅁㅁㅁㅁ'),
  ];

  Future<void> register(WidgetTester tester) async {
    // 그룹 선택 뒤엔 폼이 아래로 스크롤돼 위 칸들이 ListView 밖이다 — 끌어올린다.
    await tester.dragUntilVisible(find.byKey(const ValueKey('pet-form-name')),
        find.byType(Scrollable).first, const Offset(0, 300));
    await tester.enterText(find.byKey(const ValueKey('pet-form-name')), '도도');
    await tester.dragUntilVisible(
        find.byKey(const ValueKey('pet-form-species')),
        find.byType(Scrollable).first,
        const Offset(0, 300));
    await tester.tap(find.byKey(const ValueKey('pet-form-species')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('크레스티드 게코').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-form-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('기기가 있는 그룹이 하나면 등록 뒤 연결 카드(994:13307) — 좌표·배정', (tester) async {
    await pump(tester, groups: singleGroup);
    await register(tester);
    expect(saved.length, 1);
    expect(find.byKey(const ValueKey('pet-form-done-devices')), findsNothing);
    expect(tester.getRect(find.text('도마뱀과 기기를 연결합니다')).top, 266);
    expect(tester.getRect(find.text('도마뱀의 활동 리포트를 받아볼수 있어요')).top,
        closeTo(295, 0.5));
    final device = tester.getRect(find.text('사육장'));
    expect(device.left, 88);
    expect(device.top, closeTo(360.5, 0.5));
    expect(tester.getRect(find.text('viva-iot-ㅁㅁㅁㅁ')).right, 353);
    expect(tester.getRect(find.text('카메라')).top, closeTo(424.5, 0.5));
    final circles = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 36);
    expect(tester.getRect(circles.first), const Rect.fromLTWH(40, 352, 36, 36));
    expect(tester.getRect(find.byKey(const ValueKey('pet-form-link-confirm'))),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(
        tester.getRect(find.byKey(const ValueKey('pet-form-done-later'))).top,
        752);
    await tester.tap(find.byKey(const ValueKey('pet-form-link-confirm')));
    await tester.pumpAndSettle();
    expect(saved.length, 2);
    expect(saved[1].$2, 'g1');
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연결 카드에서 나중에 하기는 배정 없이 닫힌다', (tester) async {
    await pump(tester, groups: singleGroup);
    await register(tester);
    await tester.tap(find.byKey(const ValueKey('pet-form-done-later')));
    await tester.pumpAndSettle();
    expect(saved.length, 1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('폼에서 그룹을 이미 골랐으면 연결 카드 없이 완료 화면', (tester) async {
    await pump(tester, groups: singleGroup);
    await openGroups(tester);
    await tester.tap(find.byKey(const ValueKey('pet-form-group-g1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pet-form-group-confirm')));
    await tester.pumpAndSettle();
    await register(tester);
    expect(saved.single.$2, 'g1');
    expect(find.byKey(const ValueKey('pet-form-done-devices')), findsOneWidget);
    expect(find.text('도마뱀과 기기를 연결합니다'), findsNothing);
  });
}
