// UX-06 (2026-10-01): 휴대폰 글자 크기 설정이 앱에 반영된다(AppTextScaler =
// 1.0(Figma) × 시스템, 최대 2.0). 주요 화면을 시스템 배율 1.0·1.3·최대(2.0 상한)로
// 그려 넘침(RenderFlex overflow 등)이 없는지 본다. 393×852·Pretendard 기준.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_text_scaler.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/data/login_prefs_repository.dart';
import 'package:vivanaut/features/auth/presentation/email_verification_screen.dart';
import 'package:vivanaut/features/auth/presentation/login_screen.dart';
import 'package:vivanaut/features/auth/presentation/password_reset_screen.dart';
import 'package:vivanaut/features/auth/presentation/signup_screen.dart';
import 'package:vivanaut/features/community/presentation/clip_select_screen.dart';
import 'package:vivanaut/features/community/presentation/compose_screen.dart';
import 'package:vivanaut/features/home/domain/schedule_device.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/device_control_sheet.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/my_cre_activity_screen.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/profile/presentation/password_change_screen.dart';
import 'package:vivanaut/shared/widgets/offline_banner.dart';
import 'package:vivanaut/shared/widgets/viva_modal.dart';

import 'package:vivanaut/core/router/tab_branches.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/webrtc_live_view.dart';
import 'package:vivanaut/shared/domain/env_extremes.dart';
import 'package:vivanaut/shared/widgets/glass_dock.dart';

import 'package:vivanaut/features/home/presentation/env_detail_screen.dart';
import 'package:vivanaut/features/home/presentation/env_range_setting_screen.dart';
import 'package:vivanaut/features/home/presentation/temp_humid_setting_screen.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_screen.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_report_cards.dart';
import 'package:vivanaut/shared/domain/week_range.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_alert_card.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_range_bar.dart';
import 'package:vivanaut/features/profile/data/notification_preferences_repository.dart';
import 'package:vivanaut/features/profile/presentation/notification_settings_screen.dart';
import 'package:vivanaut/shared/widgets/viva_stepper.dart';

import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_photo_crop_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_quiet_time_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_saver_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_settings_screen.dart';

import '../features/home/control_sheet_fixtures.dart';
import '../features/my_cage/lcd_fixtures.dart';
import '../features/home/env_v4_screen_fixtures.dart';
import '../helpers/inert_live_controller.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Prefs implements LoginPrefsRepository {
  @override
  String? lastEmail = 'vivanaut@gmail.com';
  @override
  bool autoLogin = true;
  @override
  Future<void> save({required String email, required bool autoLogin}) async {}
}

final _draft = ComposeDraft(FavoriteClip(
    clipId: 'c1',
    cameraId: 'cam',
    startedAt: DateTime(2026, 9, 30),
    durationSec: 12,
    filePath: '',
    sizeBytes: 0,
    favoritedAt: DateTime(2026, 9, 30),
    ownerId: 'u'));

Future<void> _pump(WidgetTester tester, double system, Widget home,
    {List<Override> overrides = const [], bool settle = true}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
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
                  // lib/app.dart와 같은 조립 — 시스템 배율에 앱 기준(1.0)을 곱한다.
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(top: 62, bottom: 34),
                          textScaler: AppTextScaler(TextScaler.linear(system))),
                      child: child!),
                  home: home)))));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 끝나지 않는 반짝임(불러오는 중) — 몇 프레임만 흘린다.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await fonts.load();
  });

  test('배율 = 1.0(Figma) × 시스템, 최대 2.0', () {
    expect(
        const AppTextScaler(TextScaler.noScaling).scale(10), closeTo(10, 1e-9));
    expect(const AppTextScaler(TextScaler.linear(1.3)).scale(10),
        closeTo(13, 1e-9));
    expect(const AppTextScaler(TextScaler.linear(3)).scale(10), 20);
  });

  // 시스템 1.0(=Figma 그대로), 1.3, 2.0(=상한).
  for (final system in [1.0, 1.3, 2.0]) {
    group('시스템 글자 $system배', () {
      testWidgets('홈 — 라이브·온습도·제어 타일·탭바', (tester) async {
        final sets = [
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
              camera: TerraCamera(
                  id: 'c',
                  cameraId: 'p4cam',
                  name: '카메라 1',
                  isOnline: true,
                  enclosureId: 'g',
                  createdAt: DateTime.utc(2026)),
              pet: null)
        ];
        await _pump(
            tester,
            system,
            Scaffold(
                extendBody: true,
                body: const HomeScreen(),
                bottomNavigationBar: GlassDock(items: [
                  for (var i = 0; i < 4; i++)
                    GlassDockItem(
                        iconAsset: kHomeTabIconAssets[i],
                        label: kHomeTabLabelKeys[i].tr())
                ], currentIndex: 0, onSelected: (_) {})),
            overrides: [
              currentUserProvider.overrideWithValue(null),
              homeDeviceSetsProvider.overrideWith((ref) async => sets),
              currentDeviceIdProvider.overrideWith((ref) async => 'd'),
              moduleOnlineProvider('d').overrideWithValue(true),
              telemetryStreamProvider.overrideWith((ref, id) => Stream.value(
                  TelemetryReading(
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
                      tempMin: 27, tempMax: 36, humidMin: 27, humidMax: 70)),
              runningTimersProvider
                  .overrideWith((ref) async => const <RunningTimer>[]),
              webrtcLiveControllerProvider
                  .overrideWith((ref, id) => InertLiveController(ref, id)),
            ]);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      });

      testWidgets('로그인', (tester) async {
        await _pump(tester, system, const LoginScreen(),
            overrides: [loginPrefsProvider.overrideWithValue(_Prefs())]);
        expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
        expect(find.byKey(const ValueKey('login-forgot-password')),
            findsOneWidget);
      });

      testWidgets('회원가입', (tester) async {
        await _pump(tester, system, const SignupScreen());
      });

      testWidgets('이메일 인증', (tester) async {
        await _pump(
            tester, system, const EmailVerificationScreen(email: 'a@b.co'));
      });

      testWidgets('비밀번호 재설정', (tester) async {
        await _pump(
            tester, system, const PasswordResetScreen(initialEmail: 'a@b.co'));
      });

      testWidgets('비밀번호 변경', (tester) async {
        await _pump(tester, system, const PasswordChangeScreen());
      });

      testWidgets('마이크레 — 개체 없음·조회 실패', (tester) async {
        for (final load in [PetListLoad.ready, PetListLoad.failed]) {
          await _pump(
              tester,
              system,
              MyCreActivityScreen(
                header: const SizedBox(height: 56),
                userId: null,
                pet: null,
                petLoad: load,
                hasCameraConnection: false,
                assignments: const [],
                onAddPet: () {},
              ));
        }
      });

      testWidgets('글쓰기', (tester) async {
        await _pump(tester, system, ComposeScreen(draft: _draft), overrides: [
          enclosureSetsProvider.overrideWith((ref) async => const []),
          motionThumbnailProvider.overrideWith((ref, id) async => null),
        ]);
      });

      testWidgets('환기팬 제어 시트', (tester) async {
        await _pump(
            tester,
            system,
            const Scaffold(
                body: Align(
                    alignment: Alignment.bottomCenter,
                    child: DeviceControlSheet(
                        deviceId: kTestDeviceId,
                        device: ScheduleDevice.fan,
                        initialTab: DeviceControlTab.immediate))),
            overrides: controlOverrides(
                sent: [], telemetry: reading(fan: ActuatorState.off)));
      });

      // 자동 환기·분무 토글(계획 2026-11-05 Task 4, 출시 스위치 켠 화면) —
      // 설명 두 줄이 1.3배·상한에서 넘치지 않는다(Review Focus 4).
      for (final device in [ScheduleDevice.fan, ScheduleDevice.mist]) {
        testWidgets('${device.name} 제어 시트 · 자동 토글', (tester) async {
          await _pump(
              tester,
              system,
              Scaffold(
                  body: Align(
                      alignment: Alignment.bottomCenter,
                      child: DeviceControlSheet(
                          deviceId: kTestDeviceId,
                          device: device,
                          initialTab: DeviceControlTab.immediate))),
              overrides: controlOverrides(
                  sent: [],
                  telemetry: reading(fan: ActuatorState.off),
                  autoEnvReleased: true));
          expect(
              find.byKey(device == ScheduleDevice.fan
                  ? DeviceControlSheet.autoVentKey
                  : DeviceControlSheet.autoMistKey),
              findsOneWidget);
        });
      }

      testWidgets('확인 모달·오프라인 안내', (tester) async {
        await _pump(
            tester,
            system,
            Scaffold(
                body: Stack(children: [
              Builder(
                  builder: (c) => Center(
                      child: TextButton(
                          onPressed: () => showVivaModal(c,
                              message: '작성 중인 글이 있어요',
                              detail: '나가면 입력한 내용이 사라져요.',
                              cancelLabel: '계속 작성',
                              confirmLabel: '나가기'),
                          child: const Text('open')))),
              Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: OfflineBanner(onRetry: () {})),
            ])));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('나가기'), findsOneWidget);
      });

      // v4 온습도 설정 묶음(Figma 1635:6166) — 온습도 설정(보정 켜짐 −2, S06).
      testWidgets('온습도 설정', (tester) async {
        await _pump(tester, system,
            const TempHumidSettingScreen(deviceId: kEnvV4DeviceId),
            overrides: envV4SettingOverrides());
        expect(
            find.byKey(TempHumidSettingScreen.offsetValueKey), findsOneWidget);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      });

      // 보정값 설정(S16) — 저장값 빼기 2.0.
      testWidgets('보정값 설정', (tester) async {
        await _pump(
            tester, system, const TempOffsetScreen(deviceId: kEnvV4DeviceId),
            overrides: envV4OffsetOverrides());
        expect(find.byKey(TempOffsetScreen.sliderKey), findsOneWidget);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      });

      // 적정 온도·습도 — 바꾼 뒤(S10: 저장 + 변경 사항 취소)까지.
      for (final kind in EnvRangeKind.values) {
        testWidgets('적정 범위 설정 ${kind.name}', (tester) async {
          await _pump(tester, system,
              EnvRangeSettingScreen(deviceId: kEnvV4DeviceId, kind: kind),
              overrides: envV4SettingOverrides());
          await tester.tap(find.descendant(
              of: find.byKey(EnvRangeSettingScreen.minStepperKey),
              matching: find.byKey(VivaStepper.decreaseKey)));
          await tester.pumpAndSettle();
          expect(find.byKey(EnvRangeSettingScreen.discardKey), findsOneWidget);
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
        });
      }

      // 온습도 상세 — 범위 바 2줄 + 실시간 이탈 카드 2줄(A10).
      testWidgets('온습도 상세 — 범위 바·이탈 카드', (tester) async {
        await _pump(tester, system, const EnvDetailScreen(),
            overrides: envV4DetailOverrides());
        expect(find.byKey(EnvRangeBar.trackKey), findsNWidgets(2));
        await tester.scrollUntilVisible(find.byKey(EnvAlertCard.cardKey), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      });

      // 실시간 카드 세 줄 — 온도·습도·습기 사이클(A26·A36, 설명 두 줄).
      testWidgets('온습도 상세 — 이탈 카드 세 줄', (tester) async {
        await _pump(tester, system, const EnvDetailScreen(),
            overrides: envV4DetailOverrides(alerts: envV4CycleAlerts));
        await tester.scrollUntilVisible(find.byKey(EnvAlertCard.cardKey), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      });

      // 지난 날 일일 분석 — 구간 캡션 + 온도 2줄·습도 1줄 카드(A14·A15).
      testWidgets('온습도 상세 — 지난 날 일일 분석', (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await _pump(tester, system, const EnvDetailScreen(),
            overrides: envV4DetailOverrides(
                reports: FakeEnvReportRepository(
                    daily: envV4DailyReport(yesterday))));
        await tester.tap(find.byKey(EnvDetailScreen.dayPrevKey));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(EnvDetailScreen.dailyReportCaptionKey), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        final d = DateTime(yesterday.year, yesterday.month, yesterday.day);
        final n = DateTime(d.year, d.month, d.day + 1);
        expect(
            find.text(
                '${d.month}/${d.day} 08:00 ~ ${n.month}/${n.day} 08:00 분석'),
            findsOneWidget);
        await tester.scrollUntilVisible(
            find.byKey(EnvDailyReportCard.cardKey), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      });

      // 지난주 주간 분석 — 온도 카드 + 습도 안내·카드(A19·A20).
      testWidgets('온습도 상세 — 지난주 주간 분석', (tester) async {
        final monday = WeekRange.containing(DateTime.now()).previous.monday;
        await _pump(tester, system, const EnvDetailScreen(),
            overrides: envV4DetailOverrides(
                reports: FakeEnvReportRepository(
                    weekly: envV4WeeklyReport(monday))));
        await tester.tap(find.byKey(EnvDetailScreen.segmentWeeklyKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(EnvDetailScreen.weekPrevKey));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.humid)),
            200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      });

      // 알림 설정 — 온습도 이탈 알림 이동 행(S39).
      testWidgets('알림 설정', (tester) async {
        await _pump(tester, system, const NotificationSettingsScreen(),
            overrides: [
              currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
              notificationPreferencesRepositoryProvider
                  .overrideWithValue(_MemNotifPrefs()),
            ]);
        expect(
            find.byKey(NotificationSettingsScreen.envAlertKey), findsOneWidget);
      });

      // 모듈 화면 설정(Figma 1659:5964) — 글자가 가장 많은 상태: 예약 켜짐 +
      // 예약 시간 안 안내 + 오프라인 안내 + 긴 문구. 구 펌웨어는 업데이트 안내.
      for (final support in [LcdSupport.supported, LcdSupport.needsUpdate]) {
        testWidgets('모듈 화면 설정 ${support.name}', (tester) async {
          final rows = CommandRows();
          addTearDown(rows.close);
          await _pump(
              tester, system, const LcdSettingsScreen(deviceId: kLcdDevice),
              overrides: lcdOverrides(
                  repo: FakeLcdRepo(),
                  rows: rows,
                  link: Stream.value(lcdLink(
                      support: support,
                      quiet: LcdQuietWindow.defaults,
                      imageKey: 'k1')),
                  online: false,
                  now: DateTime.utc(2026, 11, 3, 14),
                  devices: const [
                    Device(
                        id: kLcdDevice,
                        ownerId: 'u1',
                        enclosureId: null,
                        name: '사육장 1',
                        hardwareId: '일이삼사오육칠팔구십일이삼사오육칠팔구십',
                        isOnline: false,
                        lastSeenAt: null),
                  ]));
          expect(find.byKey(LcdSettingsScreen.quietNoteKey), findsOneWidget);
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
        });
      }

      // 화면 꺼짐 시간(Figma 1659:6267) — 오프라인 안내까지.
      testWidgets('화면 꺼짐 시간', (tester) async {
        final rows = CommandRows();
        addTearDown(rows.close);
        await _pump(
            tester, system, const LcdQuietTimeScreen(deviceId: kLcdDevice),
            overrides: lcdOverrides(
                repo: FakeLcdRepo(),
                rows: rows,
                link: Stream.value(lcdLink(quiet: LcdQuietWindow.defaults)),
                online: false,
                now: DateTime.utc(2026, 11, 3, 3)));
        expect(find.byKey(LcdQuietTimeScreen.doneKey), findsOneWidget);
        expect(find.byKey(LcdQuietTimeScreen.offlineNoteKey), findsOneWidget);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      });

      // 순환 사진 설정(Figma 1659:6396 / 1660:6700) — 글자가 가장 많은
      // 상태: 사진 없음(사진 먼저 안내) + 오프라인 안내 + 칸 밖 값("1분 30초").
      // 사진 있음은 연필·미리보기 자리까지.
      for (final imageKey in [null, 'k1']) {
        testWidgets('순환 사진 설정 ${imageKey ?? '사진 없음'}', (tester) async {
          final rows = CommandRows();
          addTearDown(rows.close);
          await _pump(
              tester, system, const LcdSaverScreen(deviceId: kLcdDevice),
              overrides: lcdOverrides(
                  repo: FakeLcdRepo(),
                  rows: rows,
                  link: Stream.value(lcdLink(
                      imageKey: imageKey,
                      saver: LcdSaverSettings.defaults
                          .copyWith(enabled: true, imageSec: 90))),
                  online: false));
          expect(find.byKey(LcdSaverScreen.doneKey), findsOneWidget);
          expect(find.byKey(LcdSaverScreen.offlineNoteKey), findsOneWidget);
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -600));
          await tester.pumpAndSettle();
        });
      }

      // 사진 자르기(Figma 밖 — 공통 헤더·CTA만). 사진은 isolate에서 읽으니
      // 불러오는 중(반짝임) 모양으로 본다.
      testWidgets('사진 자르기', (tester) async {
        await _pump(
            tester,
            system,
            LcdPhotoCropScreen(
                source: img.encodeJpg(img.Image(width: 50, height: 40))),
            settle: false);
        expect(find.text('사진 자르기'), findsOneWidget);
        expect(find.byKey(LcdPhotoCropScreen.doneKey), findsOneWidget);
      });

      // 카메라 오프라인 안내(Figma 1525:10689) — 홈·카메라 탭 면(369:271)과
      // 확대 세로 면(4:3). 낮은 면은 안에서 스크롤, 버튼 라벨은 한 줄 축소.
      for (final size in [const Size(369, 271), const Size(369, 276.75)]) {
        testWidgets('라이브 면 — 카메라 오프라인 안내 ${size.height}', (tester) async {
          await _pump(
              tester,
              system,
              Scaffold(
                  body: Center(
                      child: SizedBox.fromSize(
                          size: size,
                          child: const WebRtcLiveView(cameraUuid: 'c')))),
              overrides: [
                camerasProvider.overrideWith((ref) => Stream.value([
                      TerraCamera(
                          id: 'c',
                          cameraId: 'p4cam',
                          name: '카메라 10',
                          isOnline: false,
                          createdAt: DateTime.utc(2026))
                    ])),
                webrtcLiveControllerProvider
                    .overrideWith((ref, id) => OfflineLiveController(ref, id)),
              ]);
          expect(find.text('카메라 재연결'), findsOneWidget);
          expect(find.text('네트워크 변경'), findsOneWidget);
        });
      }

      // 실시간 녹화 세로 목록(Figma 1523:5049) — 줄 높이 40은 최소, 알약은
      // 200까지 늘어난 뒤 말줄임.
      for (final online in [true, false]) {
        testWidgets('라이브 확대 — 녹화·회전·전원 목록 (온라인 $online)', (tester) async {
          await _pump(
              tester, system, const CameraLiveFullscreenScreen(cameraId: 'c'),
              overrides: [
                currentUserProvider.overrideWithValue(null),
                camerasProvider.overrideWith((ref) => Stream.value([
                      TerraCamera(
                          id: 'c',
                          cameraId: 'p4cam',
                          name: '카메라 10',
                          firmwareVer: 'fb2-p4 0.2.0-20260928',
                          isOnline: online,
                          createdAt: DateTime.utc(2026))
                    ])),
                sysHealthProvider(cameraRebootTarget('c'))
                    .overrideWith((ref) => const Stream.empty()),
                webrtcLiveControllerProvider.overrideWith((ref, id) => online
                    ? _StreamingLive(ref, id)
                    : InertLiveController(ref, id)),
              ]);
          expect(find.text('실시간 녹화'), findsOneWidget);
          expect(find.text('카메라 180° 회전'), findsOneWidget);
          expect(find.text('녹화 시작'), findsOneWidget);
        });
      }
    });
  }
}

class _StreamingRenderer extends RTCVideoRenderer {
  @override
  Future<void> initialize() async {}
  @override
  set srcObject(MediaStream? stream) {}
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _StreamingLive extends WebRtcLiveController {
  _StreamingLive(super.ref, super.cameraUuid) {
    state = WebRtcLiveState(
        phase: WebRtcLivePhase.streaming, renderer: _StreamingRenderer());
  }
}

class _MemNotifPrefs implements NotificationPreferencesRepository {
  NotificationPrefs prefs = const NotificationPrefs();
  @override
  NotificationPrefs load() => prefs;
  @override
  Future<void> save(NotificationPrefs p) async => prefs = p;
}
