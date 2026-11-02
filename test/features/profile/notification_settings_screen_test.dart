// 알림 설정의 온습도 이탈 알림 이동 행(v4 계획 Task 9, Figma S39 1657:5547).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/features/profile/data/notification_preferences_repository.dart';
import 'package:vivanaut/features/profile/presentation/notification_settings_screen.dart';

import '../notification/notification_test_host.dart';

class _MemPrefs implements NotificationPreferencesRepository {
  NotificationPrefs prefs = const NotificationPrefs();
  @override
  NotificationPrefs load() => prefs;
  @override
  Future<void> save(NotificationPrefs p) async => prefs = p;
}

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<GoRouter> pump(WidgetTester tester,
      {required Future<String?> Function() deviceId,
      PushPermission permission = PushPermission.authorized}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(
          path: '$kTempHumidSettingPath/:deviceId',
          builder: (_, state) => Scaffold(
              body: Text('setting:${state.pathParameters['deviceId']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) => deviceId()),
        notificationPreferencesRepositoryProvider
            .overrideWithValue(_MemPrefs()),
        pushPermissionProvider.overrideWith((ref) => permission),
      ],
      child: localizedNotificationHost((context) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(
                    padding: const EdgeInsets.only(top: 62, bottom: 34)),
                child: child!),
          )),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  Finder inRow(Finder f) => find.descendant(
      of: find.byKey(NotificationSettingsScreen.envAlertKey), matching: f);

  testWidgets('하이라이트 영상 아래에 이동 행 — 제목·부제·설정하기, S39 좌표', (tester) async {
    await pump(tester, deviceId: () async => 'd1');
    expect(inRow(find.text('온습도 이탈 알림')), findsOneWidget);
    expect(inRow(find.text('적정 온습도에서 이탈했을 때 받는 알림')), findsOneWidget);
    expect(inRow(find.text('설정하기')), findsOneWidget);

    final highlight =
        tester.getRect(find.byKey(NotificationSettingsScreen.highlightKey));
    final row =
        tester.getRect(find.byKey(NotificationSettingsScreen.envAlertKey));
    final comment =
        tester.getRect(find.byKey(NotificationSettingsScreen.commentKey));
    // Figma: 하이라이트 y146 → 온습도 y226 → 댓글 y306 (행 72 + 간격 8).
    expect(row.top, closeTo(highlight.bottom + 8, 0.5));
    expect(row.left, 12);
    expect(row.width, 369);
    expect(row.height, closeTo(72, 0.5));
    expect(comment.top, closeTo(row.bottom + 8, 0.5));
    // 토글이 아니다.
    expect(inRow(find.byType(ScheduleSwitch)), findsNothing);
  });

  testWidgets('탭 → 홈 세트 기기의 온습도 설정으로 push, 뒤로 가면 알림 설정', (tester) async {
    final router = await pump(tester, deviceId: () async => 'd1');
    await tester.tap(find.byKey(NotificationSettingsScreen.envAlertKey));
    await tester.pumpAndSettle();
    expect(find.text('setting:d1'), findsOneWidget);
    // 경로 = tempHumidSettingPath('d1') — 위 placeholder가 :deviceId를 그린다.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationSettingsScreen.envAlertKey), findsOneWidget);
  });

  testWidgets('기기 없음 → 이유 표시, 눌러도 이동하지 않는다', (tester) async {
    await pump(tester, deviceId: () async => null);
    expect(inRow(find.text('홈에 연결된 사육장 기기가 없어요')), findsOneWidget);
    expect(inRow(find.text('적정 온습도에서 이탈했을 때 받는 알림')), findsNothing);
    expect(inRow(find.byType(InkWell)), findsNothing);
    await tester.tap(find.byKey(NotificationSettingsScreen.envAlertKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('setting:'), findsNothing);
  });

  testWidgets('기기 조회 실패 → 이유 표시, 이동 없음', (tester) async {
    await pump(tester, deviceId: () async => throw StateError('network'));
    expect(inRow(find.text('사육장 정보를 불러오지 못했어요')), findsOneWidget);
    await tester.tap(find.byKey(NotificationSettingsScreen.envAlertKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('setting:'), findsNothing);
  });

  testWidgets('기기 알림 꺼짐 — 흐리게 보이지만 이동은 된다', (tester) async {
    await pump(tester,
        deviceId: () async => 'd1', permission: PushPermission.denied);
    expect(
        tester
            .widget<Opacity>(
                find.byKey(NotificationSettingsScreen.featureSectionKey))
            .opacity,
        0.4);
    // 토글 행은 여전히 조작 불가.
    expect(
        tester
            .widget<IgnorePointer>(find
                .ancestor(
                    of: find.byKey(NotificationSettingsScreen.highlightKey),
                    matching: find.byType(IgnorePointer))
                .first)
            .ignoring,
        isTrue);
    await tester.tap(find.byKey(NotificationSettingsScreen.envAlertKey));
    await tester.pumpAndSettle();
    expect(find.text('setting:d1'), findsOneWidget);
  });
}
