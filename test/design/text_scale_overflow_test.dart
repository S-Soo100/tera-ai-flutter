// UX-06 (2026-10-01): 휴대폰 글자 크기 설정이 앱에 반영된다(AppTextScaler =
// 1.15 × 시스템, 최대 2.0). 주요 화면을 시스템 배율 1.0·1.3·최대(2.0 상한)로
// 그려 넘침(RenderFlex overflow 등)이 없는지 본다. 393×852·Pretendard 기준.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:vivanaut/shared/domain/env_extremes.dart';
import 'package:vivanaut/shared/widgets/glass_dock.dart';

import '../features/home/control_sheet_fixtures.dart';
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
    {List<Override> overrides = const []}) async {
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
                  // lib/app.dart와 같은 조립 — 시스템 배율에 앱 기준 1.15를 곱한다.
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(top: 62, bottom: 34),
                          textScaler:
                              AppTextScaler(TextScaler.linear(system))),
                      child: child!),
                  home: home)))));
  await tester.pumpAndSettle();
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

  test('배율 = 1.15 × 시스템, 최대 2.0', () {
    expect(const AppTextScaler(TextScaler.noScaling).scale(10),
        closeTo(11.5, 1e-9));
    expect(const AppTextScaler(TextScaler.linear(1.3)).scale(10),
        closeTo(14.95, 1e-9));
    expect(const AppTextScaler(TextScaler.linear(3)).scale(10), 20);
  });

  // 시스템 1.0(=지금 화면), 1.3, 1.74(=상한 2.0).
  for (final system in [1.0, 1.3, 1.74]) {
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
        await _pump(tester, system,
            const PasswordResetScreen(initialEmail: 'a@b.co'));
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
    });
  }
}
