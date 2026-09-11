import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/features/community/data/community_post_publisher.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';
import 'package:vivnanaut/features/community/presentation/clip_select_screen.dart';
import 'package:vivnanaut/features/community/presentation/community_providers.dart';
import 'package:vivnanaut/features/community/presentation/compose_screen.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';
import 'package:vivnanaut/features/profile/domain/user_profile.dart';
import 'package:vivnanaut/features/profile/presentation/profile_providers.dart';

import '../home/analytics_recorder_spy.dart';

class _Publisher implements CommunityPostPublisher {
  final result = Completer<void>();
  @override
  Future<void> publish(
          {required FavoriteClip fav,
          String? caption,
          Pet? pet,
          void Function(double progress)? onProgress}) =>
      result.future;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Profile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => UserProfile(
      id: 'private-user',
      displayName: 'private-name',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
}

class _Feed extends CommunityFeed {
  _Feed({this.failRefresh = false});
  final bool failRefresh;
  @override
  Future<List<CommunityPost>> build() async => [];
  @override
  Future<void> refresh() async {
    if (failRefresh) throw StateError('refresh-failed');
  }
}

void main() {
  for (final outcome in [
    'success',
    'failure',
    'account-change',
    'refresh-failure'
  ]) {
    testWidgets('publish $outcome reports confirmed publication only',
        (tester) async {
      final analytics = AnalyticsRecorderSpy();
      final publisher = _Publisher();
      final draft = ComposeDraft(FavoriteClip(
          clipId: 'private-clip',
          cameraId: 'private-camera',
          startedAt: DateTime(2026),
          durationSec: 5,
          filePath: 'private-path',
          sizeBytes: 100,
          favoritedAt: DateTime(2026),
          ownerId: 'private-user'));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => ComposeScreen(draft: draft)),
        GoRoute(
            path: '/community',
            builder: (_, __) => const Scaffold(body: Text('done'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        analyticsRecorderProvider.overrideWithValue(analytics),
        communityPublisherProvider.overrideWithValue(publisher),
        communityFeedProvider.overrideWith(
            () => _Feed(failRefresh: outcome == 'refresh-failure')),
        profileNotifierProvider.overrideWith(_Profile.new),
        enclosureSetsProvider.overrideWith((ref) async => []),
        motionThumbnailProvider.overrideWith((ref, clipId) async => null),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(analytics.features, isEmpty);
      expect(analytics.events, isEmpty);
      // Load profile before the publishing action (the real app header does so).
      final container =
          ProviderScope.containerOf(tester.element(find.byType(ComposeScreen)));
      await container.read(profileNotifierProvider.future);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(analytics.features, [AnalyticsFeature.community]);
      expect(analytics.events, isEmpty);
      if (outcome == 'account-change') analytics.epoch++;
      if (outcome == 'failure') {
        publisher.result.completeError(StateError('private-error'));
      } else {
        publisher.result.complete();
      }
      await tester.pumpAndSettle();
      expect(
          analytics.events,
          ['success', 'refresh-failure'].contains(outcome)
              ? [AnalyticsEvent.communityPublished]
              : isEmpty);
    });
  }
}
