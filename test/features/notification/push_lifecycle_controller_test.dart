import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/data/push_device_repository.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/data/push_preferences.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';

class FakePushMessaging implements PushMessagingPort {
  PushPermission permission = PushPermission.authorized;
  int requests = 0;
  String? token = 'test-token';
  Completer<String?>? pendingToken;
  int deletes = 0;
  bool failDelete = false;
  List<String>? lifecycleEvents;
  Completer<void>? pendingDeletion;
  PushMessage? initial;
  final tokens = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushMessage>.broadcast();
  @override
  bool get supported => true;
  @override
  Future<PushPermission> getPermission() async => permission;
  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<String?> getToken() =>
      pendingToken?.future ?? Future.value(token ??= 'new-login-token');
  @override
  Future<void> deleteToken() async {
    deletes++;
    lifecycleEvents?.add('deleteToken');
    await pendingDeletion?.future;
    if (failDelete) throw StateError('offline');
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => tokens.stream;
  @override
  Stream<PushMessage> get onMessage => messages.stream;
  @override
  Stream<PushMessage> get onMessageOpenedApp => taps.stream;
  @override
  Future<PushMessage?> getInitialMessage() async => initial;
  @override
  Future<void> openSettings() async {}
  Future<void> close() async {
    await tokens.close();
    await messages.close();
    await taps.close();
  }
}

class MemoryPushPreferences implements PushPreferences {
  bool seen = false;
  @override
  bool get explanationSeen => seen;
  @override
  Future<void> markExplanationSeen() async {
    seen = true;
  }

  @override
  Future<String> installationId() async =>
      '4da7f48b-0000-4000-8000-111111111111';
}

class RecordingPushDevices implements PushDevicePort {
  final operations = <String>[];
  bool failDeactivation = false;
  Completer<void>? deactivationStarted;
  Completer<void>? pendingDeactivation;
  @override
  Future<void> register(
      {required String userId,
      required String installationId,
      required String token,
      required String appVersion,
      required String locale}) async {
    operations
        .add('register:$userId:$installationId:$token:$appVersion:$locale');
  }

  @override
  Future<void> deactivate(String installationId) async {
    operations.add('deactivate');
    deactivationStarted?.complete();
    await pendingDeactivation?.future;
    if (failDeactivation) throw StateError('offline');
  }
}

void main() {
  late FakePushMessaging messaging;
  late RecordingPushDevices devices;
  late PushLifecycleController controller;
  late List<String> displayed;
  late List<String> navigated;
  late List<String> reads;
  late bool notificationAvailable;
  setUp(() {
    messaging = FakePushMessaging();
    devices = RecordingPushDevices();
    displayed = [];
    navigated = [];
    reads = [];
    notificationAvailable = true;
    controller = PushLifecycleController(
      messaging: messaging,
      devices: devices,
      preferences: MemoryPushPreferences(),
      appVersion: () async => '0.103.0+205',
      locale: () => 'ko',
      findNotification: (id, userId) async =>
          id == 'foreign' || !notificationAvailable
              ? null
              : AppNotification.fromJson({
                  'id': id,
                  'user_id': userId,
                  'kind': 'safety.alert',
                  'category': 'safety',
                  'route': '/env-detail',
                  'title': '안전',
                  'body': '확인',
                }),
      markRead: (id) async {
        reads.add(id);
      },
      display: (message) async {
        displayed.add(message.notificationId);
      },
      navigate: (route) {
        navigated.add(route);
      },
      permissionChanged: (_) {},
      reportError: (_) {},
    );
  });
  tearDown(() async {
    await controller.dispose();
    await messaging.close();
  });

  test(
      'signed out never registers; authorized login and refresh register same installation',
      () async {
    await controller.start();
    expect(devices.operations, isEmpty);
    await controller.setUser('a');
    expect(devices.operations.single,
        'register:a:4da7f48b-0000-4000-8000-111111111111:test-token:0.103.0+205:ko');
    messaging.token = 'refreshed';
    messaging.tokens.add('refreshed');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(devices.operations.last, contains(':refreshed:'));
  });

  test('direct account switch rotates transport before new registration',
      () async {
    messaging.lifecycleEvents = devices.operations;
    await controller.start();
    await controller.setUser('a');
    devices.operations.clear();
    messaging.pendingDeletion = Completer<void>();
    final switchUser = controller.setUser('b');
    await Future<void>.delayed(Duration.zero);
    await controller.setUser('b');
    messaging.tokens.add('old-account-refresh');
    await Future<void>.delayed(Duration.zero);
    final duringDeletion = List<String>.of(devices.operations);
    messaging.pendingDeletion!.complete();
    await switchUser;
    expect(duringDeletion, ['deleteToken']);
    expect(devices.operations, [
      'deleteToken',
      'register:b:4da7f48b-0000-4000-8000-111111111111:new-login-token:0.103.0+205:ko'
    ]);
  });

  test('denied permission never gets registered', () async {
    messaging.permission = PushPermission.denied;
    await controller.start();
    await controller.setUser('a');
    expect(devices.operations, isEmpty);
  });

  test(
      'logout deactivates then deletes transport before signout and next login gets a new token',
      () async {
    messaging.lifecycleEvents = devices.operations;
    await controller.setUser('a');
    devices.operations.clear();
    await controller.logout(() async {
      devices.operations.add('signout');
    });
    expect(devices.operations, ['deactivate', 'deleteToken', 'signout']);
    await controller.setUser('b');
    expect(devices.operations.last,
        'register:b:4da7f48b-0000-4000-8000-111111111111:new-login-token:0.103.0+205:ko');
  });

  test('remote deactivation failure still deletes transport and signs out',
      () async {
    messaging.lifecycleEvents = devices.operations;
    devices.failDeactivation = true;
    await controller.setUser('a');
    devices.operations.clear();
    await controller.logout(() async {
      devices.operations.add('signout');
    });
    expect(devices.operations, ['deactivate', 'deleteToken', 'signout']);
  });

  test('transport delete failure does not stop signout', () async {
    messaging.lifecycleEvents = devices.operations;
    messaging.failDelete = true;
    await controller.setUser('a');
    devices.operations.clear();
    await controller.logout(() async {
      devices.operations.add('signout');
    });
    expect(devices.operations, ['deactivate', 'deleteToken', 'signout']);
  });

  test('forced auth loss deletes transport once without remote calls',
      () async {
    messaging.lifecycleEvents = devices.operations;
    await controller.setUser('a');
    devices.operations.clear();
    await controller.setUser(null);
    await controller.setUser(null);
    expect(devices.operations, ['deleteToken']);
    expect(messaging.deletes, 1);
  });

  test('refresh during explicit logout transport deletion never registers',
      () async {
    messaging.lifecycleEvents = devices.operations;
    await controller.start();
    await controller.setUser('a');
    devices.operations.clear();
    messaging.pendingDeletion = Completer<void>();
    final logout = controller.logout(() async {
      devices.operations.add('signout');
    });
    await Future<void>.delayed(Duration.zero);
    await controller.setUser('a');
    messaging.tokens.add('late-token');
    await Future<void>.delayed(Duration.zero);
    final duringDelete = List<String>.of(devices.operations);
    messaging.pendingDeletion!.complete();
    await logout;
    expect(duringDelete, ['deactivate', 'deleteToken']);
    expect(devices.operations, ['deactivate', 'deleteToken', 'signout']);
  });

  test(
      'new login waits for forced deletion and cannot register a refresh from the old transport',
      () async {
    messaging.lifecycleEvents = devices.operations;
    await controller.start();
    await controller.setUser('a');
    devices.operations.clear();
    messaging.pendingDeletion = Completer<void>();
    final forcedLogout = controller.setUser(null);
    await Future<void>.delayed(Duration.zero);
    final newLogin = controller.setUser('b');
    messaging.tokens.add('stale-refresh');
    await Future<void>.delayed(Duration.zero);
    final duringDelete = List<String>.of(devices.operations);
    messaging.pendingDeletion!.complete();
    await Future.wait([forcedLogout, newLogin]);
    expect(duringDelete, ['deleteToken']);
    expect(devices.operations, [
      'deleteToken',
      'register:b:4da7f48b-0000-4000-8000-111111111111:new-login-token:0.103.0+205:ko'
    ]);
  });

  test('resume and token refresh during delayed deactivation cannot register',
      () async {
    await controller.start();
    await controller.setUser('a');
    devices.operations.clear();
    devices.deactivationStarted = Completer<void>();
    devices.pendingDeactivation = Completer<void>();
    final logout = controller.logout(() async {
      devices.operations.add('signout');
    });
    await devices.deactivationStarted!.future;
    await controller.setUser('a');
    messaging.tokens.add('during-logout');
    await Future<void>.delayed(Duration.zero);
    await controller.synchronize();
    final whileDeactivating = List<String>.of(devices.operations);
    devices.pendingDeactivation!.complete();
    await logout;
    expect(whileDeactivating, ['deactivate']);
    expect(devices.operations, ['deactivate', 'signout']);
    await controller.setUser('a');
    expect(devices.operations.last, startsWith('register:a:'));
  });

  test(
      'a different authenticated account cannot register while logout is active',
      () async {
    await controller.setUser('a');
    devices.operations.clear();
    devices.deactivationStarted = Completer<void>();
    devices.pendingDeactivation = Completer<void>();
    final logout = controller.logout(() async {
      devices.operations.add('signout');
    });
    await devices.deactivationStarted!.future;
    await controller.setUser('b');
    final whileDeactivating = List<String>.of(devices.operations);
    devices.pendingDeactivation!.complete();
    await logout;
    expect(whileDeactivating, ['deactivate']);
    expect(devices.operations, ['deactivate', 'signout']);
    await controller.setUser('b');
    expect(devices.operations.last, startsWith('register:b:'));
  });

  test('failed signout remains recoverable for the authenticated account',
      () async {
    await controller.setUser('a');
    devices.operations.clear();
    await expectLater(controller.logout(() async {
      throw StateError('offline');
    }), throwsStateError);
    await controller.setUser('a');
    expect(devices.operations.first, 'deactivate');
    expect(devices.operations.last, startsWith('register:a:'));
  });

  test(
      'temporarily absent foreground row can retry but successful display stays deduplicated',
      () async {
    await controller.setUser('a');
    const message = PushMessage(
        notificationId: 'eventual', kind: 'safety.alert', route: '/env-detail');
    notificationAvailable = false;
    await controller.foreground(message);
    expect(displayed, isEmpty);
    notificationAvailable = true;
    await controller.foreground(message);
    await controller.foreground(message);
    expect(displayed, ['eventual']);
  });

  test(
      'temporarily absent tapped row can retry but successful open stays deduplicated',
      () async {
    await controller.setUser('a');
    const message = PushMessage(
        notificationId: 'eventual', kind: 'safety.alert', route: '/env-detail');
    notificationAvailable = false;
    await controller.open(message);
    expect(navigated, isEmpty);
    notificationAvailable = true;
    await controller.open(message);
    await controller.open(message);
    expect(reads, ['eventual']);
    expect(navigated, ['/env-detail']);
  });

  test('logout deactivates before signout even when deactivation fails',
      () async {
    await controller.setUser('a');
    devices.failDeactivation = true;
    await controller.logout(() async {
      devices.operations.add('signout');
    });
    expect(devices.operations.sublist(1), ['deactivate', 'signout']);
    messaging.tokens.add('late-refresh');
    await Future<void>.delayed(Duration.zero);
    expect(devices.operations.last, 'signout');
  });

  test(
      'token acquisition finishing after logout cannot re-enable the installation',
      () async {
    messaging.pendingToken = Completer<String?>();
    final registration = controller.setUser('a');
    await Future<void>.delayed(Duration.zero);
    final logout = controller.logout(() async {
      devices.operations.add('signout');
    });
    messaging.pendingToken!.complete('late');
    await Future.wait([registration, logout]);
    expect(devices.operations, ['deactivate', 'signout']);
  });

  test('foreground duplicates display once; foreign account rows never display',
      () async {
    await controller.setUser('a');
    const message = PushMessage(
        messageId: 'm1',
        notificationId: 'n1',
        kind: 'safety.alert',
        route: '/env-detail',
        title: '제목',
        body: '본문');
    await controller.foreground(message);
    await controller.foreground(message);
    await controller.foreground(
        const PushMessage(messageId: 'm2', notificationId: 'foreign'));
    expect(displayed, ['n1']);
  });

  test(
      'tap marks owned notification then uses safe fallback for untrusted route',
      () async {
    await controller.setUser('a');
    await controller.open(const PushMessage(
        messageId: 'm1',
        notificationId: 'n1',
        kind: 'safety.alert',
        route: 'https://evil.example'));
    expect(reads, ['n1']);
    expect(navigated, ['/notifications']);
    await controller.open(const PushMessage(
        notificationId: 'foreign', kind: 'safety.alert', route: '/env-detail'));
    expect(navigated, ['/notifications']);
  });

  test('cold-start tap waits for login and is consumed once', () async {
    messaging.initial = const PushMessage(
        messageId: 'cold',
        notificationId: 'n1',
        kind: 'safety.alert',
        route: '/env-detail');
    await controller.start();
    expect(navigated, isEmpty);
    await controller.setUser('a');
    await controller.open(messaging.initial!);
    expect(navigated, ['/env-detail']);
  });
}
