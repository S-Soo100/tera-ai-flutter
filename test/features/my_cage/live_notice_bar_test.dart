// 라이브 위 카메라 렌즈 초점 안내 스낵바(Figma 1813:8260, 계획 2026-11-10 Task 4).
// `.tr()`은 키를 그대로 돌려준다 — 문구 원문은 ko.json 값으로 고정한다.
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
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/live_notice_bar.dart';
import 'package:vivanaut/features/notification/data/notification_repository.dart';
import 'package:vivanaut/features/notification/domain/app_notification.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';

import '../notification/notification_repository_test.dart';
import '../notification/notification_test_host.dart';

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLivePhase phase) {
    state = WebRtcLiveState(phase: phase);
  }
}

void main() {
  setUpAll(initializeNotificationLocalization);
  test('문구는 Figma 원문 그대로', () {
    final ko = jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(ko['camera_focus_notice'], '카메라 렌즈 초점을 맞춰주세요');
    expect(ko['camera_weak_signal_notice'], '네트워크 신호가 약하니 점검해 주세요');
    expect(ko['live_notice_more'], '더보기');
  });

  late MemoryNotificationStore store;
  setUp(() {
    Map<String, Object?> row(String id, String cameraId,
            [String kind = cameraFocusNotificationKind]) =>
        {
          ...notificationRow(id, 'a', '2026-11-10T01:00:00Z'),
          'kind': kind,
          'category': 'camera',
          'data': <String, Object?>{'camera_id': cameraId},
        };
    // c1에 안내 1건, 다른 카메라 c2에도 1건.
    store = MemoryNotificationStore()
      ..rows.add(row('f1', 'c1'))
      ..rows.add(row('g1', 'c2'))
      // 카메라 c4에는 신호 약함 안내만.
      ..rows.add(row('w1', 'c4', cameraWeakSignalNotificationKind));
  });

  Future<void> pump(WidgetTester tester,
      {WebRtcLivePhase phase = WebRtcLivePhase.streaming,
      double textScale = 1,
      String cameraId = 'c1'}) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SizedBox(
                  width: 369,
                  height: 271,
                  child: Stack(children: [
                    const Positioned.fill(
                        child: ColoredBox(color: Colors.black)),
                    Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: LiveNoticeBar(
                            cameraId: cameraId, deviceId: 'p4-$cameraId')),
                  ])))),
      GoRoute(
          path: '/devices/camera/:id',
          builder: (_, s) =>
              Scaffold(body: Text('device ${s.pathParameters['id']}'))),
      GoRoute(
          path: '/crecam/cameras/:id/live',
          builder: (_, s) =>
              Scaffold(body: Text('detail ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => notificationUser('a')),
        notificationRepositoryProvider.overrideWithValue(
            NotificationRepository(store, currentUserId: () => 'a')),
        webrtcLiveControllerProvider
            .overrideWith((ref, id) => _Fixed(ref, id, phase)),
      ],
      child: localizedNotificationHost((context) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('안내가 있고 영상이 나오면 Figma 수치로 보인다', (tester) async {
    await pump(tester);
    final bar = find.byKey(LiveNoticeBar.tapKey);
    expect(bar, findsOneWidget);
    final rect = tester.getRect(bar);
    expect(rect.width, 345);
    expect(rect.height, 36);

    final body = tester.widget<Text>(find.text('카메라 렌즈 초점을 맞춰주세요'));
    expect(body.style!.fontSize, 16);
    expect(body.style!.fontWeight, FontWeight.w500);
    expect(body.style!.height, 28 / 16);
    expect(body.style!.color, VivaColors.labelSecondary);
    final more = tester.widget<Text>(find.text('더보기'));
    expect(more.style!.fontSize, 16);
    expect(more.style!.fontWeight, FontWeight.w600);
    expect(more.style!.color, VivaColors.mainDark);
    // 좌우 패딩 16.
    expect(tester.getTopLeft(find.text('카메라 렌즈 초점을 맞춰주세요')).dx - rect.left, 16);
    expect(rect.right - tester.getTopRight(find.text('더보기')).dx, 16);
    final material = tester.widget<Material>(
        find.ancestor(of: bar, matching: find.byType(Material)).first);
    expect(material.color, VivaColors.fillButton);
  });

  testWidgets('stalled도 영상이 있으니 보인다', (tester) async {
    await pump(tester, phase: WebRtcLivePhase.stalled);
    expect(find.byKey(LiveNoticeBar.tapKey), findsOneWidget);
  });

  for (final phase in [
    WebRtcLivePhase.connectingConfig,
    WebRtcLivePhase.waitingVideo,
    WebRtcLivePhase.recovering,
    WebRtcLivePhase.failed,
    WebRtcLivePhase.limited,
    WebRtcLivePhase.rebooting,
  ]) {
    testWidgets('${phase.name} 단계에서는 그리지 않는다(안내·버튼을 가리지 않게)', (tester) async {
      await pump(tester, phase: phase);
      expect(find.byKey(LiveNoticeBar.tapKey), findsNothing);
    });
  }

  testWidgets('안내가 없는 카메라 라이브에는 그리지 않는다', (tester) async {
    await pump(tester, cameraId: 'c3');
    expect(find.byKey(LiveNoticeBar.tapKey), findsNothing);
  });

  testWidgets('안내가 없으면 아무것도 그리지 않는다', (tester) async {
    store.rows.clear();
    await pump(tester);
    expect(find.byKey(LiveNoticeBar.tapKey), findsNothing);
  });

  testWidgets('누르면 그 카메라 상세로 가고 읽음 처리된다', (tester) async {
    await pump(tester);
    await tester.tap(find.text('카메라 렌즈 초점을 맞춰주세요'));
    await tester.pumpAndSettle();
    expect(find.text('detail c1'), findsOneWidget);
    expect(store.operations, contains('read:f1:a'));
    expect(store.operations, isNot(contains('read:g1:a')),
        reason: '다른 카메라(c2) 안내는 그대로');
  });

  testWidgets('글자 2배면 높이가 늘고 넘치지 않는다', (tester) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(LiveNoticeBar.tapKey)).height,
        greaterThan(36));
  });

  // ── 네트워크 신호 약함(Figma 1877:15097) ──

  testWidgets('신호 약함 막대도 Figma 수치 그대로(초점 막대와 같은 컴포넌트)', (tester) async {
    await pump(tester, cameraId: 'c4');
    final bar = find.byKey(LiveNoticeBar.tapKey);
    final rect = tester.getRect(bar);
    // 높이 36·한 줄 여부는 실제 Pretendard가 필요해 시뮬레이터로 본다 — 테스트
    // 글꼴은 글자마다 16px라 이 문구가 두 줄이 된다.
    expect(rect.width, 345);
    const text = '네트워크 신호가 약하니 점검해 주세요';
    final body = tester.widget<Text>(find.text(text));
    expect(body.style!.fontSize, 16);
    expect(body.style!.fontWeight, FontWeight.w500);
    expect(body.style!.height, 28 / 16);
    expect(body.style!.letterSpacing, closeTo(-0.32, 1e-9));
    expect(body.style!.color, VivaColors.labelSecondary);
    expect(body.maxLines, 2);
    final more = tester.widget<Text>(find.text('더보기'));
    expect(more.style!.fontWeight, FontWeight.w600);
    expect(more.style!.color, VivaColors.mainDark);
    expect(tester.getTopLeft(find.text(text)).dx - rect.left, 16);
    expect(rect.right - tester.getTopRight(find.text('더보기')).dx, 16);
    final material = tester.widget<Material>(
        find.ancestor(of: bar, matching: find.byType(Material)).first);
    expect(material.color, VivaColors.fillButton);
    expect(material.elevation, 0);
    expect(material.shape, isNull, reason: '테두리 없음');
  });

  testWidgets('신호 약함 막대를 누르면 그 카메라 기기 상세로 가고 그 안내만 읽음', (tester) async {
    await pump(tester, cameraId: 'c4');
    await tester.tap(find.byKey(LiveNoticeBar.tapKey));
    await tester.pumpAndSettle();
    expect(find.text('device c4'), findsOneWidget);
    expect(store.operations.where((o) => o.startsWith('read:')), ['read:w1:a']);
  });

  testWidgets('같은 카메라에 둘 다 있으면 신호 약함 문구 하나만', (tester) async {
    store.rows.add({
      ...notificationRow('w2', 'a', '2026-11-10T02:00:00Z'),
      'kind': cameraWeakSignalNotificationKind,
      'data': <String, Object?>{'camera_id': 'c1'},
    });
    await pump(tester);
    expect(find.byKey(LiveNoticeBar.tapKey), findsOneWidget);
    expect(find.text('네트워크 신호가 약하니 점검해 주세요'), findsOneWidget);
    expect(find.text('카메라 렌즈 초점을 맞춰주세요'), findsNothing);
  });

  // 막대 어디를 눌러도 이동한다 — "더보기" 글자만이 아니다(2026-11-16 사용자 지시).
  for (final (camera, dest) in [('c1', 'detail c1'), ('c4', 'device c4')]) {
    final points = <String, Offset Function(Rect)>{
      '왼쪽 위 모서리 안': (r) => r.topLeft + const Offset(3, 3),
      '왼쪽 여백(문구 앞)': (r) => Offset(r.left + 8, r.center.dy),
      '문구 가운데': (r) => r.center,
      '문구와 더보기 사이·아래 끝': (r) => Offset(r.right - 70, r.bottom - 3),
      '오른쪽 아래 모서리 안': (r) => r.bottomRight - const Offset(3, 3),
    };
    for (final MapEntry(key: where, value: at) in points.entries) {
      testWidgets('$camera 막대 $where를 눌러도 이동하고 읽음 처리된다', (tester) async {
        await pump(tester, cameraId: camera);
        final rect = tester.getRect(find.byKey(LiveNoticeBar.tapKey));
        await tester.tapAt(at(rect));
        await tester.pumpAndSettle();
        expect(find.text(dest), findsOneWidget);
        expect(store.operations.where((o) => o.startsWith('read:')), isNotEmpty);
      });
    }
  }
}
