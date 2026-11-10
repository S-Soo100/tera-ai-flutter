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
import 'package:vivanaut/features/my_cage/presentation/widgets/focus_notice_snack_bar.dart';
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
    expect(ko['camera_focus_notice_more'], '더보기');
  });

  late MemoryNotificationStore store;
  setUp(() {
    store = MemoryNotificationStore()
      ..rows.add({
        ...notificationRow('f1', 'a', '2026-11-10T01:00:00Z'),
        'kind': cameraFocusNotificationKind,
        'category': 'camera',
      });
  });

  Future<void> pump(WidgetTester tester,
      {WebRtcLivePhase phase = WebRtcLivePhase.streaming,
      double textScale = 1}) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SizedBox(
                  width: 369,
                  height: 271,
                  child: Stack(children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.black)),
                    Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: FocusNoticeSnackBar(cameraId: 'c1')),
                  ])))),
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
    final bar = find.byKey(FocusNoticeSnackBar.tapKey);
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
    expect(tester.getTopLeft(find.text('카메라 렌즈 초점을 맞춰주세요')).dx - rect.left,
        16);
    expect(rect.right - tester.getTopRight(find.text('더보기')).dx,
        16);
    final material = tester.widget<Material>(
        find.ancestor(of: bar, matching: find.byType(Material)).first);
    expect(material.color, VivaColors.fillButton);
  });

  testWidgets('stalled도 영상이 있으니 보인다', (tester) async {
    await pump(tester, phase: WebRtcLivePhase.stalled);
    expect(find.byKey(FocusNoticeSnackBar.tapKey), findsOneWidget);
  });

  for (final phase in [
    WebRtcLivePhase.connectingConfig,
    WebRtcLivePhase.waitingVideo,
    WebRtcLivePhase.recovering,
    WebRtcLivePhase.failed,
    WebRtcLivePhase.limited,
    WebRtcLivePhase.rebooting,
  ]) {
    testWidgets('${phase.name} 단계에서는 그리지 않는다(안내·버튼을 가리지 않게)',
        (tester) async {
      await pump(tester, phase: phase);
      expect(find.byKey(FocusNoticeSnackBar.tapKey), findsNothing);
    });
  }

  testWidgets('안내가 없으면 아무것도 그리지 않는다', (tester) async {
    store.rows.clear();
    await pump(tester);
    expect(find.byKey(FocusNoticeSnackBar.tapKey), findsNothing);
  });

  testWidgets('누르면 그 카메라 상세로 가고 읽음 처리된다', (tester) async {
    await pump(tester);
    await tester.tap(find.text('카메라 렌즈 초점을 맞춰주세요'));
    await tester.pumpAndSettle();
    expect(find.text('detail c1'), findsOneWidget);
    expect(store.operations, contains('read:f1:a'));
  });

  testWidgets('글자 2배면 높이가 늘고 넘치지 않는다', (tester) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(FocusNoticeSnackBar.tapKey)).height,
        greaterThan(36));
  });
}
