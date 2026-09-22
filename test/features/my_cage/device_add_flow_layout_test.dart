import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import 'device_add_flow_test.dart' show Gateway, device, camera;

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? raw =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return raw is Map<String, Object?> ? raw : {};
  }
}

class _Controller extends DeviceAddFlowController {
  _Controller(DeviceAddState initial)
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
  int scans = 0;
  int networkLoads = 0;
  @override
  Future<void> scan() async {
    scans++;
  }

  @override
  Future<void> loadNetworks() async {
    networkLoads++;
  }

  void set(DeviceAddState next) => state = next;
}

/// Figma 971:1837 / 990:7601 / 990:11450 / 982:3103 / 982:3174 / 982:3604 /
/// 982:3643 실측 좌표. 상 62 / 하 34 SafeArea, 393×852.
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

  Future<_Controller> pump(WidgetTester tester, DeviceAddState initial,
      {double keyboard = 0, List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final controller = _Controller(initial);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const _Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                key: ValueKey(initial),
                overrides: [
                  deviceAddAccountProvider.overrideWithValue('a'),
                  deviceAddFlowProvider('t').overrideWith((ref) => controller),
                  ...overrides,
                ],
                child: MaterialApp(
                    theme: AppTheme.light,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            // 키보드가 뜨면 iOS는 하단 안전영역을 0으로 준다.
                            padding: EdgeInsets.only(
                                top: 62, bottom: keyboard > 0 ? 0 : 34),
                            viewInsets: EdgeInsets.only(bottom: keyboard)),
                        child: child!),
                    home: const DeviceAddFlowScreen(flowKey: 't'))))));
    // 스피너가 도는 상태(스캔 중·연결 중)는 settle되지 않으므로 명시 pump.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

  testWidgets('scan: rescan CTA at y696, N개 추가 after select, hint at y667',
      (tester) async {
    final c =
        await pump(tester, const DeviceAddState(candidates: [device, camera]));
    final rescan = rectOf(tester, const Key('device_add_rescan'));
    expect(rescan, const Rect.fromLTWH(12, 696, 369, 56));
    expect(
        find.descendant(
            of: find.byKey(const Key('device_add_rescan')),
            matching: find.byWidgetPredicate(
                (w) => w is FigmaIcon && w.name == 'redesign_v2/restart_alt')),
        findsOneWidget);
    expect(find.byKey(const Key('device_add_selection_hint')), findsNothing);
    expect(find.byKey(const Key('device_add_continue')), findsNothing);
    // 제목 y122 18/600, 부제 y151, 목록 y184 행 64.
    final title = tester.getRect(find.text('추가할 기기 선택'));
    expect(title.topLeft, const Offset(24, 122));
    expect(tester.getRect(find.text('사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요')).top, 151);
    final first = find.byKey(Key('device_add_candidate_${device.physicalId}'));
    expect(tester.getRect(first).top, 184);
    expect(tester.getRect(first).height, 64);

    await tester.tap(first);
    await tester.pump();
    expect(find.byKey(const Key('device_add_rescan')), findsNothing);
    final cta = rectOf(tester, const Key('device_add_continue'));
    expect(cta, const Rect.fromLTWH(12, 696, 369, 56));
    expect(find.text('기기 1개 추가'), findsOneWidget);
    final hint = rectOf(tester, const Key('device_add_selection_hint'));
    expect(hint.top, closeTo(667, 0.5));
    await tester.tap(find.byKey(const Key('device_add_continue')));
    expect(c.networkLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan: no devices shows grey box, busy shows title spinner',
      (tester) async {
    final c = await pump(tester, const DeviceAddState());
    final box = rectOf(tester, const Key('device_add_empty_box'));
    expect(box, const Rect.fromLTWH(12, 184, 369, 64));
    expect(find.text('검색된 기기가 없습니다'), findsOneWidget);
    final before = c.scans; // 진입 시 자동 스캔 1회는 별도.
    await tester.tap(find.byKey(const Key('device_add_rescan')));
    expect(c.scans, before + 1);
    c.set(const DeviceAddState(busy: true));
    await tester.pump();
    expect(find.text('주변 기기를 검색하고 있어요'), findsOneWidget);
    final spinner = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == 'redesign_v2/progress_activity');
    expect(tester.getSize(spinner), const Size(20, 20));
    expect(tester.getRect(spinner).top, closeTo(122.5, 0.5));
    // 스캔 중 CTA 비활성.
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: find.byKey(const Key('device_add_rescan')),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('networks: rows 65, rescan 696 + manual 752, close in top bar',
      (tester) async {
    await pump(
        tester,
        const DeviceAddState(step: DeviceAddStep.networks, networks: [
          WifiAccessPoint(no: 1, ssid: 'iptime_office', rssi: -30, channel: 1),
          WifiAccessPoint(no: 2, ssid: 'SK_WIFIGIGA88', rssi: -50, channel: 6),
        ]));
    expect(rectOf(tester, const Key('device_add_network_rescan')),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(rectOf(tester, const Key('device_add_manual')).top, 752);
    expect(tester.getRect(find.text('iptime_office')).topLeft.dx, 28);
    final row0 = find.byKey(const Key('device_add_network_iptime_office'));
    final row1 = find.byKey(const Key('device_add_network_SK_WIFIGIGA88'));
    expect(tester.getRect(row0).top, 184);
    expect(tester.getRect(row0).height, 65);
    expect(tester.getRect(row1).top, closeTo(250, 0.5));
    expect(find.byKey(const Key('management_top_close')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'credentials: field 184/65, remember 261, CTA 696 or above keyboard',
      (tester) async {
    await pump(tester,
        const DeviceAddState(step: DeviceAddStep.credentials, ssid: 'home'));
    final field = tester.getRect(find
        .ancestor(of: find.byType(TextField), matching: find.byType(Container))
        .first);
    expect(field.top, closeTo(184, 0.5));
    expect(field.height, 65);
    final check = find.byWidgetPredicate((w) =>
        w is FigmaIcon && w.name == 'redesign_v2/check_box_outline_blank_300');
    expect(tester.getRect(check).topLeft, const Offset(20, 261));
    expect(tester.getRect(find.text('비밀번호 기억하기')).left, 48);
    // 눈 24 그림 x340 (원본 982:3174).
    final eye = find.descendant(
        of: find.byKey(const Key('device_add_eye')),
        matching: find.byType(FigmaIcon));
    expect(tester.getRect(eye).left, closeTo(340, 1.5)); // 48 터치면 가운데 정렬
    expect(rectOf(tester, const Key('device_add_connect')),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(find.text('다른 네트워크 선택'), findsNothing);
    expect(find.byKey(const Key('management_top_close')), findsOneWidget);

    await pump(tester,
        const DeviceAddState(step: DeviceAddStep.credentials, ssid: 'home'),
        keyboard: 287);
    // Figma 982:3174 — 키보드(565) 위 43 → CTA 466.
    expect(
        rectOf(tester, const Key('device_add_connect')).top, closeTo(466, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('connecting: dim overlay blocks input and shows 62 spinner',
      (tester) async {
    await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'));
    final overlay = find.byKey(const Key('device_add_connecting_overlay'));
    expect(overlay, findsOneWidget);
    expect(tester.getSize(overlay), const Size(393, 852));
    final spinner = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == 'redesign_v2/progress_activity');
    expect(tester.getSize(spinner), const Size(62, 62));
    expect(tester.getCenter(spinner).dx, 196.5);
    expect(find.text('WiFi 연결 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('results: check 64 at y308, title y396, CTA 696 + later 752',
      (tester) async {
    await pump(
        tester,
        const DeviceAddState(step: DeviceAddStep.results, results: {
          PairTargetKind.device: DeviceAddResult(
              candidate: device,
              outcome: DeviceAddOutcome.registered,
              registeredId: 'd'),
        }));
    final icon = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == 'redesign_v2/check_circle');
    expect(tester.getRect(icon), const Rect.fromLTWH(164.5, 308, 64, 64));
    expect(tester.getRect(find.text('사육장 추가완료')).top, 396);
    expect(
        tester.getRect(find.text('이어서 카메라를 추가해 주세요')).top, closeTo(425, 0.5));
    expect(rectOf(tester, const Key('device_add_continue_kind')),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(rectOf(tester, const Key('device_add_later')).top, 752);
    expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wifi failure returns to the password form with a modal',
      (tester) async {
    final c = await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'));
    c.set(const DeviceAddState(
        step: DeviceAddStep.results,
        ssid: 'home',
        results: {
          PairTargetKind.device: DeviceAddResult(
              candidate: device, outcome: DeviceAddOutcome.wifiFailed),
        }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('device_add_error_modal')), findsOneWidget);
    expect(find.text('네트워크 비밀번호를 다시 확인해 주세요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('device_add_error_modal')), findsNothing);
    expect(find.byKey(const Key('device_add_connect')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// 사육장 하나만 있는 그룹 + 카메라 단독 성공 → 합류 카드(990:7508).
  List<Override> joinOverrides(List<Map<String, Object?>> rpcCalls,
          {bool withPet = false}) =>
      [
        managementInventoryProvider
            .overrideWith((ref) async => ManagementInventory(groups: const [
                  ManagementGroup(id: 'g1', name: '마뱀이네 집', number: 1)
                ], items: [
                  const ManagementItem(
                      key: ManagementKey(kind: ManagementKind.device, id: 'd1'),
                      name: 'viva-iot-ㅁㅁㅁㅁ',
                      groupId: 'g1'),
                  if (withPet)
                    const ManagementItem(
                        key: ManagementKey(kind: ManagementKind.pet, id: 'p1'),
                        name: '꼬꼬',
                        groupId: 'g1'),
                ])),
        redesignGroupRepositoryProvider
            .overrideWith((ref) => RedesignGroupRepository(
                loadRows: (_) async => [],
                rpc: (name, params) async {
                  rpcCalls.add({'name': name, ...params});
                  return {'group_id': 'g1'};
                })),
      ];

  Future<_Controller> pumpJoin(
      WidgetTester tester, List<Map<String, Object?>> rpcCalls) async {
    final c = await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'),
        overrides: joinOverrides(rpcCalls));
    c.set(const DeviceAddState(step: DeviceAddStep.results, results: {
      PairTargetKind.camera: DeviceAddResult(
          candidate: camera,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'c1'),
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('join card: 카메라 단독 성공 + 사육장 그룹 1개 → 990:7508 좌표, 함께 사용하기 = 그룹 저장',
      (tester) async {
    final rpc = <Map<String, Object?>>[];
    await pumpJoin(tester, rpc);
    expect(tester.getRect(find.text('연결한 사육장과 함께 사용할까요?')).top, 266);
    expect(tester.getRect(find.text('카메라로 사육장을 보며 제어할 수 있어요')).top,
        closeTo(295, 0.5));
    expect(tester.getRect(find.text('viva-iot-ㅁㅁㅁㅁ')).right, 353);
    expect(tester.getRect(find.text('FB2_P4_CAM')).right, 353);
    expect(tester.getRect(find.text('사육장')).left, 88);
    expect(rectOf(tester, const Key('device_add_join')),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(rectOf(tester, const Key('device_add_separate')).top, 752);
    await tester.tap(find.byKey(const Key('device_add_join')));
    await tester.pumpAndSettle();
    expect(rpc, hasLength(1));
    expect(rpc.single['name'], 'redesign_save_group_v1');
    expect(rpc.single['p_group_id'], 'g1');
    expect(rpc.single['p_device_id'], 'd1');
    expect(rpc.single['p_camera_id'], 'c1');
    // 결과 화면으로 돌아오면 개체 선택 CTA, 기존 기기 연결/이어서 추가는 없다.
    expect(find.byKey(const Key('device_add_pet')), findsOneWidget);
    expect(find.byKey(const Key('device_add_link_existing')), findsNothing);
    expect(find.byKey(const Key('device_add_continue_kind')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('join card: 따로 사용하기 → 저장 없이 기존 결과 화면', (tester) async {
    final rpc = <Map<String, Object?>>[];
    await pumpJoin(tester, rpc);
    await tester.tap(find.byKey(const Key('device_add_separate')));
    await tester.pumpAndSettle();
    expect(rpc, isEmpty);
    expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
    expect(find.byKey(const Key('device_add_continue_kind')), findsOneWidget);
    expect(find.byKey(const Key('device_add_pet')), findsNothing);
  });

  testWidgets('join card: 후보 그룹이 없으면 카드 없이 결과 화면', (tester) async {
    final c = await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'),
        overrides: [
          managementInventoryProvider.overrideWith((ref) async =>
              ManagementInventory(groups: const [], items: const [])),
        ]);
    c.set(const DeviceAddState(step: DeviceAddStep.results, results: {
      PairTargetKind.camera: DeviceAddResult(
          candidate: camera,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'c1'),
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device_add_join')), findsNothing);
    expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
  });

  // 2026-09-22: 합류는 그 환경의 기존 멤버(도마뱀 포함)를 그대로 두고 새 기기만
  // 더한다. 도마뱀을 빼고 보내면 서버가 40001(무한 재시도)을 내고, 통과해도
  // 도마뱀이 환경에서 빠진다.
  testWidgets('join card: 도마뱀이 있는 그룹에 합류해도 도마뱀을 유지한다',
      (tester) async {
    final rpc = <Map<String, Object?>>[];
    var refreshed = 0;
    final c = await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'),
        overrides: [
          ...joinOverrides(rpc, withPet: true),
          managementMutationCompletedProvider
              .overrideWithValue(() => refreshed++),
        ]);
    c.set(const DeviceAddState(step: DeviceAddStep.results, results: {
      PairTargetKind.camera: DeviceAddResult(
          candidate: camera,
          outcome: DeviceAddOutcome.registered,
          registeredId: 'c1',
          registeredName: '카메라 3'),
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // 카드에는 BLE 광고 이름이 아니라 등록된 이름을 보인다.
    expect(find.text('카메라 3'), findsOneWidget);
    expect(find.text('FB2_P4_CAM'), findsNothing);
    await tester.tap(find.byKey(const Key('device_add_join')));
    await tester.pumpAndSettle();
    expect(rpc, hasLength(1));
    expect(rpc.single['p_pet_id'], 'p1');
    expect(rpc.single['p_device_id'], 'd1');
    expect(rpc.single['p_camera_id'], 'c1');
    expect(
        rpc.single['p_expected_members'],
        unorderedEquals([
          {'kind': 'device', 'id': 'd1', 'group_id': 'g1'},
          {'kind': 'pet', 'id': 'p1', 'group_id': 'g1'},
          {'kind': 'camera', 'id': 'c1', 'group_id': null},
        ]));
    // 홈·목록 갱신 신호.
    expect(refreshed, 1);
  });

  testWidgets('results: 자동 묶기 실패면 도마뱀 등록 안내 부제를 숨긴다', (tester) async {
    final c = await pump(tester,
        const DeviceAddState(step: DeviceAddStep.connecting, ssid: 'home'),
        overrides: joinOverrides([]));
    c.set(const DeviceAddState(
        step: DeviceAddStep.results,
        groupError: true,
        results: {
          PairTargetKind.device: DeviceAddResult(
              candidate: device,
              outcome: DeviceAddOutcome.registered,
              registeredId: 'd9'),
          PairTargetKind.camera: DeviceAddResult(
              candidate: camera,
              outcome: DeviceAddOutcome.registered,
              registeredId: 'c1'),
        }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('device_add_group_error'.tr()), findsOneWidget);
    expect(find.text('device_add_done_subtitle'.tr()), findsNothing);
  });
}
