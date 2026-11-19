// 카메라 네트워크 신호 약함 모달(Figma 2020:11196, 2026-11-19 막대 → 모달).
// `.tr()`은 ko.json 값으로 그린다(localizedNotificationHost).
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/weak_signal_notice_prompt.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';

import '../notification/notification_repository_test.dart';
import '../notification/notification_test_host.dart';

const _message = '네트워크 신호가 약하니 기기와 연결된 네트워크를 변경해 주세요';

void main() {
  setUpAll(initializeNotificationLocalization);

  test('문구는 Figma 원문 그대로', () {
    final ko = jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(ko['camera_weak_signal_modal'], _message);
    expect(ko['camera_weak_signal_change'], '변경');
    expect(ko['camera_weak_signal_dont_show'], '알림 다시 보지 않기');
    expect(ko.containsKey('camera_weak_signal_notice'), isFalse,
        reason: '막대 문구는 더 쓰지 않는다');
  });

  late MemoryNotificationStore store;
  late List<String> turnedOff;
  late bool failTurnOff;

  Map<String, Object?> weak(String id, String cameraId) => {
        ...notificationRow(id, 'a', '2026-11-19T01:00:00Z'),
        'kind': cameraWeakSignalNotificationKind,
        'category': 'camera',
        'data': <String, Object?>{'camera_id': cameraId},
      };

  setUp(() {
    store = MemoryNotificationStore()..rows.add(weak('w1', 'c1'));
    turnedOff = [];
    failTurnOff = false;
  });

  /// '/'에 c1 카메라 모달 자리를 두 개(홈·카메라 탭처럼) 둔다.
  Future<GoRouter> pump(WidgetTester tester,
      {String cameraId = 'c1', bool twoHosts = false}) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
                  body: Column(children: [
                WeakSignalNoticePrompt(
                    cameraId: cameraId, deviceId: 'p4-$cameraId'),
                if (twoHosts)
                  WeakSignalNoticePrompt(
                      cameraId: cameraId, deviceId: 'p4-$cameraId'),
                const Text('home'),
              ]))),
      GoRoute(
          path: '/other', builder: (_, __) => const Scaffold(body: Text('other'))),
      // 네트워크 관리(2026-11-19) — extra는 미리 체크할 카메라 행 id.
      GoRoute(
          path: '/devices/network',
          builder: (_, s) =>
              Scaffold(body: Text('network ${s.extra! as String}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => notificationUser('a')),
        notificationRepositoryProvider.overrideWithValue(
            NotificationRepository(store, currentUserId: () => 'a')),
        weakSignalNoticeOffWriterProvider.overrideWithValue((id) async {
          if (failTurnOff) throw Exception('network');
          turnedOff.add(id);
        }),
      ],
      child: localizedNotificationHost((context) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale)),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  Iterable<String> reads() => store.operations.where((o) => o.startsWith('read:'));

  testWidgets('미읽음 안내가 있으면 그 카메라에 모달을 Figma 수치로 띄운다', (tester) async {
    await pump(tester);
    expect(find.text(_message), findsOneWidget);
    final surface = tester.getRect(find.byKey(const Key('viva_modal_surface')));
    expect(surface.width, 345);
    expect(find.text('닫기'), findsOneWidget);
    final change = tester.widget<FilledButton>(
        find.ancestor(of: find.text('변경'), matching: find.byType(FilledButton)));
    expect(change.style!.backgroundColor!.resolve({}), VivaColors.mainDark);
    // 체크 행은 버튼 16 아래, 왼쪽 정렬.
    final check = tester.getRect(find.byKey(WeakSignalNoticePrompt.checkKey));
    final buttons = tester.getRect(find.byKey(const Key('viva_modal_cancel')));
    expect(check.top - buttons.bottom, 16);
    expect(check.left, buttons.left);
    expect(check.height, 24);
    expect(surface.bottom - check.bottom, 24);
  });

  testWidgets('안내가 없는 카메라에는 띄우지 않는다', (tester) async {
    await pump(tester, cameraId: 'c2');
    expect(find.text(_message), findsNothing);
  });

  testWidgets('닫기 → 읽음 처리, 다시 뜨지 않는다', (tester) async {
    await pump(tester);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
    expect(reads(), ['read:w1:a']);
    expect(turnedOff, isEmpty);
    // 다른 화면에 다녀와도 다시 뜨지 않는다.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(_message), findsNothing);
  });

  testWidgets('바깥을 눌러 닫아도 닫기와 같다', (tester) async {
    await pump(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
    expect(reads(), ['read:w1:a']);
  });

  testWidgets('변경 → 그 카메라를 미리 체크한 네트워크 관리, 읽음 처리', (tester) async {
    await pump(tester);
    await tester.tap(find.text('변경'));
    await tester.pumpAndSettle();
    expect(find.text('network c1'), findsOneWidget);
    expect(reads(), ['read:w1:a']);
  });

  testWidgets('다시 보지 않기를 고르고 닫으면 그 카메라 안내를 끈다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(WeakSignalNoticePrompt.checkKey));
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(turnedOff, ['c1']);
    expect(reads(), ['read:w1:a']);
  });

  testWidgets('다시 보지 않기를 고르고 변경해도 끈다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(WeakSignalNoticePrompt.checkKey));
    await tester.pump();
    await tester.tap(find.text('변경'));
    await tester.pumpAndSettle();
    expect(turnedOff, ['c1']);
    expect(find.text('network c1'), findsOneWidget);
  });

  testWidgets('체크를 다시 풀면 끄지 않는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(WeakSignalNoticePrompt.checkKey));
    await tester.pump();
    await tester.tap(find.byKey(WeakSignalNoticePrompt.checkKey));
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(turnedOff, isEmpty);
  });

  testWidgets('끄기 저장에 실패하면 알린다', (tester) async {
    failTurnOff = true;
    await pump(tester);
    await tester.tap(find.byKey(WeakSignalNoticePrompt.checkKey));
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('알림을 끄지 못했어요. 다음에 안내가 뜨면 다시 시도해 주세요.'),
        findsOneWidget);
    expect(reads(), ['read:w1:a']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('같은 카메라 자리가 둘이어도 모달은 하나', (tester) async {
    await pump(tester, twoHosts: true);
    expect(find.text(_message), findsOneWidget);
  });

  testWidgets('다른 화면이 위에 있으면 기다렸다가 돌아오면 띄운다', (tester) async {
    store.rows.clear();
    final router = await pump(tester);
    router.push('/other');
    await tester.pumpAndSettle();
    store.rows.add(weak('w1', 'c1'));
    store.changes.add(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(_message), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);
  });

  testWidgets('떠 있는 동안 신호가 회복돼도 닫을 때까지 둔다(읽음만 다시 보낸다)',
      (tester) async {
    await pump(tester);
    store.rows.single['read_at'] = '2026-11-19T02:00:00Z';
    store.changes.add(null);
    await tester.pump();
    expect(find.text(_message), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
  });
}
