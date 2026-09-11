import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivnanaut/core/analytics/analytics_boundary.dart';
import 'package:vivnanaut/core/analytics/analytics_consent.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/core/analytics/clarity_setup.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'analytics_consent_test.dart' show MemoryConsentRepository;
import 'analytics_recorder_test.dart' show FakeAnalyticsSdk;

class _PlayerEntryProbe extends ConsumerStatefulWidget {
  const _PlayerEntryProbe();
  @override
  ConsumerState<_PlayerEntryProbe> createState() => _PlayerEntryProbeState();
}

class _PlayerEntryProbeState extends ConsumerState<_PlayerEntryProbe> {
  @override
  void initState() {
    super.initState();
    final analytics = ref.read(analyticsRecorderProvider);
    final epoch = analytics.epoch;
    analytics.record(AnalyticsEvent.clipRequested, epoch: epoch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      analytics.record(AnalyticsEvent.clipPlaying, epoch: epoch);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('player'));
}

void main() {
  test('only allowlisted routes produce fixed names', () {
    expect(analyticsScreenForPath('/profile'), isNull);
    expect(analyticsScreenForPath('/login?email=private'), isNull);
    expect(analyticsScreenForPath('/unknown'), isNull);
    expect(analyticsScreenForPath('/crecam/player/secret-id?token=private'),
        'clip_player');
    expect(analyticsScreenForPath('/my-pets/pet-id/edit'), 'pet_edit');
    expect(analyticsScreenForPath('/home/unknown'), isNull);
  });
  testWidgets('excluded first frame, push/pop, background and stable child',
      (tester) async {
    final sdk = FakeAnalyticsSdk();
    final repo = MemoryConsentRepository()..values['a'] = true;
    final router = GoRouter(initialLocation: '/profile', routes: [
      GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('profile'))),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home'))),
      GoRoute(
          path: '/crecam/player/:id',
          builder: (_, __) => const _PlayerEntryProbe()),
    ]);
    final container = ProviderContainer(overrides: [
      analyticsSdkProvider.overrideWithValue(sdk),
      analyticsRuntimeConfigProvider.overrideWithValue(
          const ClarityRuntimeConfig(
              enabled: true, mobile: true, projectId: 'qatest123')),
      analyticsConsentRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(User(
          id: 'a',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '')),
    ]);
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) =>
                AnalyticsBoundary(router: router, child: child!))));
    await tester.pumpAndSettle();
    expect(sdk.starts, 0);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(sdk.starts, 1);
    sdk.sessions.last();
    final element = tester.element(find.text('home'));
    final recorder = container.read(analyticsRecorderProvider);
    final activeEpoch = recorder.epoch;
    router.push('/crecam/player/private-id');
    await tester.pumpAndSettle();
    expect(recorder.epoch, activeEpoch);
    expect(sdk.events, ['clip_requested', 'clip_playing']);
    sdk.events.clear();
    router.pop();
    await tester.pumpAndSettle();
    expect(recorder.epoch, activeEpoch);
    recorder.record(AnalyticsEvent.liveRequested);
    router.push('/profile');
    await tester.pumpAndSettle();
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, ['live_requested']);
    router.pop();
    await tester.pumpAndSettle();
    sdk.sessions.last();
    expect(identical(element, tester.element(find.text('home'))), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, ['live_requested']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    sdk.sessions.last();
    recorder.record(AnalyticsEvent.liveRequested);
    expect(sdk.events, ['live_requested', 'live_requested']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nested routes and account changes discard old session callbacks',
      (tester) async {
    final sdk = FakeAnalyticsSdk();
    final repo = MemoryConsentRepository()
      ..values.addAll({'a': true, 'b': true});
    User user(String id) => User(
        id: id,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '');
    final account = StateProvider<User?>((_) => user('a'));
    final router =
        GoRouter(initialLocation: '/my-pets/pet-secret/edit', routes: [
      GoRoute(path: '/my-pets', builder: (_, __) => const Scaffold(), routes: [
        GoRoute(path: ':id', builder: (_, __) => const Scaffold(), routes: [
          GoRoute(
              path: 'edit',
              builder: (_, __) => const Scaffold(body: Text('edit'))),
        ]),
      ]),
    ]);
    final container = ProviderContainer(overrides: [
      analyticsSdkProvider.overrideWithValue(sdk),
      analyticsRuntimeConfigProvider.overrideWithValue(
          const ClarityRuntimeConfig(
              enabled: true, mobile: true, projectId: 'qatest123')),
      analyticsConsentRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => ref.watch(account)),
    ]);
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) =>
                AnalyticsBoundary(router: router, child: child!))));
    await tester.pumpAndSettle();
    expect(sdk.screens.last, 'pet_edit');
    final oldCallback = sdk.sessions.last;
    oldCallback();
    final recorder = container.read(analyticsRecorderProvider);
    final epoch = recorder.epoch;
    container.read(account.notifier).state = user('b');
    // Even before next frame/consent load, an old async completion is blocked.
    oldCallback();
    recorder.record(AnalyticsEvent.petSaved, epoch: epoch);
    expect(sdk.events, isEmpty);
    await tester.pumpAndSettle();
    oldCallback();
    recorder.record(AnalyticsEvent.petSaved);
    expect(sdk.events, isEmpty);
    sdk.sessions.last();
    recorder.record(AnalyticsEvent.petSaved);
    expect(sdk.events, ['pet_saved']);
    final element = tester.element(find.text('edit'));
    await container.read(analyticsConsentProvider.notifier).setGranted(false);
    await tester.pumpAndSettle();
    expect(identical(element, tester.element(find.text('edit'))), isTrue);
    recorder.record(AnalyticsEvent.petSaved);
    expect(sdk.events, ['pet_saved']);
    await tester.pumpWidget(const SizedBox());
  });
}
