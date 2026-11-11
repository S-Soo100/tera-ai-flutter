// 카메라 렌즈 초점 안내 — 카메라 단위(기획 2026-11-11). 운영자가 app_notifications에
// 넣은 `camera.focus_needed` 미읽음 행의 `data.camera_id` 카메라 라이브에만 막대를 띄운다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/presentation/focus_notice_providers.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';

import 'notification_repository_test.dart';

Map<String, Object?> focusRow(String id, String userId,
        {String? readAt, String? cameraId = 'c1', String? deviceId}) =>
    {
      ...notificationRow(id, userId, '2026-11-10T01:00:00Z'),
      'kind': cameraFocusNotificationKind,
      'category': 'camera',
      'route': '/crecam',
      'read_at': readAt,
      'data': <String, Object?>{
        'kind': cameraFocusNotificationKind,
        if (cameraId != null) 'camera_id': cameraId,
        if (deviceId != null) 'device_id': deviceId,
      },
    };

const c1 = (id: 'c1', deviceId: 'p4-c1');
const c2 = (id: 'c2', deviceId: 'p4-c2');

class _FailingStore extends MemoryNotificationStore {
  final failIds = <String>{};
  @override
  Future<void> markRead(String id, String userId, DateTime at) async {
    if (failIds.contains(id)) {
      operations.add('fail:$id');
      throw Exception('network');
    }
    return super.markRead(id, userId, at);
  }
}

void main() {
  late _FailingStore store;
  late StateProvider<User?> user;

  setUp(() {
    store = _FailingStore();
    user = StateProvider<User?>((_) => notificationUser('a'));
  });

  /// 화면에 'c1/c2' 두 카메라의 막대 표시 여부를 `true/false`로 그린다.
  Future<WidgetRef> pump(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(user)),
        notificationRepositoryProvider.overrideWith((ref) =>
            NotificationRepository(store,
                currentUserId: () => ref.read(user)?.id)),
      ],
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        final a = ref.watch(focusNoticeVisibleProvider(c1));
        final b = ref.watch(focusNoticeVisibleProvider(c2));
        return Text('$a/$b', textDirection: TextDirection.ltr);
      }),
    ));
    await tester.pump();
    await tester.pump();
    return captured;
  }

  testWidgets('안내는 지정한 카메라에만 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a', cameraId: 'c1'));
    await pump(tester);
    expect(find.text('true/false'), findsOneWidget);
    expect(store.operations, contains('watchKind:camera.focus_needed'));
  });

  testWidgets('camera_id에 기기 ID를 넣어도 그 카메라에 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a', cameraId: 'p4-c2'));
    await pump(tester);
    expect(find.text('false/true'), findsOneWidget);
  });

  testWidgets('camera_id 없이 device_id만 있어도 그 카메라에 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a', cameraId: null, deviceId: 'p4-c1'));
    await pump(tester);
    expect(find.text('true/false'), findsOneWidget);
  });

  testWidgets('dismiss는 uuid·기기 ID로 들어온 같은 카메라 안내를 함께 읽음 처리한다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a', cameraId: 'c1'))
      ..add(focusRow('f2', 'a', cameraId: 'p4-c1'));
    final ref = await pump(tester);
    await dismissFocusNotices(ref, c1);
    await tester.pump();
    expect(store.operations.where((o) => o.startsWith('read:')).toSet(),
        {'read:f1:a', 'read:f2:a'});
  });

  testWidgets('camera_id 없는 사람 단위(v1) 안내는 어느 카메라에도 막대를 띄우지 않는다',
      (tester) async {
    store.rows.add(focusRow('f1', 'a', cameraId: null));
    await pump(tester);
    expect(find.text('false/false'), findsOneWidget);
  });

  testWidgets('읽은 안내·다른 계정 행·다른 종류는 무시한다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a', readAt: '2026-11-10T02:00:00Z'))
      ..add(focusRow('f2', 'b'))
      ..add(notificationRow('s1', 'a', '2026-11-10T01:00:00Z'));
    await pump(tester);
    expect(find.text('false/false'), findsOneWidget);
  });

  testWidgets('dismiss는 그 카메라 안내만 읽음 처리하고 다른 카메라 안내는 남긴다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a', cameraId: 'c1'))
      ..add(focusRow('f2', 'a', cameraId: 'c1'))
      ..add(focusRow('g1', 'a', cameraId: 'c2'));
    final ref = await pump(tester);
    expect(find.text('true/true'), findsOneWidget);
    final done = dismissFocusNotices(ref, c1);
    await tester.pump();
    // 서버 갱신을 기다리지 않고 c1만 바로 숨는다.
    expect(find.text('false/true'), findsOneWidget);
    await done;
    await tester.pump();
    expect(store.operations.where((o) => o.startsWith('read:')).toSet(),
        {'read:f1:a', 'read:f2:a'});
    expect(find.text('false/true'), findsOneWidget);
  });

  testWidgets('markRead에 실패한 id는 다시 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a'));
    store.failIds.add('f1');
    final ref = await pump(tester);
    await dismissFocusNotices(ref, c1);
    await tester.pump();
    expect(store.operations, contains('fail:f1'));
    expect(find.text('true/false'), findsOneWidget);
  });

  testWidgets('계정이 바뀌면 숨김과 목록이 새 계정 기준이다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a'))
      ..add(focusRow('g1', 'b'));
    final ref = await pump(tester);
    await dismissFocusNotices(ref, c1);
    await tester.pump();
    expect(find.text('false/false'), findsOneWidget);

    ref.read(user.notifier).state = notificationUser('b');
    await tester.pump();
    await tester.pump();
    expect(find.text('true/false'), findsOneWidget);
  });

  testWidgets('로그아웃이면 보이지 않는다', (tester) async {
    store.rows.add(focusRow('f1', 'a'));
    final ref = await pump(tester);
    ref.read(user.notifier).state = null;
    await tester.pump();
    await tester.pump();
    expect(find.text('false/false'), findsOneWidget);
  });

  testWidgets('dismiss는 이미 읽음이 된 지난 id를 숨김 목록에서 버린다', (tester) async {
    store.rows
      ..add(focusRow('f2', 'a', cameraId: 'c1'))
      ..add(focusRow('g1', 'a', cameraId: 'c2'));
    final ref = await pump(tester);
    ref.read(focusNoticeDismissedProvider.notifier).state = {'old1', 'g1'};
    await dismissFocusNotices(ref, c1);
    await tester.pump();
    // 지난 id(old1)는 버리고, 아직 미읽음인 다른 카메라 숨김(g1)은 남긴다.
    expect(ref.read(focusNoticeDismissedProvider), {'g1', 'f2'});
  });
}
