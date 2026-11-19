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
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/wifi_access_point.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'device_add_flow_test.dart' show Gateway, device, camera;
import 'network_manage_screen_fixtures.dart';

class Translations extends AssetLoader {
  const Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? raw =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return raw is Map<String, Object?> ? raw : {};
  }
}

class Controller extends DeviceAddFlowController {
  Controller(DeviceAddState initial)
      : super(
            gateway: Gateway(),
            accountId: 'a',
            isCurrent: () => true,
            token: () => '',
            namePrefix: (_) => '기기',
            names: () async => [],
            confirm: (_, __) async => null,
            saveCredentials: (_, __) async {},
            readCredentials: () async => {},
            autoGroup: (_, __) async => 'group') {
    state = initial;
  }
  @override
  Future<void> scan() async {}

  /// 테스트가 진행 중 상태 변화를 흉내 낸다.
  void emit(DeviceAddState next) => state = next;
  int retries = 0;
  @override
  Future<void> continueAdding() async => retries++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });
  for (final (step, single) in [
    for (final step in DeviceAddStep.values) (step, false),
    (DeviceAddStep.results, true),
  ]) {
    testWidgets(
        '${step.name}${single ? ' single' : ''} narrow screen and large text fit without overflow',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final initial = DeviceAddState(
          step: step,
          candidates: [device, camera],
          ssid: 'A long WiFi network with spaces',
          networks: [
            const WifiAccessPoint(
                no: 1,
                ssid: 'A long network name with many words',
                rssi: -30,
                channel: 1)
          ],
          results: step == DeviceAddStep.results
              ? {
                  'physical-a': const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  if (!single)
                    'physical-b': const DeviceAddResult(
                        candidate: camera,
                        outcome: DeviceAddOutcome.registrationPending,
                        wifiConnected: true),
                }
              : {});
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey(step),
                  overrides: [
                    deviceAddAccountProvider.overrideWithValue('a'),
                    deviceAddFlowProvider('test')
                        .overrideWith((ref) => Controller(initial)),
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: const TextScaler.linear(1.7)),
                          child: child!),
                      home: const DeviceAddFlowScreen(flowKey: 'test'))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  // 이미 등록된 카메라의 Wi-Fi만 바꾼 결과(2026-09-21) — 도마뱀 등록·이어
  // 추가를 권하지 않고, 끝내 안 붙을 때만 새 카메라로 등록할 길을 연다.
  for (final reconnect in CameraReconnect.values) {
    testWidgets('Wi-Fi 변경 결과 · ${reconnect.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final initial =
          DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
        'physical-b': DeviceAddResult(
            candidate: camera,
            outcome: DeviceAddOutcome.wifiUpdated,
            registeredId: 'existing',
            wifiConnected: true,
            reconnect: reconnect),
      });
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        deviceAddAccountProvider.overrideWithValue('a'),
                        deviceAddFlowProvider('test')
                            .overrideWith((ref) => Controller(initial)),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  textScaler: const TextScaler.linear(1.7)),
                              child: child!),
                          home: const DeviceAddFlowScreen(flowKey: 'test'))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      // 끝내 안 붙었으면 "변경완료"라고 쓰지 않는다(2026-09-25).
      expect(
          find.byKey(Key(reconnect == CameraReconnect.missing
              ? 'device_add_wifi_missing'
              : 'device_add_wifi_updated')),
          findsOneWidget);
      expect(find.byKey(const Key('device_add_pet')), findsNothing);
      expect(find.byKey(const Key('device_add_continue_kind')), findsNothing);
      expect(find.byKey(const Key('device_add_register_new')),
          reconnect == CameraReconnect.missing ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  // BLE가 Wi-Fi 성공을 주지 않은 Wi-Fi 변경(2026-09-24) — 서버 last_seen_at
  // 확인 중엔 '확인 중', 끝내 안 붙으면 실패(다시 연결 + 새 카메라 등록).
  for (final reconnect in CameraReconnect.values) {
    testWidgets('BLE 미확인 Wi-Fi 변경 결과 · ${reconnect.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final initial =
          DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
        'physical-b': DeviceAddResult(
            candidate: camera,
            outcome: DeviceAddOutcome.wifiUpdated,
            registeredId: 'existing',
            wifiConnected: false,
            reconnect: reconnect),
      });
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        deviceAddAccountProvider.overrideWithValue('a'),
                        deviceAddFlowProvider('test')
                            .overrideWith((ref) => Controller(initial)),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          home: const DeviceAddFlowScreen(flowKey: 'test'))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final missing = reconnect == CameraReconnect.missing;
      expect(find.byKey(const Key('device_add_wifi_checking')),
          reconnect == CameraReconnect.waiting ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_wifi_failed')),
          missing ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_wifi_updated')),
          reconnect == CameraReconnect.online ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_retry_failed')),
          missing ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_register_new')),
          missing ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  // 사육장 등록 완료 + 카메라 BLE 미확인(첨부 스크린샷 사고) — 확인 중엔
  // '연결 실패'·다시 연결 버튼이 없고, 끝내 안 붙을 때만 나온다.
  for (final reconnect in [CameraReconnect.waiting, CameraReconnect.missing]) {
    testWidgets('사육장 등록 + 카메라 BLE 미확인 · ${reconnect.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final initial =
          DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
        'physical-a': const DeviceAddResult(
            candidate: device,
            outcome: DeviceAddOutcome.registered,
            registeredId: 'device-uuid',
            wifiConnected: true),
        'physical-b': DeviceAddResult(
            candidate: camera,
            outcome: DeviceAddOutcome.wifiUpdated,
            registeredId: 'existing',
            wifiConnected: false,
            reconnect: reconnect),
      });
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        deviceAddAccountProvider.overrideWithValue('a'),
                        deviceAddFlowProvider('test')
                            .overrideWith((ref) => Controller(initial)),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          home: const DeviceAddFlowScreen(flowKey: 'test'))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final missing = reconnect == CameraReconnect.missing;
      expect(find.textContaining('device_add_checking'.tr()),
          missing ? findsNothing : findsOneWidget);
      expect(find.textContaining('device_add_failed'.tr()),
          missing ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_retry_failed')),
          missing ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  // 등록을 마친 기기도 몇 분간 광고한다(2026-09-21) — 이 폰이 등록한 기기는
  // '이미 등록됨'으로 표시하고 아래로 내린다.
  testWidgets('이미 등록한 기기는 표시하고 목록 아래로 내린다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final initial = DeviceAddState(
        candidates: const [camera, device], registered: {camera.physicalId});
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceAddFlowProvider('test')
                          .overrideWith((ref) => Controller(initial)),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowScreen(flowKey: 'test'))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('이미 등록됨 · Wi-Fi만 변경'), findsOneWidget);
    expect(find.byKey(Key('device_add_registered_${device.physicalId}')),
        findsNothing);
    final cameraY = tester
        .getTopLeft(
            find.byKey(Key('device_add_candidate_${camera.physicalId}')))
        .dy;
    final deviceY = tester
        .getTopLeft(
            find.byKey(Key('device_add_candidate_${device.physicalId}')))
        .dy;
    expect(cameraY, greaterThan(deviceY));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  // 새 사육장 + Wi-Fi만 바꾼 카메라(2026-09-21) — 버튼이 '나중에 하기'만
  // 남던 문제. 새 사육장을 기존 사육 환경에 연결할 길을 연다.
  testWidgets('새 사육장과 Wi-Fi 변경 카메라가 섞이면 기존 환경 연결을 연다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    const initial =
        DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
      'physical-a': DeviceAddResult(
          candidate: device,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'new-device',
          wifiConnected: true),
      'physical-b': DeviceAddResult(
          candidate: camera,
          outcome: DeviceAddOutcome.wifiUpdated,
          registeredId: 'existing-camera',
          wifiConnected: true,
          reconnect: CameraReconnect.online),
    });
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceAddFlowProvider('test')
                          .overrideWith((ref) => Controller(initial)),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowScreen(flowKey: 'test'))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
    expect(find.byKey(const Key('device_add_continue_kind')), findsNothing);
    expect(find.byKey(const Key('device_add_later')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  // 사육장 등록 대기(2026-09-21) — 실패 사유를 밝히고 다시 연결을 연다.
  testWidgets('사육장 등록 실패 사유와 다시 연결', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    const initial =
        DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
      'physical-a': DeviceAddResult(
          candidate: device,
          outcome: DeviceAddOutcome.registrationPending,
          wifiConnected: true,
          issue: DeviceRegistrationIssue.pairFailed,
          issueDetail: '401'),
    });
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceAddFlowProvider('test')
                          .overrideWith((ref) => Controller(initial)),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowScreen(flowKey: 'test'))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('기기가 서버 등록에 실패했어요 (401)'), findsOneWidget);
    expect(find.text('실패한 기기 다시 연결'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('opt-in capture measured selection/password/result screens',
      (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_PAIRING')) return;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    for (final step in [
      DeviceAddStep.scan,
      DeviceAddStep.credentials,
      DeviceAddStep.results
    ]) {
      final initial = DeviceAddState(
          step: step,
          candidates: [device, camera],
          selected: {'physical-a': device, 'physical-b': camera},
          ssid: 'KT_GIGA_2G',
          results: step == DeviceAddStep.results
              ? {
                  'physical-a': const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  'physical-b': const DeviceAddResult(
                      candidate: camera,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'c'),
                }
              : {},
          groupId: 'g');
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey(step),
                  overrides: [
                    deviceAddAccountProvider.overrideWithValue('a'),
                    deviceAddFlowProvider('test')
                        .overrideWith((ref) => Controller(initial))
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) =>
                          RepaintBoundary(key: boundary, child: child!),
                      home: MediaQuery(
                          data: const MediaQueryData(
                              size: Size(393, 852),
                              padding: EdgeInsets.only(top: 62, bottom: 34)),
                          child:
                              const DeviceAddFlowScreen(flowKey: 'test')))))));
      await tester.pumpAndSettle();
      Future<void> capture(String name) => tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/private/tmp/pairing-$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
      await capture(step.name);
      if (step == DeviceAddStep.credentials) {
        await tester.tap(find.text('비밀번호 기억하기'));
        await tester.pumpAndSettle();
        await capture('credentials-checked');
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  // [Wi-Fi 바꾸기](2026-09-28) — 대상 이름으로 찾고, 못 알아본 기기는 맞는지
  // 확인받고, 대상 신호가 안 오면 기기 선택부터 다시 한다.
  group('Wi-Fi 바꾸기 화면', () {
    const target = WifiChangeTarget(
        kind: PairTargetKind.device, id: 'row-3', name: '사육장 3');
    Future<void> pump(WidgetTester tester, DeviceAddState initial) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        deviceAddAccountProvider.overrideWithValue('a'),
                        deviceAddFlowProvider('test')
                            .overrideWith((ref) => Controller(initial)),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  textScaler: const TextScaler.linear(1.7)),
                              child: child!),
                          home: const DeviceAddFlowScreen(
                              flowKey: 'test', wifiTarget: target))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Figma 1912:5758 — 상단 제목만 '네트워크 변경'이고 본문은 기기 추가와
    // 같다. 안내문을 덧붙이지 않는다(2026-11-16 기획자 지적).
    testWidgets('상단 제목만 "네트워크 변경", 본문은 기기 추가와 같고 버튼은 "다음"', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              candidates: [device],
              matched: {'physical-a'},
              selected: {'physical-a': device}));
      expect(tester.takeException(), isNull);
      expect(find.text('네트워크 변경'), findsOneWidget);
      expect(find.text('추가할 기기 선택'), findsOneWidget);
      expect(find.text('사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요'), findsOneWidget);
      expect(find.text('사육장 3 찾기'), findsNothing);
      expect(find.byKey(const Key('device_wifi_matched_physical-a')),
          findsNothing);
      expect(find.byKey(const Key('device_add_scan_hint')), findsNothing);
      expect(find.text('다음'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // Figma 1912:5813 — 네트워크 선택도 제목·부제뿐, 2.4GHz 안내 없음.
    testWidgets('네트워크 선택에 덧붙인 안내가 없다', (tester) async {
      await pump(tester, const DeviceAddState(step: DeviceAddStep.networks));
      expect(tester.takeException(), isNull);
      expect(find.text('네트워크 변경'), findsOneWidget);
      expect(find.text('네트워크 선택'), findsOneWidget);
      expect(
          find.byKey(const Key('device_add_network_band_hint')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('못 알아본 기기를 고르면 대상이 맞는지 먼저 묻는다', (tester) async {
      await pump(tester, const DeviceAddState(candidates: [device]));
      await tester
          .tap(find.byKey(const Key('device_add_candidate_physical-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device_wifi_confirm_other_ok')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('device_wifi_confirm_other_ok')));
      await tester.pumpAndSettle();
      expect(find.text('다음'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('대상 행이 해제됐으면 목록 대신 안내만 보인다', (tester) async {
      await pump(
          tester, const DeviceAddState(candidates: [device], targetGone: true));
      expect(find.textContaining('더 이상 이 계정에 등록돼 있지 않아요'), findsOneWidget);
      expect(find.byKey(const Key('device_add_candidate_physical-a')),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('대상 신호가 안 오면 기기 확인 안내 + 다시 찾기', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              step: DeviceAddStep.results,
              ssid: 'home',
              results: {
                'physical-a': DeviceAddResult(
                    candidate: device,
                    outcome: DeviceAddOutcome.wifiUpdated,
                    registeredId: 'row-3',
                    wifiConnected: true,
                    reconnect: CameraReconnect.missing),
              }));
      expect(tester.takeException(), isNull);
      expect(find.text('사육장이 다시 연결되지 않았어요'), findsOneWidget);
      expect(find.textContaining('사육장 3의 신호가 오지 않아요'), findsOneWidget);
      expect(find.byKey(const Key('device_wifi_retry')), findsOneWidget);
      expect(find.text('새 사육장으로 등록'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('대상인지 확인 못 했으면 "변경완료"라고 단정하지 않는다', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              step: DeviceAddStep.results,
              ssid: 'home',
              results: {
                'physical-a': DeviceAddResult(
                    candidate: device,
                    outcome: DeviceAddOutcome.wifiUpdated,
                    registeredId: 'row-3',
                    wifiConnected: true,
                    reconnect: CameraReconnect.online,
                    unverified: true),
              }));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('device_wifi_unverified')), findsOneWidget);
      expect(find.text('사육장 Wi-Fi 변경완료'), findsNothing);
      expect(find.byKey(const Key('device_wifi_retry')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('사육장이 붙으면 사육장 문구로 완료를 알린다', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              step: DeviceAddStep.results,
              ssid: 'home',
              results: {
                'physical-a': DeviceAddResult(
                    candidate: device,
                    outcome: DeviceAddOutcome.wifiUpdated,
                    registeredId: 'row-3',
                    wifiConnected: true,
                    reconnect: CameraReconnect.online),
              }));
      expect(find.text('사육장 Wi-Fi 변경완료'), findsOneWidget);
      expect(find.text('사육장이 새 Wi-Fi로 다시 연결됐어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // 네트워크 관리(2026-11-19, Figma 1913:6570·7778) — 근처의 이 계정 기기 여러
  // 대에 Wi-Fi만. 목록·완료·기기별 결과.
  group('네트워크 관리 화면', () {
    Future<Controller> pump(WidgetTester tester, DeviceAddState initial,
        {Set<String> preferred = const {},
        Map<(PairTargetKind, String), String> names = const {},
        bool pushed = false}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final controller = Controller(initial);
      final screen = DeviceAddFlowScreen(
          flowKey: 'test',
          networkManage: NetworkManageRequest(preferredIds: preferred));
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        deviceAddAccountProvider.overrideWithValue('a'),
                        deviceWifiNameStoreProvider
                            .overrideWithValue(NmWifiNames(names)),
                        deviceAddFlowProvider('test')
                            .overrideWith((ref) => controller),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          home: pushed
                              ? Builder(
                                  builder: (context) => Scaffold(
                                      body: TextButton(
                                          key: const Key('open'),
                                          onPressed: () => Navigator.of(context)
                                              .push(MaterialPageRoute<void>(
                                                  builder: (_) => screen)),
                                          child: const Text('entry'))))
                              : screen)))));
      await tester.pump();
      if (pushed) {
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 300));
      return controller;
    }

    TextStyle styleOf(WidgetTester tester, Finder finder) =>
        tester.widget<Text>(finder).style!;
    Finder icon(String name, Finder within) => find.descendant(
        of: within,
        matching:
            find.byWidgetPredicate((w) => w is FigmaIcon && w.name == name));
    Finder row(DeviceAddCandidate c) =>
        find.byKey(Key('network_manage_row_${c.physicalId}'));

    testWidgets('네트워크 관리 목록: Figma 수치', (tester) async {
      await pump(tester, nmScan());
      expect(tester.takeException(), isNull);
      expect(find.text('네트워크 관리'), findsOneWidget);
      expect(find.text('추가할 기기 선택'), findsNothing);
      final title = styleOf(tester, find.text('네트워크에 연결할 기기 선택'));
      expect(title.fontSize, 18);
      expect(title.fontWeight, FontWeight.w600);
      expect(title.color, const Color(0xFF3C3C3C));
      final subtitle = styleOf(
          tester,
          find.text('사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요\n'
              'dBm이 낮은 기기는 네트워크 변경을 권장합니다'));
      expect(subtitle.fontSize, 14);
      expect(subtitle.fontWeight, FontWeight.w500);
      expect(subtitle.height! * 14, closeTo(20, 0.01));
      expect(subtitle.color, const Color(0xFF626262));
      final cam = row(nmCamera);
      final name = styleOf(
          tester, find.descendant(of: cam, matching: find.text('카메라 4')));
      expect(name.fontSize, 16);
      expect(name.fontWeight, FontWeight.w600);
      expect(name.color, const Color(0xFF3C3C3C));
      final hw = styleOf(tester,
          find.descendant(of: cam, matching: find.text('p4cam-0d1b47b4')));
      expect(hw.fontSize, 14);
      expect(hw.fontWeight, FontWeight.w500);
      expect(hw.color, const Color(0xFF949090));
      final ssidFinder =
          find.byKey(Key('network_manage_ssid_${nmCamera.physicalId}'));
      expect(tester.widget<Text>(ssidFinder).data, 'iptime');
      expect(tester.widget<Text>(ssidFinder).maxLines, 1);
      final ssid = styleOf(tester, ssidFinder);
      expect(ssid.fontSize, 16);
      expect(ssid.fontWeight, FontWeight.w600);
      expect(ssid.color, const Color(0xFF1E1E1E));
      final dbmFinder =
          find.byKey(Key('network_manage_dbm_${nmCamera.physicalId}'));
      expect(tester.widget<Text>(dbmFinder).data, '-78 dBm');
      final dbm = styleOf(tester, dbmFinder);
      expect(dbm.fontSize, 14);
      expect(dbm.fontWeight, FontWeight.w500);
      expect(dbm.color, const Color(0xFF949090));
      final bar = icon('redesign_v2/signal_cellular_alt_1_bar', cam);
      expect(bar, findsOneWidget);
      expect(tester.widget<FigmaIcon>(bar).size, 16);
      expect(tester.widget<FigmaIcon>(bar).color, const Color(0xFFB4AEAE));
      expect(
          icon('redesign_v2/check_box_outline_blank_400', cam), findsOneWidget);
      // 미선택은 [다시 스캔], 이 모드엔 선택 안내가 없다.
      expect(find.byKey(const Key('device_add_rescan')), findsOneWidget);
      expect(find.byKey(const Key('device_add_selection_hint')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('줄 순서는 미리 체크 → 오프라인 → 약한 순 → 이름', (tester) async {
      await pump(tester, nmScan(), preferred: {'d1'});
      double y(DeviceAddCandidate c) => tester.getTopLeft(row(c)).dy;
      // d1(미리 체크) → d2(오프라인) → c4(-78) → d3(신호 모름)
      expect(y(nmDevice), lessThan(y(nmOffline)));
      expect(y(nmOffline), lessThan(y(nmCamera)));
      expect(y(nmCamera), lessThan(y(nmBare)));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('이름 모르면 dBm만, 기억한 이름이 있으면 그 이름', (tester) async {
      await pump(tester, nmScan());
      expect(find.byKey(Key('network_manage_ssid_${nmDevice.physicalId}')),
          findsNothing);
      expect(find.byKey(Key('network_manage_dbm_${nmDevice.physicalId}')),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(tester, nmScan(),
          names: {(PairTargetKind.device, 'd1'): 'home_2.4G'});
      await tester.pump();
      expect(
          tester
              .widget<Text>(
                  find.byKey(Key('network_manage_ssid_${nmDevice.physicalId}')))
              .data,
          'home_2.4G');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('오프라인은 네트워크 연결 없음 한 줄', (tester) async {
      await pump(tester, nmScan());
      final off = row(nmOffline);
      final none = find.descendant(of: off, matching: find.text('네트워크 연결 없음'));
      expect(none, findsOneWidget);
      final style = styleOf(tester, none);
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, const Color(0xFF949090));
      expect(find.byKey(Key('network_manage_ssid_${nmOffline.physicalId}')),
          findsNothing);
      expect(find.byKey(Key('network_manage_dbm_${nmOffline.physicalId}')),
          findsNothing);
      // hw_id가 없으면 둘째 줄이 없다.
      expect(find.descendant(of: off, matching: find.byType(Text)),
          findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // Figma 1913:6570 — 체크는 줄마다 오른쪽 끝(x341), 오프라인 줄도 같다.
    testWidgets('체크는 모든 줄에서 같은 오른쪽 끝', (tester) async {
      await pump(tester, nmScan());
      double checkRight(DeviceAddCandidate c) => tester
          .getRect(find
              .descendant(of: row(c), matching: find.byType(FigmaIcon))
              .last)
          .right;
      final rights = {
        for (final c in [nmCamera, nmDevice, nmOffline, nmBare])
          checkRight(c).roundToDouble()
      };
      expect(rights, hasLength(1), reason: '$rights');
      expect(tester.getRect(row(nmOffline)).right - rights.single, 16);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('rssi·이름 둘 다 없으면 오른쪽 비움', (tester) async {
      await pump(tester, nmScan());
      final bare = row(nmBare);
      expect(find.byKey(Key('network_manage_ssid_${nmBare.physicalId}')),
          findsNothing);
      expect(find.byKey(Key('network_manage_dbm_${nmBare.physicalId}')),
          findsNothing);
      expect(find.descendant(of: bare, matching: find.text('네트워크 연결 없음')),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('CTA는 실제 체크 수', (tester) async {
      await pump(
          tester,
          nmScan(selected: {
            nmCamera.physicalId: nmCamera,
            nmDevice.physicalId: nmDevice,
            nmBare.physicalId: nmBare,
          }));
      expect(find.text('기기 3개 네트워크 연결'), findsOneWidget);
      expect(find.byKey(const Key('device_add_selection_hint')), findsNothing);
      expect(icon('redesign_v2/check_box_400', row(nmCamera)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(tester, nmScan(selected: {nmCamera.physicalId: nmCamera}));
      expect(find.text('기기 1개 네트워크 연결'), findsOneWidget);
      expect(find.byKey(const Key('device_add_selection_hint')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('줄을 누르면 고른다', (tester) async {
      final controller = await pump(tester, nmScan());
      var picked = <String>[];
      controller.addListener((s) => picked = s.selected.keys.toList());
      await tester.tap(row(nmCamera));
      await tester.pump();
      expect(picked, [nmCamera.physicalId]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('목록 조회 실패는 빈 상태보다 먼저 안내', (tester) async {
      await pump(tester,
          const DeviceAddState(networkManage: true, ownedLoadFailed: true));
      expect(find.text('기기 정보를 불러오지 못했어요. 다시 스캔해 주세요'), findsOneWidget);
      expect(find.text('device_add_no_devices'.tr()), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('네트워크 선택·비밀번호 단계도 상단 제목은 네트워크 관리', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              networkManage: true, step: DeviceAddStep.networks));
      expect(find.text('네트워크 관리'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(
          tester,
          const DeviceAddState(
              networkManage: true,
              step: DeviceAddStep.credentials,
              ssid: 'home'));
      expect(find.text('네트워크 관리'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('연결 중 n/N 표시', (tester) async {
      await pump(
          tester,
          const DeviceAddState(
              networkManage: true,
              step: DeviceAddStep.connecting,
              ssid: 'home',
              owned: nmOwned,
              selected: {
                'AA:00:00:00:00:01': nmCamera,
                'AA:00:00:00:00:02': nmDevice
              },
              activePhysicalId: 'AA:00:00:00:00:01',
              connectingIndex: 1,
              connectingTotal: 2));
      expect(
          find.descendant(
              of: find.byKey(const Key('device_add_connecting_overlay')),
              matching: find.text('1/2 · 카메라 4')),
          findsOneWidget);
      expect(find.text('네트워크 관리'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('모두 붙으면 완료 화면, [확인]은 pop', (tester) async {
      await pump(
          tester,
          nmResults({
            nmCamera.physicalId:
                nmUpdated(nmCamera, 'c4', CameraReconnect.online),
            nmDevice.physicalId:
                nmUpdated(nmDevice, 'd1', CameraReconnect.online),
          }),
          pushed: true);
      expect(tester.takeException(), isNull);
      final done = find.byKey(const Key('network_manage_done'));
      expect(done, findsOneWidget);
      expect(tester.widget<Text>(done).data, '네트워크 연결 완료');
      final style = styleOf(tester, done);
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, const Color(0xFF3C3C3C));
      final check = find.byWidgetPredicate(
          (w) => w is FigmaIcon && w.name == 'redesign_v2/check_circle');
      expect(check, findsOneWidget);
      expect(tester.widget<FigmaIcon>(check).size, 64);
      // 체크 아래 24에 제목.
      expect(tester.getTopLeft(done).dy - tester.getBottomLeft(check).dy,
          closeTo(24, 0.5));
      expect(find.text('새 기기로 등록'), findsNothing);
      expect(find.byKey(const Key('device_wifi_retry')), findsNothing);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('entry'), findsOneWidget);
      expect(done, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('하나라도 안 붙으면 기기별 결과', (tester) async {
      final controller = await pump(
          tester,
          nmResults({
            nmCamera.physicalId:
                nmUpdated(nmCamera, 'c4', CameraReconnect.online),
            nmDevice.physicalId:
                nmUpdated(nmDevice, 'd1', CameraReconnect.missing),
          }));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('network_manage_done')), findsNothing);
      final cam =
          find.byKey(Key('network_manage_result_${nmCamera.physicalId}'));
      final dev =
          find.byKey(Key('network_manage_result_${nmDevice.physicalId}'));
      expect(find.descendant(of: cam, matching: find.text('카메라 4')),
          findsOneWidget);
      expect(find.descendant(of: cam, matching: find.text('연결됐어요')),
          findsOneWidget);
      expect(find.descendant(of: dev, matching: find.text('사육장 1')),
          findsOneWidget);
      expect(find.descendant(of: dev, matching: find.text('신호가 오지 않아요')),
          findsOneWidget);
      expect(find.text('새 기기로 등록'), findsNothing);
      expect(find.text('새 사육장으로 등록'), findsNothing);
      expect(find.text('새 카메라로 등록'), findsNothing);
      expect(find.byKey(const Key('device_add_register_new')), findsNothing);
      expect(find.text('네트워크 관리'), findsOneWidget);
      final retry = find.byKey(const Key('device_wifi_retry'));
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(controller.retries, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // 진입점이 기기 상세·모달·라이브라 결과 화면 ✕는 홈이 아니라 들어온 화면으로.
    testWidgets('결과 화면 닫기(✕)는 들어온 화면으로 돌아간다', (tester) async {
      await pump(
          tester,
          nmResults({
            nmCamera.physicalId:
                nmUpdated(nmCamera, 'c4', CameraReconnect.online),
            nmDevice.physicalId:
                nmUpdated(nmDevice, 'd1', CameraReconnect.missing),
          }),
          pushed: true);
      expect(tester.takeException(), isNull);
      final close = find.byWidgetPredicate(
          (w) => w is FigmaIcon && w.name == FigmaIcons.close);
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('entry'), findsOneWidget);
      expect(find.byKey(Key('network_manage_result_${nmCamera.physicalId}')),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('결과 문구 8갈래', (tester) async {
      DeviceAddCandidate c(String id) => DeviceAddCandidate(
          physicalId: id, kind: PairTargetKind.device, name: 'x', rssi: -40);
      final cases = <DeviceAddResult, String>{
        nmUpdated(c('1'), 'r', CameraReconnect.waiting): '연결 확인 중',
        nmUpdated(c('2'), 'r', CameraReconnect.online): '연결됐어요',
        nmUpdated(c('3'), 'r', CameraReconnect.online, unverified: true):
            '연결돼 있어요 · 새 Wi-Fi인지 확인하지 못했어요',
        nmUpdated(c('4'), 'r', CameraReconnect.missing): '신호가 오지 않아요',
        DeviceAddResult(
                candidate: c('5'), outcome: DeviceAddOutcome.wifiFailed):
            'Wi-Fi에 연결하지 못했어요. 비밀번호를 확인해 주세요',
        DeviceAddResult(
            candidate: c('6'),
            outcome: DeviceAddOutcome.failed,
            failure: DeviceProvisionFailure.ble): '기기와 연결하지 못했어요',
        DeviceAddResult(
            candidate: c('7'),
            outcome: DeviceAddOutcome.failed,
            failure: DeviceProvisionFailure.notOwned): '이 계정 기기가 아니에요',
        DeviceAddResult(
                candidate: c('8'),
                outcome: DeviceAddOutcome.failed,
                failure: DeviceProvisionFailure.notChecked):
            '기기 정보를 확인하지 못해 건너뛰었어요',
      };
      await pump(tester,
          nmResults({for (final r in cases.keys) r.candidate.physicalId: r}));
      expect(tester.takeException(), isNull);
      for (final MapEntry(key: r, value: text) in cases.entries) {
        final line =
            find.byKey(Key('network_manage_result_${r.candidate.physicalId}'));
        await tester.ensureVisible(line);
        expect(find.descendant(of: line, matching: find.text(text)),
            findsOneWidget,
            reason: text);
      }
      // 확인 중인 기기가 있으면 [다시 찾기]를 숨긴다.
      expect(find.byKey(const Key('device_wifi_retry')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('확인 중이면 결과 목록에 확인 중, 다 붙으면 완료 화면으로 바뀐다', (tester) async {
      final controller = await pump(
          tester,
          nmResults({
            nmCamera.physicalId:
                nmUpdated(nmCamera, 'c4', CameraReconnect.online),
            nmDevice.physicalId:
                nmUpdated(nmDevice, 'd1', CameraReconnect.waiting),
          }));
      final dev =
          find.byKey(Key('network_manage_result_${nmDevice.physicalId}'));
      expect(find.descendant(of: dev, matching: find.text('연결 확인 중')),
          findsOneWidget);
      expect(find.byKey(const Key('device_wifi_retry')), findsNothing);
      expect(find.byKey(const Key('network_manage_done')), findsNothing);
      controller.emit(nmResults({
        nmCamera.physicalId: nmUpdated(nmCamera, 'c4', CameraReconnect.online),
        nmDevice.physicalId: nmUpdated(nmDevice, 'd1', CameraReconnect.online),
      }));
      await tester.pump();
      expect(find.byKey(const Key('network_manage_done')), findsOneWidget);
      expect(dev, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // 리뷰(2026-09-28): 종류별 키는 문자열로 이어 붙여 짝이 없으면 키가 그대로 보인다.
  test('종류별 결과 문구는 카메라·사육장 짝이 모두 ko.json에 있다', () {
    final Object? raw =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    final keys = (raw! as Map<String, Object?>).keys.toSet();
    for (final key in DeviceAddFlowScreenKeys.kindKeyed) {
      expect(keys, contains(key));
      expect(keys, contains('${key}_device'));
    }
  });
}
