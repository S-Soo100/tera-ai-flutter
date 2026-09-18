// flutter test --dart-define=CAPTURE_PAIRING_PETS=true test/features/my_cage/pairing_pet_selection_capture_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/pairing_pet_selection_screen.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';

class _PairingTranslations extends AssetLoader {
  const _PairingTranslations();

  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final decoded = jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  }
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_PAIRING_PETS')) {
    test('opt-in pairing pet captures', () {},
        skip: 'CAPTURE_PAIRING_PETS=true');
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('localized post-pairing pet states at source size',
      (tester) async {
    final boundary = GlobalKey();
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [], rpc: (_, __) async => {'group_id': 'g'});
    final now = DateTime(2026, 9, 15);
    final pet = Pet(
        id: 'p',
        name: '크레 이름',
        speciesId: 'crested-gecko',
        speciesName: '크레스티드 게코',
        sex: 'female',
        morph: '아잔틱 릴리 화이트',
        weight: 21,
        createdAt: now,
        updatedAt: now);

    ManagementInventory inventory(
            {required bool selected, required bool empty}) =>
        ManagementInventory(groups: const [
          ManagementGroup(id: 'g', name: '사육 환경 1')
        ], items: [
          if (!empty)
            ManagementItem(
                key: const ManagementKey(kind: ManagementKind.pet, id: 'p'),
                name: '크레 이름',
                groupId: selected ? 'g' : null,
                subtitle: '아잔틱 릴리 화이트'),
          if (!empty)
            const ManagementItem(
                key: ManagementKey(kind: ManagementKind.pet, id: 'p2'),
                name: '둘째'),
          if (!empty)
            const ManagementItem(
                key: ManagementKey(kind: ManagementKind.pet, id: 'p3'),
                name: '셋째'),
        ]);

    Future<void> pump(
        {required bool selected, required bool empty, Size? size}) async {
      await tester.binding.setSurfaceSize(size ?? const Size(393, 852));
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          startLocale: const Locale('ko'),
          path: 'assets/l10n',
          assetLoader: const _PairingTranslations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey((selected, empty, size)),
                  overrides: [
                    managementInventoryProvider.overrideWith((ref) async =>
                        inventory(selected: selected, empty: empty)),
                    redesignGroupRepositoryProvider.overrideWith((ref) => repo),
                    pairingPetsProvider
                        .overrideWith((ref) => empty ? const [] : [pet]),
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => RepaintBoundary(
                          key: boundary,
                          child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  textScaler:
                                      TextScaler.linear(size == null ? 1 : 1.7),
                                  padding: const EdgeInsets.only(
                                      top: 62, bottom: 34)),
                              child: child!)),
                      home: const PairingPetSelectionScreen(groupId: 'g'))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/private/tmp/pairing-pet-$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await pump(selected: false, empty: false);
    await capture('unselected');
    await pump(selected: true, empty: false);
    await capture('selected');
    await pump(selected: false, empty: true);
    await capture('empty');
    await pump(selected: false, empty: false, size: const Size(320, 568));
    await capture('small');
    await pump(selected: false, empty: true, size: const Size(320, 568));
    await capture('small-empty');
  });
}
