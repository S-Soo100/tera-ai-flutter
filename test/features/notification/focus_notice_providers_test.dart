// 카메라 렌즈 초점 안내(계획 2026-11-10 Task 2) — 운영자가 app_notifications에
// 넣은 `camera.focus_needed` 미읽음 행이 있으면 라이브 위 스낵바를 띄운다.
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

Map<String, Object?> focusRow(String id, String userId, {String? readAt}) => {
      ...notificationRow(id, userId, '2026-11-10T01:00:00Z'),
      'kind': cameraFocusNotificationKind,
      'category': 'camera',
      'route': '/crecam',
      'read_at': readAt,
    };

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
        final visible = ref.watch(focusNoticeVisibleProvider);
        return Text('$visible', textDirection: TextDirection.ltr);
      }),
    ));
    await tester.pump();
    await tester.pump();
    return captured;
  }

  testWidgets('미읽음 초점 안내가 있으면 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a'));
    await pump(tester);
    expect(find.text('true'), findsOneWidget);
    expect(store.operations, contains('watchKind:camera.focus_needed'));
  });

  testWidgets('읽은 안내·다른 계정 행·다른 종류는 무시한다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a', readAt: '2026-11-10T02:00:00Z'))
      ..add(focusRow('f2', 'b'))
      ..add(notificationRow('s1', 'a', '2026-11-10T01:00:00Z'));
    await pump(tester);
    expect(find.text('false'), findsOneWidget);
  });

  testWidgets('dismiss는 미읽음 초점 안내 전부를 읽음 처리한다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a'))
      ..add(focusRow('f2', 'a'));
    final ref = await pump(tester);
    final done = dismissFocusNotices(ref);
    await tester.pump();
    // 서버 갱신을 기다리지 않고 바로 숨는다.
    expect(find.text('false'), findsOneWidget);
    await done;
    await tester.pump();
    expect(store.operations.where((o) => o.startsWith('read:')).toSet(),
        {'read:f1:a', 'read:f2:a'});
    expect(find.text('false'), findsOneWidget);
  });

  testWidgets('markRead에 실패한 id는 다시 보인다', (tester) async {
    store.rows.add(focusRow('f1', 'a'));
    store.failIds.add('f1');
    final ref = await pump(tester);
    await dismissFocusNotices(ref);
    await tester.pump();
    expect(store.operations, contains('fail:f1'));
    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('계정이 바뀌면 숨김과 목록이 새 계정 기준이다', (tester) async {
    store.rows
      ..add(focusRow('f1', 'a'))
      ..add(focusRow('g1', 'b'));
    store.failIds.add('f1'); // A의 읽음은 실패해도 숨김은 A 것만이어야
    final ref = await pump(tester);
    store.failIds.clear();
    await dismissFocusNotices(ref);
    await tester.pump();
    expect(find.text('false'), findsOneWidget);

    ref.read(user.notifier).state = notificationUser('b');
    await tester.pump();
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('로그아웃이면 보이지 않는다', (tester) async {
    store.rows.add(focusRow('f1', 'a'));
    final ref = await pump(tester);
    ref.read(user.notifier).state = null;
    await tester.pump();
    await tester.pump();
    expect(find.text('false'), findsOneWidget);
  });
}
