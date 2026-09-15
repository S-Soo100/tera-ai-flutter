// P01~P18 after-fix captures. Opt-in only:
//   flutter test --no-pub --dart-define=CAPTURE_REMAINING=true \
//     test/design/remaining_ui_capture_test.dart
// Writes /private/tmp/remaining-after/<name>.png + .json (widget metrics).
// Values/thumbnails come from test fixtures, not devices or servers.
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
import 'dart:math' as math;
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/env_day.dart';
import 'package:vivanaut/shared/domain/week_range.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_screen.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_form_screen.dart';
import 'package:vivanaut/features/wiki/domain/morph_genetics.dart';
import 'package:vivanaut/features/wiki/presentation/wiki_providers.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

const _outDir = '/private/tmp/remaining-after';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  await _settle(tester);
  void repaint(RenderObject o) {
    o.markNeedsPaint();
    o.visitChildren(repaint);
  }

  repaint(boundary.currentContext!.findRenderObject()!);
  await tester.pump();
  final rows = <Map<String, dynamic>>[];
  void visit(Element e) {
    final r = e.renderObject;
    final w = e.widget;
    if (r is RenderBox &&
        r.hasSize &&
        (w is Text ||
            w is EditableText ||
            w is FilledButton ||
            w is FigmaIcon ||
            w is IconButton ||
            w is InkWell)) {
      final p = r.localToGlobal(Offset.zero);
      rows.add({
        'type': w.runtimeType.toString(),
        if (w is Text) 'text': w.data ?? w.textSpan?.toPlainText(),
        if (w is EditableText) 'text': w.controller.text,
        if (w is FigmaIcon) 'icon': w.name,
        if (w is InkWell && w.key != null) 'key': w.key.toString(),
        'rect': [p.dx, p.dy, r.size.width, r.size.height],
        if (w is Text) 'style': w.style.toString(),
        if (w is FilledButton) 'enabled': w.onPressed != null,
      });
    }
    e.visitChildren(visit);
  }

  boundary.currentContext!.visitChildElements(visit);
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    File('$_outDir/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    image.dispose();
  });
}

Widget shell(GlobalKey boundary, Widget home,
        {List<Override> overrides = const []}) =>
    ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
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
                    home: home))));

void main() {
  if (!const bool.fromEnvironment('CAPTURE_REMAINING')) {
    test('opt-in remaining UI captures', () {},
        skip: 'CAPTURE_REMAINING=true');
    return;
  }
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

  testWidgets('P01 morph search captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(
        boundary, PetFormScreen(original: null, onSave: (_, __) async {}),
        overrides: [
          morphDataProvider('crested-gecko').overrideWith((ref) async =>
              MorphGeneticsData.fromJson(jsonDecode(
                  File('assets/data/morphs/crested-gecko.json')
                      .readAsStringSync()))),
          petListProvider
              .overrideWith((ref) => PetListNotifier(_Pets(), null)),
        ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 안함').first);
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'p01-morph-list');
    for (final (name, query) in [
      ('p01-morph-search-b', 'ㅂ'),
      ('p01-morph-search-initial', 'ㄹ'),
      ('p01-morph-search-english', 'Lilly'),
      ('p01-morph-no-result', 'ㅇㄹㄴㅇㄹ'),
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await capture(tester, boundary, name);
    }
    await tester.tap(find.byKey(const ValueKey('pet-form-morph-clear')));
    await capture(tester, boundary, 'p01-morph-cleared');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P06 device management empty capture', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(boundary, const DeviceManagementScreen(),
        overrides: [
          managementInventoryProvider.overrideWith(
              (ref) async => ManagementInventory(groups: [], items: [])),
          redesignGroupRepositoryProvider.overrideWith((ref) =>
              RedesignGroupRepository(
                  loadRows: (_) async => [], rpc: (_, __) async => null)),
        ]));
    await capture(tester, boundary, 'p06-management-empty');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('P07 env detail captures', (tester) async {
    debugDisableShadows = false;
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final day = EnvDay.of(DateTime.now().subtract(const Duration(days: 1)));
    final week = WeekRange.containing(day.start);
    await tester.pumpWidget(shell(boundary, const EnvDetailScreen(),
        overrides: [
          currentDeviceIdProvider.overrideWith((ref) async => null),
          envDetailDayProvider.overrideWith((ref) => day),
          envDayBucketsProvider.overrideWith((ref) async => [
                for (var i = 0; i < 48; i++)
                  TelemetryBucket(
                      bucket: day.start.add(Duration(minutes: i * 30)),
                      sampleCount: 600,
                      tValidCount: 600,
                      hValidCount: 600,
                      tAvg: 27.5 + 2.2 * math.sin((i - 12) * math.pi / 48),
                      tMin: 26,
                      tMax: 32,
                      hAvg: 62 - 4 * math.sin((i - 12) * math.pi / 48),
                      hMin: 55,
                      hMax: 70)
              ]),
          envDayControlLogProvider.overrideWith((ref) async => [
                ControlLogEntry(
                    kind: MarkerKind.fan,
                    state: ControlLogState.on,
                    at: day.start.add(const Duration(hours: 8)),
                    temperature: 29.4,
                    humidity: 60.2),
                ControlLogEntry(
                    kind: MarkerKind.fan,
                    state: ControlLogState.off,
                    at: day.start.add(const Duration(hours: 9)),
                    temperature: 27.8,
                    humidity: 62,
                    deltaTemperature: -1.6,
                    deltaHumidity: 1.8),
                ControlLogEntry(
                    kind: MarkerKind.mist,
                    state: ControlLogState.ran,
                    at: day.start.add(const Duration(hours: 13)),
                    temperature: 28.8,
                    humidity: 61),
              ]),
          envWeekRowsProvider.overrideWith((ref) async => (
                temp: [
                  for (var i = 0; i < 7; i++)
                    DayMinMax(
                        day: week.days[i],
                        min: i == 3 || i == 4 ? 23 : 25.0,
                        max: i == 1 ? 33 : 30.0)
                ],
                humid: [
                  for (var i = 0; i < 7; i++)
                    DayMinMax(
                        day: week.days[i],
                        min: i == 5 ? 50 : 55.0,
                        max: i == 2 ? 72 : 65.0)
                ]
              )),
        ]));
    await capture(tester, boundary, 'p07-env-daily');
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -420));
    await capture(tester, boundary, 'p07-env-log');
    await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
    await capture(tester, boundary, 'p07-env-weekly');
    debugDisableShadows = true;
    await tester.binding.setSurfaceSize(null);
  });
}
