import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/data/activity_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/activity_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/my_cre_activity_screen.dart';
import 'package:vivanaut/shared/widgets/redesign_tab_header.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? decoded =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : {};
  }
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_MYCRE')) {
    test('opt-in MyCre visual capture', () {}, skip: 'CAPTURE_MYCRE=true');
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
  testWidgets(
      '393px localized MyCre populated, lower content and empty captures',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final boundary = GlobalKey();
    final now = DateTime.parse('2026-09-15T03:00:00Z');
    Future<void> pump(Pet? pet, {bool linked = true}) async {
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          startLocale: const Locale('ko'),
          path: 'assets/l10n',
          assetLoader: const _Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey((pet?.id, linked)),
                  overrides: [
                    activityClockProvider
                        .overrideWith((ref) => Stream.value(now)),
                    activityDataProvider.overrideWith((ref, query) async =>
                        ActivityData(
                            intervals: [
                          for (var hour = 0; hour < 12; hour++)
                            ActivityInterval(
                                cameraId: 'a',
                                startUtc: DateTime.utc(2026, 9, 14, 15 + hour),
                                endUtc: DateTime.utc(2026, 9, 14, 15 + hour,
                                    (hour * 7 + 10) % 60)),
                        ]
                                .where((i) =>
                                    !i.startUtc
                                        .isBefore(query.window.startUtc) &&
                                    i.endUtc.isBefore(query.window.endUtc))
                                .toList())),
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
                                  padding: const EdgeInsets.only(top: 62)),
                              child: child!)),
                      home: MyCreActivityScreen(
                        userId: 'u',
                        pet: pet,
                        hasCameraConnection: linked,
                        assignments: [
                          ActivityAssignment(
                              cameraId: 'a', origin: ActivityOrigin.legacy)
                        ],
                        header: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: RedesignTabHeader(
                                choices: const [(id: 'p', label: '사육 환경 1')],
                                selectedId: 'p',
                                emptyLabel: '',
                                onSelected: (_) {})),
                        onAddPet: () {},
                        onEditPet: () {},
                        onConnectCamera: () {},
                      ))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await precacheImage(
            FigmaImages.petPlaceholder, boundary.currentContext!);
        await precacheImage(FigmaImages.emptyPet, boundary.currentContext!);
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/private/tmp/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await pump(Pet(
        id: 'p',
        name: '크랑이',
        speciesId: 's',
        speciesName: '크레스티드 게코',
        morph: '아잔틱 릴리 화이트',
        sex: 'female',
        weight: 21));
    await capture('mycre-populated');
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -480));
    await tester.pumpAndSettle();
    await capture('mycre-week');
    await pump(
        Pet(
            id: 'unlinked',
            name: '모모',
            speciesId: 's',
            speciesName: '크레스티드 게코'),
        linked: false);
    await capture('mycre-unlinked');
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('연결된 카메라에서 감지한 활동입니다. 카메라는 개체를 구별하지 않습니다.'), findsNothing);
    await capture('mycre-unlinked-week');
    await pump(null);
    await capture('mycre-empty');
  });
}
