// Opt-in source-size captures. No camera connection, account rows or commands.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/router/tab_branches.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/shared/domain/env_extremes.dart';
import 'package:vivanaut/shared/widgets/glass_dock.dart';
import '../helpers/inert_live_controller.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_HOME')) {
    test('opt-in Home captures', () {}, skip: 'CAPTURE_HOME=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final path in [
      'assets/icons/redesign_v2/discover_tune.svg',
      'assets/icons/person.svg'
    ]) {
      final picture = await vg.loadPicture(SvgAssetLoader(path), null);
      picture.picture.dispose();
    }
    final fonts = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await fonts.load();
  });
  testWidgets('393px Home states and white scrolled header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final boundary = GlobalKey();
    for (final mode in ['linked', 'linked', 'device', 'empty']) {
      final sets = <EnclosureSet>[
        if (mode != 'empty')
          EnclosureSet(
              enclosure: Enclosure(
                  id: 'g', name: '사육 환경 1', createdAt: DateTime.utc(2026)),
              device: const Device(
                  id: 'd',
                  ownerId: 'u',
                  enclosureId: 'g',
                  name: '사육장 1',
                  hardwareId: 'viva-iot-0001',
                  isOnline: true,
                  lastSeenAt: null),
              camera: mode == 'linked'
                  ? TerraCamera(
                      id: 'c',
                      cameraId: 'p4cam',
                      name: '카메라 1',
                      isOnline: true,
                      enclosureId: 'g',
                      createdAt: DateTime.utc(2026))
                  : null,
              pet: null)
      ];
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const _Loader(),
          startLocale: const Locale('ko'),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: UniqueKey(),
                  overrides: [
                    currentUserProvider.overrideWithValue(null),
                    homeDeviceSetsProvider.overrideWith((ref) async => sets),
                    currentDeviceIdProvider.overrideWith(
                        (ref) async => mode == 'empty' ? null : 'd'),
                    moduleOnlineProvider('d').overrideWithValue(true),
                    telemetryStreamProvider.overrideWith((ref, id) =>
                        Stream.value(TelemetryReading(
                            deviceId: id,
                            tA: 32,
                            hA: 60,
                            aOk: true,
                            tB: null,
                            hB: null,
                            bOk: false,
                            relay: ActuatorState.off,
                            fan: ActuatorState.on,
                            fan2: ActuatorState.on,
                            led: ActuatorState.on,
                            ledBrightness: 50,
                            heaterState: ActuatorState.off,
                            heaterLocked: false,
                            ts: DateTime.now()))),
                    homeTodayExtremesProvider.overrideWith((ref) async =>
                        const EnvExtremes(
                            tempMin: 27,
                            tempMax: 36,
                            humidMin: 27,
                            humidMax: 70)),
                    runningTimersProvider
                        .overrideWith((ref) async => const <RunningTimer>[]),
                    webrtcLiveControllerProvider.overrideWith(
                        (ref, id) => InertLiveController(ref, id)),
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
                                  padding: const EdgeInsets.only(
                                      top: 62, bottom: 26)),
                              child: child!)),
                      home: Scaffold(
                          extendBody: true,
                          body: const HomeScreen(),
                          bottomNavigationBar: GlassDock(items: [
                            for (var i = 0; i < 4; i++)
                              GlassDockItem(
                                  iconAsset: kHomeTabIconAssets[i],
                                  label: kHomeTabLabelKeys[i].tr())
                          ], currentIndex: 0, onSelected: (_) {})))))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final r = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final im = await r.toImage();
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          await File('/private/tmp/redesign-home-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          im.dispose();
        });
      }

      await capture(mode);
      if (mode == 'linked') {
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
        await capture('scrolled');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
