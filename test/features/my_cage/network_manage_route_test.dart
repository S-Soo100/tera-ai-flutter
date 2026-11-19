import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_wifi_name_store.dart';
import 'package:vivanaut/features/my_cage/data/known_device_store.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart'
    show DeviceAddCandidate;
import 'package:vivanaut/features/my_cage/domain/network_manage.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import '../notification/notification_repository_test.dart' show notificationUser;
import 'device_add_flow_screen_test.dart' show Translations;
import 'device_add_flow_test.dart' show Gateway;
import 'device_add_route_integration_test.dart' show FakeRegistration, FakeServer;

/// 실제 앱 라우터의 `/devices/network` 정의 + 실제 `DeviceAddFlowRoute`(안쪽
/// scope) + 실제 컨트롤러를 그대로 두고 BLE·서버만 가짜로 바꾼다.
///
/// 네트워크 관리 요청은 안쪽 scope의 `deviceAddNetworkManageProvider`로만
/// 컨트롤러에 간다. `deviceAddFlowProvider`의 `dependencies`에서 빠지면 flow가
/// 최상위 컨테이너에 만들어져 기본값(null = 기기 추가)을 읽는다(2026-09-22 사고와
/// 같은 꼴) — 그러면 아래의 모드·미리 체크 검사가 실패한다.
class _OwnedRegistration extends FakeRegistration {
  _OwnedRegistration(super.server, this.rows);
  final List<OwnedNetworkDevice> rows;
  @override
  Future<List<OwnedNetworkDevice>> networkDevices(String account) async =>
      rows;

  @override
  Future<OwnedNetworkDevice?> networkDevice(
          String account, PairTargetKind kind, String id) async =>
      rows.where((r) => r.kind == kind && r.id == id).firstOrNull;
}

class _NoKnown implements KnownDeviceStore {
  @override
  String? load(String account, DeviceAddCandidate candidate) => null;
  @override
  Future<void> save(
      String account, DeviceAddCandidate candidate, String id) async {}
  @override
  Future<void> forget(String account, DeviceAddCandidate candidate) async {}
}

class _NoNames implements DeviceWifiNameStore {
  @override
  String? load(String account, PairTargetKind kind, String id) => null;
  @override
  Future<void> save(
      String account, PairTargetKind kind, String id, String ssid) async {}
  @override
  Stream<String?> watch(String account, PairTargetKind kind, String id) =>
      Stream.value(null);
  @override
  Future<void> clearAll() async {}
}

/// 서버 `hw_id`와 BLE 주소가 같은 카메라 — `bleMatchesHardware`로 알아본다.
const _ble = DeviceAddCandidate(
    physicalId: 'AA:BB:CC:DD:EE:F0',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM',
    rssi: -50);
const _row = OwnedNetworkDevice(
    kind: PairTargetKind.camera,
    id: 'cam-row',
    name: '카메라 4',
    hardwareId: 'aabbccddeef0',
    isOnline: true,
    wifiRssi: -78);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late Gateway gateway;
  setUp(() => gateway = Gateway());

  GoRoute appRoute(String path) {
    final router = buildAppRouter(isAuthenticated: () => true);
    addTearDown(router.dispose);
    return router.configuration.routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == path);
  }

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('entry'))),
      appRoute('/devices/network'),
    ]);
    addTearDown(router.dispose);
    final server = FakeServer();
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
                      deviceAddRegistrationProvider.overrideWithValue(
                          _OwnedRegistration(server, const [_row])),
                      knownDeviceStoreProvider.overrideWithValue(_NoKnown()),
                      deviceWifiNameStoreProvider.overrideWithValue(_NoNames()),
                      freshAccessTokenProvider
                          .overrideWithValue(() async => 'jwt'),
                      redesignGroupRepositoryProvider
                          .overrideWith((ref) => server.repository()),
                      managementMutationCompletedProvider
                          .overrideWithValue(() {}),
                    ],
                    child: MaterialApp.router(
                        theme: AppTheme.light,
                        routerConfig: router,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates:
                            context.localizationDelegates)))));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> open(WidgetTester tester, GoRouter router,
      {Object? extra}) async {
    router.push('/devices/network', extra: extra);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    gateway.events.add([_ble]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('/devices/network → 네트워크 관리 화면, 컨트롤러도 네트워크 관리 모드',
      (tester) async {
    final router = await pumpApp(tester);
    await open(tester, router);

    expect(find.text('네트워크 관리'), findsOneWidget);
    expect(find.text('네트워크에 연결할 기기 선택'), findsOneWidget);
    // 컨트롤러가 이 계정 기기 행으로 알아본 카메라 — 행 이름·dBm으로 보인다.
    // 메뉴에서 열면(extra 없음) 아무것도 체크하지 않는다.
    final row = find.byKey(Key('network_manage_row_${_ble.physicalId}'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('카메라 4')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('-78 dBm')),
        findsOneWidget);
    expect(find.text('기기 1개 네트워크 연결'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('extra 문자열 = 미리 체크할 행 id', (tester) async {
    final router = await pumpApp(tester);
    await open(tester, router, extra: 'cam-row');

    expect(find.text('네트워크 관리'), findsOneWidget);
    expect(find.byKey(Key('network_manage_row_${_ble.physicalId}')),
        findsOneWidget);
    expect(find.text('기기 1개 네트워크 연결'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
