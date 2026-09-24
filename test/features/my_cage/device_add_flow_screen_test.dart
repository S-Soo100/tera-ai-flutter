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
import 'device_add_flow_test.dart' show Gateway, device, camera;

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
                  PairTargetKind.device: const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  if (!single)
                    PairTargetKind.camera: const DeviceAddResult(
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
        PairTargetKind.camera: DeviceAddResult(
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
        PairTargetKind.camera: DeviceAddResult(
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
    testWidgets('사육장 등록 + 카메라 BLE 미확인 · ${reconnect.name}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final initial =
          DeviceAddState(step: DeviceAddStep.results, ssid: 'home', results: {
        PairTargetKind.device: const DeviceAddResult(
            candidate: device,
            outcome: DeviceAddOutcome.registered,
            registeredId: 'device-uuid',
            wifiConnected: true),
        PairTargetKind.camera: DeviceAddResult(
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
      PairTargetKind.device: DeviceAddResult(
          candidate: device,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'new-device',
          wifiConnected: true),
      PairTargetKind.camera: DeviceAddResult(
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
      PairTargetKind.device: DeviceAddResult(
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
          selected: {
            PairTargetKind.device: device,
            PairTargetKind.camera: camera
          },
          ssid: 'KT_GIGA_2G',
          results: step == DeviceAddStep.results
              ? {
                  PairTargetKind.device: const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  PairTargetKind.camera: const DeviceAddResult(
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
}
