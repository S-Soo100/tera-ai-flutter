import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/domain/push_consent_flow.dart';
import 'package:vivanaut/features/notification/domain/push_lifecycle_controller.dart';
import 'package:vivanaut/features/notification/presentation/push_pre_popup.dart';
import 'package:vivanaut/features/notification/presentation/push_providers.dart';
import 'package:vivanaut/features/profile/data/notification_preferences_repository.dart';
import 'notification_repository_test.dart';
import 'notification_test_host.dart';
import 'push_lifecycle_controller_test.dart';

class _MemoryPrefsRepo implements NotificationPreferencesRepository {
  NotificationPrefs saved = const NotificationPrefs();
  @override
  NotificationPrefs load() => saved;
  @override
  Future<void> save(NotificationPrefs prefs) async => saved = prefs;
}

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<(FakePushMessaging, _MemoryPrefsRepo, MemoryPushPreferences)> pump(
      WidgetTester tester, PushPermission permission,
      {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final messaging = FakePushMessaging()..permission = permission;
    final repo = _MemoryPrefsRepo();
    final preferences = MemoryPushPreferences();
    final controller = PushLifecycleController(
        messaging: messaging,
        devices: RecordingPushDevices(),
        preferences: preferences,
        appVersion: () async => '1+1',
        locale: () => 'ko',
        findNotification: (_, __) async => null,
        markRead: (_) async {},
        display: (_) async {},
        navigate: (_) {},
        permissionChanged: (_) {},
        reportError: (_) {});
    await controller.setUser(signedIn ? 'a' : null);
    addTearDown(controller.dispose);
    addTearDown(messaging.close);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider
              .overrideWith((ref) => signedIn ? notificationUser('a') : null),
          pushPreferencesProvider.overrideWithValue(preferences),
          pushMessagingProvider.overrideWithValue(messaging),
          pushLifecycleControllerProvider.overrideWithValue(controller),
          notificationPreferencesRepositoryProvider.overrideWithValue(repo),
        ],
        child: localizedNotificationHost((context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Consumer(
                  builder: (context, ref, _) => Scaffold(
                      body: Column(children: [
                        TextButton(
                            onPressed: () => askPushConsent(
                                context, ref, PushTopic.highlight),
                            child: const Text('ask-highlight')),
                        TextButton(
                            onPressed: () => askPushConsent(
                                context, ref, PushTopic.community),
                            child: const Text('ask-community')),
                        TextButton(
                            onPressed: () => askPushConsent(
                                context, ref, PushTopic.device),
                            child: const Text('ask-device')),
                      ]))),
            ))));
    await tester.pumpAndSettle();
    return (messaging, repo, preferences);
  }

  Future<void> ask(WidgetTester tester, String which) async {
    await tester.tap(find.text('ask-$which'));
    await tester.pumpAndSettle();
  }

  testWidgets('하이라이트 프리팝업 — Figma 문구·크기, 받기는 주제 켜고 시스템 팝업',
      (tester) async {
    final (messaging, repo, _) =
        await pump(tester, PushPermission.notDetermined);
    await ask(tester, 'highlight');
    expect(find.text('하이라이트 영상 알림을 켜시겠습니까?'), findsOneWidget);
    expect(
        find.text(keepAllWords(
            '도마뱀이 활발하게 움직인 순간을 감지하여 하이라이트 영상으로 선별해 보내드립니다')),
        findsOneWidget);
    expect(keepAllWords('감지 하여').split(' ').first, '감\u2060지',
        reason: '어절 안에서는 줄이 바뀌지 않는다');
    final card = tester.getRect(find.descendant(
        of: find.byKey(const Key('push_prepopup_highlight')),
        matching: find.byType(ConstrainedBox)).first);
    expect(card.width, 345);
    final accept = tester.getRect(find.byKey(const Key('push_prepopup_accept')));
    final decline =
        tester.getRect(find.byKey(const Key('push_prepopup_decline')));
    expect(accept.height, 44);
    expect(decline.width, closeTo(142.5, 0.5));
    expect(accept.left - decline.right, closeTo(12, 0.5));
    expect(decline.left < accept.left, isTrue, reason: '받지 않기가 왼쪽');

    repo.saved = repo.saved.copyWith(highlight: false);
    await tester.tap(find.text('알림 받기'));
    await tester.pumpAndSettle();
    expect(repo.saved.highlight, isTrue);
    expect(messaging.requests, 1);
    expect(find.text('수신 거부 완료'), findsNothing);
  });

  testWidgets('시스템 알림이 켜진 상태에서 받지 않기 → 주제 끄고 수신 거부 완료',
      (tester) async {
    final (messaging, repo, _) =
        await pump(tester, PushPermission.authorized);
    await ask(tester, 'community');
    // Figma 두 줄 제목은 줄마다 한 줄(좁으면 축소).
    expect(find.text('커뮤니티 댓글 및 좋아요'), findsOneWidget);
    expect(find.text('알림을 켜시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('알림 받지 않기'));
    await tester.pumpAndSettle();
    expect(repo.saved.comment, isFalse);
    expect(repo.saved.like, isFalse);
    expect(messaging.requests, 0);
    expect(find.text('수신 거부 완료'), findsOneWidget);
    expect(find.text(keepAllWords('[마이페이지 > 알림 > 알림 허용 ON] 에서 재설정 가능합니다')),
        findsOneWidget);
    await tester.tap(find.text('common_confirm'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('수신 거부 완료'), findsNothing);
  });

  testWidgets('주제별로 한 번만 묻고, 다른 주제는 따로 묻는다', (tester) async {
    final (_, _, preferences) = await pump(tester, PushPermission.authorized);
    await ask(tester, 'highlight');
    await tester.tap(find.text('알림 받기'));
    await tester.pumpAndSettle();
    await ask(tester, 'highlight');
    expect(find.text('하이라이트 영상 알림을 켜시겠습니까?'), findsNothing);
    await ask(tester, 'community');
    expect(find.text('커뮤니티 댓글 및 좋아요'), findsOneWidget);
    expect(preferences.asked, {'highlight', 'community'});
  });

  testWidgets('로그아웃 상태에선 묻지 않는다', (tester) async {
    await pump(tester, PushPermission.notDetermined, signedIn: false);
    await ask(tester, 'highlight');
    expect(find.text('하이라이트 영상 알림을 켜시겠습니까?'), findsNothing);
  });

  testWidgets('사육장 — 권한 미요청이면 묻고 받기는 시스템 팝업만', (tester) async {
    final (messaging, repo, preferences) =
        await pump(tester, PushPermission.notDetermined);
    await ask(tester, 'device');
    expect(find.text('사육장 알림을 켜시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('알림 받기'));
    await tester.pumpAndSettle();
    expect(messaging.requests, 1);
    expect(repo.saved.highlight, isTrue, reason: '토글은 그대로');
    expect(preferences.asked, {'device'});
  });

  testWidgets('사육장 — 이미 허용됐으면 묻지 않고 기회도 소모하지 않는다',
      (tester) async {
    final (_, _, preferences) = await pump(tester, PushPermission.authorized);
    await ask(tester, 'device');
    expect(find.text('사육장 알림을 켜시겠습니까?'), findsNothing);
    expect(preferences.asked, isEmpty);
  });

  testWidgets('사육장 — 받지 않기는 닫기만(수신 거부 완료 없음)', (tester) async {
    final (messaging, _, _) = await pump(tester, PushPermission.denied);
    await ask(tester, 'device');
    await tester.tap(find.text('알림 받지 않기'));
    await tester.pumpAndSettle();
    expect(find.text('수신 거부 완료'), findsNothing);
    expect(messaging.requests, 0);
  });
}
