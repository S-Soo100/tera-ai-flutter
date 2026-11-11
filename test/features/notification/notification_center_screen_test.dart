import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/presentation/notification_center_screen.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/shared/widgets/skeleton_loading.dart';
import 'notification_repository_test.dart';
import 'notification_test_host.dart';

class ControlledNotificationStore extends MemoryNotificationStore {
  final source = StreamController<List<Map<String, Object?>>>.broadcast();
  @override
  Stream<List<Map<String, Object?>>> watch(String userId) => source.stream;
}

void main() {
  setUpAll(initializeNotificationLocalization);
  Future<ProviderContainer> pump(
      WidgetTester tester, MemoryNotificationStore store,
      {PushPermission permission = PushPermission.authorized,
      List<EnclosureSet> sets = const [],
      List<TerraCamera> cameras = const [],
      bool camerasFail = false,
      String? selectedCamera}) async {
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationCenterScreen()),
      GoRoute(
          path: '/crecam',
          builder: (_, __) => const Scaffold(body: Text('camera tab'))),
      GoRoute(
          path: '/crecam/cameras/:id/live',
          builder: (_, state) => Scaffold(
              body: Text('camera detail ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/env-detail',
          builder: (_, __) {
            expect(store.operations, contains('read:n1:a'));
            return const Scaffold(body: Text('environment'));
          }),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => notificationUser('a')),
          notificationRepositoryProvider.overrideWithValue(
              NotificationRepository(store, currentUserId: () => 'a')),
          pushPermissionProvider.overrideWith((ref) => permission),
          homeDeviceSetsProvider.overrideWith((ref) async => sets),
          camerasProvider.overrideWith((ref) => camerasFail
              ? Stream.error(StateError('network'))
              : Stream.value(cameras)),
          selectedCrecamCameraProvider.overrideWith((ref) => selectedCamera),
        ],
        child: localizedNotificationHost((context) => MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
            ))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return ProviderScope.containerOf(
        tester.element(find.byType(NotificationCenterScreen)));
  }

  testWidgets('loading skeleton, error and retry, then localized empty state',
      (tester) async {
    final store = ControlledNotificationStore();
    addTearDown(store.source.close);
    addTearDown(store.changes.close);
    await pump(tester, store);
    expect(find.byType(SkeletonPageLoading), findsOneWidget);
    store.source.addError(StateError('network'));
    await tester.pumpAndSettle();
    expect(find.text('알림을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    store.source.add([]);
    await tester.pumpAndSettle();
    expect(find.text('아직 알림이 없어요'), findsOneWidget);
  });
  testWidgets('unread row marks only its id before navigation', (tester) async {
    final store = MemoryNotificationStore()
      ..rows.add(notificationRow('n1', 'a', '2026-09-15T00:00:00Z'));
    addTearDown(store.changes.close);
    await pump(tester, store);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_unread_n1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.text('environment'), findsOneWidget);
  });
  testWidgets(
      'mark all clears the derived unread count and unknown kind stays on center',
      (tester) async {
    final row = notificationRow('n1', 'a', '2026-09-15T00:00:00Z')
      ..['kind'] = 'future.kind';
    final store = MemoryNotificationStore()..rows.add(row);
    addTearDown(store.changes.close);
    final container = await pump(tester, store);
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationCountProvider), 1);
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(find.byKey(const Key('notification_unread_n1')), findsNothing);
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationCenterScreen), findsOneWidget);
  });
  testWidgets('denied permission keeps an enable action in notification center',
      (tester) async {
    final store = MemoryNotificationStore();
    addTearDown(store.changes.close);
    await pump(tester, store, permission: PushPermission.denied);
    await tester.pumpAndSettle();
    expect(find.text('알림 켜기'), findsOneWidget);
  });

  // v4 온습도 이탈 알림(2026-11-02): 알림함에서 열면 그 사육장으로 홈 세트를
  // 옮긴 뒤 온습도 상세로 간다. 내 기기 목록에 없는 id면 옮기지 않는다.
  EnclosureSet deviceSet(String id) => EnclosureSet(
      enclosure: Enclosure(
          id: 'enc-$id', name: '사육장 $id', createdAt: DateTime.utc(2026)),
      device: Device(
          id: id,
          ownerId: 'a',
          enclosureId: 'enc-$id',
          name: '사육장 $id',
          isOnline: true,
          lastSeenAt: null),
      camera: null,
      pet: null);
  Map<String, Object?> envRow(String deviceId) =>
      notificationRow('n1', 'a', '2026-11-02T05:02:03Z')
        ..['kind'] = 'env.alert.triggered'
        ..['category'] = 'env'
        ..['title'] = '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요'
        ..['body'] = '거실 사육장'
        ..['data'] = <String, Object?>{
          'kind': 'env_temp_low',
          'device_id': deviceId,
        };

  testWidgets('env alert row shows its category and selects its device',
      (tester) async {
    final store = MemoryNotificationStore()..rows.add(envRow('dev-2'));
    addTearDown(store.changes.close);
    final container = await pump(tester, store,
        sets: [deviceSet('dev-1'), deviceSet('dev-2')]);
    await tester.pumpAndSettle();
    expect(find.textContaining('온습도 이탈'), findsOneWidget);
    expect(container.read(selectedHomeDeviceIdProvider), isNull);
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.text('environment'), findsOneWidget);
    expect(container.read(selectedHomeDeviceIdProvider), 'dev-2');
  });

  testWidgets('env alert for a device not in my list only navigates',
      (tester) async {
    final store = MemoryNotificationStore()..rows.add(envRow('foreign'));
    addTearDown(store.changes.close);
    final container = await pump(tester, store, sets: [deviceSet('dev-1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_n1')));
    await tester.pumpAndSettle();
    expect(find.text('environment'), findsOneWidget);
    expect(container.read(selectedHomeDeviceIdProvider), isNull);
  });

  // 카메라 렌즈 초점 안내 — 카메라 단위(기획 2026-11-11). 알림함에서 열면
  // data.camera_id 카메라 상세로, 그 카메라 안내만 전부 읽음. camera_id가 없는
  // v1(사람 단위) 행은 고른 카메라(없으면 첫 카메라) 상세로 간다.
  Map<String, Object?> focusRow(String id, {String? cameraId}) =>
      notificationRow(id, 'a', '2026-11-10T01:00:00Z')
        ..['kind'] = cameraFocusNotificationKind
        ..['category'] = 'camera'
        ..['route'] = '/crecam'
        ..['title'] = '카메라 렌즈 초점을 맞춰주세요'
        ..['data'] = <String, Object?>{
          'kind': cameraFocusNotificationKind,
          if (cameraId != null) 'camera_id': cameraId,
        };
  TerraCamera cam(String id) => TerraCamera(
      id: id,
      cameraId: 'p4-$id',
      name: '카메라 $id',
      isOnline: true,
      createdAt: DateTime.utc(2026));

  testWidgets('초점 안내는 분류 카메라 — 열면 그 카메라 상세 + 그 카메라 안내만 읽음',
      (tester) async {
    final store = MemoryNotificationStore()
      ..rows.add(focusRow('f1', cameraId: 'c2'))
      ..rows.add(focusRow('f2', cameraId: 'c2'))
      ..rows.add(focusRow('h1', cameraId: 'c1'));
    addTearDown(store.changes.close);
    await pump(tester, store,
        cameras: [cam('c1'), cam('c2')], selectedCamera: 'c1');
    await tester.pumpAndSettle();
    expect(find.textContaining('카메라 ·'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('notification_f1')));
    await tester.pumpAndSettle();
    expect(find.text('camera detail c2'), findsOneWidget,
        reason: '고른 카메라(c1)가 아니라 안내가 가리키는 카메라');
    expect(store.operations.where((o) => o.startsWith('read:')).toSet(),
        {'read:f1:a', 'read:f2:a'});
  });

  testWidgets('초점 안내 — 가리키는 카메라가 내 목록에 없으면 카메라 탭으로 go',
      (tester) async {
    final store = MemoryNotificationStore()
      ..rows.add(focusRow('f1', cameraId: 'gone'));
    addTearDown(store.changes.close);
    await pump(tester, store, cameras: [cam('c1')], selectedCamera: 'c1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_f1')));
    await tester.pumpAndSettle();
    expect(find.text('camera tab'), findsOneWidget);
    expect(find.byType(NotificationCenterScreen), findsNothing,
        reason: 'go — 알림함 위에 쌓지 않는다');
  });

  testWidgets('초점 안내 — 카메라 목록을 못 받아도 가리키는 카메라 상세로',
      (tester) async {
    final store = MemoryNotificationStore()
      ..rows.add(focusRow('f1', cameraId: 'c2'));
    addTearDown(store.changes.close);
    await pump(tester, store, camerasFail: true, selectedCamera: 'c1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_f1')));
    await tester.pumpAndSettle();
    expect(find.text('camera detail c2'), findsOneWidget);
  });

  testWidgets('v1 초점 안내(camera_id 없음) — 고른 카메라가 없으면 첫 카메라 상세',
      (tester) async {
    final store = MemoryNotificationStore()..rows.add(focusRow('f1'));
    addTearDown(store.changes.close);
    await pump(tester, store, cameras: [cam('c1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_f1')));
    await tester.pumpAndSettle();
    expect(find.text('camera detail c1'), findsOneWidget);
  });

  testWidgets('v1 초점 안내 — 카메라 0대면 카메라 탭으로 go', (tester) async {
    final store = MemoryNotificationStore()..rows.add(focusRow('f1'));
    addTearDown(store.changes.close);
    await pump(tester, store);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification_f1')));
    await tester.pumpAndSettle();
    expect(find.text('camera tab'), findsOneWidget);
  });
}
