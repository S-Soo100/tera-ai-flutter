import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/domain/push_consent_flow.dart';
import 'package:vivanaut/features/notification/presentation/push_pre_popup.dart';
import '../notification/notification_repository_test.dart'
    show notificationUser;
import 'device_add_flow_screen_test.dart' show Controller, Translations;
import 'device_add_flow_test.dart' show device, camera;

/// 사육장 기기 등록 직후 알림 권한 팝업(2026-09-18) — 실제 등록 흐름 화면에서
/// "결과 단계로 바뀌는 순간" 트리거를 검증한다(시뮬레이터엔 BLE 기기가 없음).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  const connecting = DeviceAddState(
      step: DeviceAddStep.connecting, candidates: [device, camera]);

  DeviceAddState results(Map<PairTargetKind, DeviceAddResult> r) =>
      DeviceAddState(
          step: DeviceAddStep.results,
          candidates: const [device, camera],
          results: r);

  const deviceRegistered = DeviceAddResult(
      candidate: device,
      outcome: DeviceAddOutcome.registered,
      registeredId: 'd');

  /// 흐름 화면을 connecting으로 띄운 뒤 [next]로 전환한다. 권한 흐름은 가짜.
  Future<({List<bool> requests, Set<PushTopic> asked})> run(
      WidgetTester tester, DeviceAddState next,
      {PushPermission permission = PushPermission.notDetermined,
      bool signedIn = true}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final requests = <bool>[];
    final asked = <PushTopic>{};
    final controller = Controller(connecting);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceAddFlowProvider('test')
                          .overrideWith((ref) => controller),
                      // 합류 카드 조회는 즉시 실패 → 합류 없이 팝업 단계로.
                      managementInventoryProvider
                          .overrideWith((ref) => throw StateError('offline')),
                      currentUserProvider.overrideWithValue(
                          signedIn ? notificationUser('a') : null),
                      pushConsentFlowProvider.overrideWithValue(PushConsentFlow(
                        currentPermission: () async => permission,
                        requestPermission: ({bool retry = false}) async =>
                            requests.add(retry),
                        setTopic: (_, __) async => fail('사육장 주제는 토글을 건드리지 않는다'),
                        isAsked: asked.contains,
                        markAsked: (t) async => asked.add(t),
                      )),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowScreen(flowKey: 'test'))))));
    await tester.pump();
    controller.state = next;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return (requests: requests, asked: asked);
  }

  final prompt = find.text('사육장 알림을 켜시겠습니까?');

  testWidgets('사육장 등록 성공 → 결과 화면 위에 팝업, 받기는 시스템 권한 요청', (tester) async {
    final r =
        await run(tester, results({PairTargetKind.device: deviceRegistered}));
    expect(prompt, findsOneWidget);
    await tester.tap(find.text('알림 받기'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(prompt, findsNothing);
    expect(r.requests, [false]);
    expect(r.asked, {PushTopic.device});
  });

  testWidgets('사육장+카메라 함께 등록해도 사육장이 성공이면 묻는다', (tester) async {
    await run(
        tester,
        results({
          PairTargetKind.device: deviceRegistered,
          PairTargetKind.camera: const DeviceAddResult(
              candidate: camera,
              outcome: DeviceAddOutcome.registered,
              registeredId: 'c'),
        }));
    expect(prompt, findsOneWidget);
  });

  testWidgets('받지 않기 → 닫기만(수신 거부 완료 없음)', (tester) async {
    final r = await run(
        tester, results({PairTargetKind.device: deviceRegistered}),
        permission: PushPermission.denied);
    await tester.tap(find.text('알림 받지 않기'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(prompt, findsNothing);
    expect(find.text('수신 거부 완료'), findsNothing);
    expect(r.requests, isEmpty);
  });

  testWidgets('카메라만 등록 → 사육장 팝업 없음', (tester) async {
    final r = await run(
        tester,
        results({
          PairTargetKind.camera: const DeviceAddResult(
              candidate: camera,
              outcome: DeviceAddOutcome.registered,
              registeredId: 'c'),
        }));
    expect(prompt, findsNothing);
    expect(r.asked, isEmpty);
  });

  testWidgets('사육장 등록 대기(미확인)면 묻지 않는다', (tester) async {
    await run(
        tester,
        results({
          PairTargetKind.device: const DeviceAddResult(
              candidate: device,
              outcome: DeviceAddOutcome.registrationPending,
              wifiConnected: true),
        }));
    expect(prompt, findsNothing);
  });

  testWidgets('시스템 알림이 이미 허용됐으면 묻지 않고 기회도 남긴다', (tester) async {
    final r = await run(
        tester, results({PairTargetKind.device: deviceRegistered}),
        permission: PushPermission.authorized);
    expect(prompt, findsNothing);
    expect(r.asked, isEmpty);
  });

  testWidgets('iOS(시스템 권한 미지원)는 묻지 않는다', (tester) async {
    await run(tester, results({PairTargetKind.device: deviceRegistered}),
        permission: PushPermission.unavailable);
    expect(prompt, findsNothing);
  });

  testWidgets('이미 물었던 기기는 다시 묻지 않는다', (tester) async {
    // 한 번 답한 뒤 같은 기록(asked)으로 두 번째 등록 흐름을 연다.
    final first =
        await run(tester, results({PairTargetKind.device: deviceRegistered}));
    await tester.tap(find.text('알림 받기'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(first.asked, {PushTopic.device});
    await tester.pumpWidget(const SizedBox());
    // 두 번째 흐름: 새 ProviderScope지만 기록은 영구 저장소 몫이라 isAsked로 흉내.
    final requests = <bool>[];
    final controller = Controller(connecting);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceAddFlowProvider('test')
                          .overrideWith((ref) => controller),
                      managementInventoryProvider
                          .overrideWith((ref) => throw StateError('offline')),
                      currentUserProvider
                          .overrideWithValue(notificationUser('a')),
                      pushConsentFlowProvider.overrideWithValue(PushConsentFlow(
                        currentPermission: () async =>
                            PushPermission.notDetermined,
                        requestPermission: ({bool retry = false}) async =>
                            requests.add(retry),
                        setTopic: (_, __) async {},
                        isAsked: first.asked.contains,
                        markAsked: (t) async => first.asked.add(t),
                      )),
                    ],
                    child: MaterialApp(
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowScreen(flowKey: 'test'))))));
    await tester.pump();
    controller.state = results({PairTargetKind.device: deviceRegistered});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(prompt, findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('로그아웃 상태면 묻지 않는다', (tester) async {
    await run(tester, results({PairTargetKind.device: deviceRegistered}),
        signedIn: false);
    expect(prompt, findsNothing);
  });
}
