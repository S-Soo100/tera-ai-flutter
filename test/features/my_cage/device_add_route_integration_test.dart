import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_add_registration_repository.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_route.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/domain/push_consent_flow.dart';
import 'package:vivanaut/features/notification/presentation/push_pre_popup.dart';
import '../notification/notification_repository_test.dart' show notificationUser;
import 'device_add_flow_screen_test.dart' show Translations;
import 'device_add_flow_test.dart' show Gateway, device, camera;

/// 실제 `DeviceAddFlowRoute`(안쪽 scope의 자동 묶기 override 포함) + 실제
/// 컨트롤러 + 실제 결과 화면을 그대로 두고, BLE·서버만 가짜로 바꿔 등록
/// 시나리오 전체를 돌린다(2026-09-22 — 컨트롤러를 통째로 갈아끼운 기존
/// 테스트는 scope 버그·합류 멤버 누락을 못 잡았다).
///
/// 가짜 서버는 `redesign_save_group_v1`의 검사(예상 구성 ≠ 실제 → PT409)와
/// 멤버 이동을 흉내 낸다.
class FakeServer {
  final enclosures = <Map<String, Object?>>[];
  final devices = <Map<String, Object?>>[];
  final cameras = <Map<String, Object?>>[];
  final pets = <Map<String, Object?>>[];
  final rpcCalls = <Map<String, Object?>>[];
  int failNext = 0;
  int _groups = 0;

  List<Map<String, Object?>> _table(String kind) => switch (kind) {
        'device' => devices,
        'camera' => cameras,
        _ => pets,
      };

  RedesignGroupRepository repository() => RedesignGroupRepository(
      loadRows: (table) async => switch (table) {
            'enclosures' => enclosures,
            'devices' => devices,
            'cameras' => cameras,
            'pets' => pets,
            _ => const [],
          },
      rpc: _rpc);

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    rpcCalls.add({'name': name, ...params});
    if (failNext > 0) {
      failNext--;
      throw const PostgrestException(message: 'boom', code: 'XX000');
    }
    expect(name, 'redesign_save_group_v1');
    final expected = (params['p_expected_members']! as List)
        .cast<Map<String, Object?>>();
    var target = params['p_group_id'] as String?;
    if (target != null) {
      final actual = {
        for (final kind in ['device', 'camera', 'pet'])
          for (final row in _table(kind))
            if (row['enclosure_id'] == target) '$kind:${row['id']}'
      };
      final claimed = {
        for (final e in expected)
          if (e['group_id'] == target) '${e['kind']}:${e['id']}'
      };
      if (!_sameSet(actual, claimed)) {
        throw const PostgrestException(message: 'group changed', code: 'PT409');
      }
    }
    for (final e in expected) {
      final row = _table(e['kind']! as String)
          .firstWhere((r) => r['id'] == e['id']);
      if (row['enclosure_id'] != e['group_id']) {
        throw const PostgrestException(
            message: 'membership changed', code: 'PT409');
      }
    }
    if (target == null) {
      target = 'g-new-${++_groups}';
      enclosures.add({'id': target, 'name': '사육 환경 $_groups'});
    }
    final selected = {
      'device': params['p_device_id'],
      'camera': params['p_camera_id'],
      'pet': params['p_pet_id'],
    };
    for (final kind in selected.keys) {
      for (final row in _table(kind)) {
        if (row['enclosure_id'] == target && row['id'] != selected[kind]) {
          row['enclosure_id'] = null;
        }
        if (row['id'] == selected[kind]) row['enclosure_id'] = target;
      }
    }
    return {'group_id': target};
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  String? groupOf(String kind, String id) =>
      _table(kind).firstWhere((r) => r['id'] == id)['enclosure_id'] as String?;
}

/// 펌웨어가 PAIR_OK로 알려 준 하드웨어 id를 서버 행으로 확인한다. 확인하는
/// 순간 행이 생긴다(기기가 스스로 /pair 한 결과를 흉내).
class FakeRegistration implements DeviceAddRegistrationRepository {
  FakeRegistration(this.server);
  final FakeServer server;
  static const ids = {'hw-d': 'D-new', 'hw-c': 'C-new', 'hw-d2': 'D-2'};

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  Future<List<String>> names(String account) async => [
        for (final row in [...server.devices, ...server.cameras])
          row['name']! as String
      ];

  @override
  Future<String?> confirm(
      String account, PairTargetKind kind, String hardwareId) async {
    final id = ids[hardwareId];
    if (id == null) return null;
    final table = kind == PairTargetKind.device ? server.devices : server.cameras;
    if (!table.any((r) => r['id'] == id)) {
      table.add({'id': id, 'name': '새 ${kind.name}', 'enclosure_id': null});
    }
    return id;
  }

  @override
  Future<({DateTime? lastSeen})?> ownedCamera(String account, String id) async =>
      null;

  @override
  Future<bool> ownedDevice(String account, String id) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeServer server;
  late Gateway gateway;
  late int refreshes;
  const flowKey = 'integration';

  setUp(() {
    server = FakeServer();
    gateway = Gateway()
      ..receipts['physical-a'] =
          const DeviceProvisionReceipt(wifiConnected: true, hardwareId: 'hw-d')
      ..receipts['physical-b'] =
          const DeviceProvisionReceipt(wifiConnected: true, hardwareId: 'hw-c');
    refreshes = 0;
  });

  Future<DeviceAddFlowController> pumpRoute(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      currentUserProvider
                          .overrideWithValue(notificationUser('a')),
                      deviceAddSessionUserProvider.overrideWithValue(() => 'a'),
                      deviceAddGatewayFactoryProvider
                          .overrideWithValue(() => gateway),
                      deviceAddRegistrationProvider
                          .overrideWithValue(FakeRegistration(server)),
                      freshAccessTokenProvider
                          .overrideWithValue(() async => 'jwt'),
                      redesignGroupRepositoryProvider
                          .overrideWith((ref) => server.repository()),
                      managementMutationCompletedProvider
                          .overrideWithValue(() => refreshes++),
                      // 알림 권한은 이미 허용 — 팝업 없이 결과 화면만 본다.
                      pushConsentFlowProvider.overrideWithValue(PushConsentFlow(
                        currentPermission: () async => PushPermission.authorized,
                        requestPermission: ({bool retry = false}) async {},
                        setTopic: (_, __) async {},
                        isAsked: (_) => true,
                        markAsked: (_) async {},
                      )),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const DeviceAddFlowRoute(flowKey: flowKey))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceAddFlowScreen)));
    return container.read(deviceAddFlowProvider(flowKey).notifier);
  }

  /// 스캔 목록에 기기를 띄우고 골라 Wi-Fi를 보낸 뒤 결과 화면까지 간다.
  Future<void> addDevices(WidgetTester tester, DeviceAddFlowController c,
      List<DeviceAddCandidate> picks) async {
    gateway.events.add(picks);
    await tester.pump();
    for (final pick in picks) {
      c.select(pick);
    }
    c.chooseNetwork('home');
    await c.connect('home', 'password');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  DeviceAddState stateOf(WidgetTester tester) {
    final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceAddFlowScreen)));
    return container.read(deviceAddFlowProvider(flowKey));
  }

  List<Map<String, Object?>> saves() => server.rpcCalls
      .where((c) => c['name'] == 'redesign_save_group_v1')
      .toList();

  testWidgets('사육장+카메라 동시 등록 → Route의 자동 묶기로 새 사육 환경', (tester) async {
    final c = await pumpRoute(tester);
    await addDevices(tester, c, [device, camera]);

    expect(saves(), hasLength(1));
    expect(saves().single['p_group_id'], isNull);
    expect(saves().single['p_device_id'], 'D-new');
    expect(saves().single['p_camera_id'], 'C-new');
    expect(server.groupOf('device', 'D-new'), 'g-new-1');
    expect(server.groupOf('camera', 'C-new'), 'g-new-1');
    expect(stateOf(tester).groupError, isFalse);
    expect(stateOf(tester).groupId, 'g-new-1');
    expect(find.text('device_add_group_error'.tr()), findsNothing);
    expect(find.byKey(const Key('device_add_pet')), findsOneWidget);
    // 등록 2건 + 묶기 1건 모두 홈 갱신 신호를 보낸다.
    expect(refreshes, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('자동 묶기 실패 → "사육 환경 다시 묶기"로 성공', (tester) async {
    server.failNext = 1;
    final c = await pumpRoute(tester);
    await addDevices(tester, c, [device, camera]);

    expect(stateOf(tester).groupError, isTrue);
    expect(find.text('device_add_group_error'.tr()), findsOneWidget);
    expect(find.text('device_add_done_subtitle'.tr()), findsNothing);
    await tester.tap(find.text('device_add_retry_group'.tr()));
    await tester.pumpAndSettle();

    expect(saves(), hasLength(2));
    expect(stateOf(tester).groupError, isFalse);
    expect(server.groupOf('device', 'D-new'), 'g-new-1');
    expect(find.text('device_add_group_error'.tr()), findsNothing);
    expect(find.byKey(const Key('device_add_pet')), findsOneWidget);
  });

  testWidgets('사육장만 등록 → 카메라+도마뱀 환경에 합류해도 도마뱀 유지', (tester) async {
    server.enclosures.add({'id': 'g1', 'name': '마뱀이네 집'});
    server.cameras
        .add({'id': 'C-old', 'name': '카메라 1', 'enclosure_id': 'g1'});
    server.pets.add({'id': 'P1', 'name': '꼬꼬', 'enclosure_id': 'g1'});
    final c = await pumpRoute(tester);
    await addDevices(tester, c, [device]);

    // 합류 카드 — 새 기기는 등록 이름으로 보인다.
    expect(find.byKey(const Key('device_add_join')), findsOneWidget);
    expect(find.text('사육장 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('device_add_join')));
    await tester.pumpAndSettle();

    expect(saves(), hasLength(1));
    expect(saves().single['p_group_id'], 'g1');
    expect(saves().single['p_pet_id'], 'P1');
    expect(server.groupOf('device', 'D-new'), 'g1');
    expect(server.groupOf('camera', 'C-old'), 'g1');
    expect(server.groupOf('pet', 'P1'), 'g1');
    expect(find.byKey(const Key('device_add_pet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카메라만 등록 → 따로 사용 → 사육장 이어 추가 → 둘이 새 환경으로 묶임',
      (tester) async {
    server.enclosures.add({'id': 'g1', 'name': '마뱀이네 집'});
    server.devices.add({'id': 'D-old', 'name': '사육장 1', 'enclosure_id': 'g1'});
    final c = await pumpRoute(tester);
    await addDevices(tester, c, [camera]);

    expect(find.byKey(const Key('device_add_join')), findsOneWidget);
    await tester.tap(find.byKey(const Key('device_add_separate')));
    await tester.pumpAndSettle();
    expect(saves(), isEmpty);
    expect(server.groupOf('camera', 'C-new'), isNull);

    await tester.tap(find.byKey(const Key('device_add_continue_kind')));
    await tester.pump();
    await addDevices(tester, c, [device]);

    expect(saves(), hasLength(1));
    expect(saves().single['p_group_id'], isNull);
    expect(server.groupOf('device', 'D-new'), 'g-new-1');
    expect(server.groupOf('camera', 'C-new'), 'g-new-1');
    // 기존 환경은 건드리지 않는다.
    expect(server.groupOf('device', 'D-old'), 'g1');
    expect(find.byKey(const Key('device_add_pet')), findsOneWidget);
  });

  testWidgets('사육장만 등록 + 합류 후보 없음 → 묶기 없이 이어 추가·기존 연결 안내',
      (tester) async {
    final c = await pumpRoute(tester);
    await addDevices(tester, c, [device]);

    expect(find.byKey(const Key('device_add_join')), findsNothing);
    expect(saves(), isEmpty);
    expect(stateOf(tester).groupError, isFalse);
    expect(find.byKey(const Key('device_add_continue_kind')), findsOneWidget);
    expect(find.byKey(const Key('device_add_link_existing')), findsOneWidget);
    expect(find.text('device_add_group_error'.tr()), findsNothing);
  });
}
