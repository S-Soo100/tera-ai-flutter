import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/community/data/community_repository.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';
import 'package:vivnanaut/features/community/presentation/community_providers.dart';

import '../home/analytics_recorder_spy.dart';

class _Repository implements CommunityRepository {
  final likeResult = Completer<void>();
  @override
  Future<Set<String>> blockedUserIds() async => {};
  @override
  Future<List<CommunityPost>> listPosts(
          {int offset = 0, int limit = 20}) async =>
      [
        CommunityPost(
            id: 'private-post',
            authorId: 'private-author',
            videoPath: 'private-path',
            createdAt: DateTime(2026)),
      ];
  @override
  Future<void> setLike(String postId, bool like) => likeResult.future;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  for (final outcome in ['success', 'failure', 'account-change']) {
    test('community like $outcome observes confirmed outcome only', () async {
      final repository = _Repository();
      final analytics = AnalyticsRecorderSpy();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        communityRepositoryProvider.overrideWithValue(repository),
        analyticsRecorderProvider.overrideWithValue(analytics),
      ]);
      addTearDown(container.dispose);
      await container.read(communityFeedProvider.future);
      expect(analytics.features, isEmpty);
      expect(analytics.events, isEmpty);
      final operation = container
          .read(communityFeedProvider.notifier)
          .toggleLike('private-post');
      expect(analytics.features, [AnalyticsFeature.community]);
      expect(analytics.events, isEmpty,
          reason: 'optimistic UI is not server success');
      if (outcome == 'account-change') analytics.epoch++;
      if (outcome == 'failure') {
        repository.likeResult.completeError(StateError('private-error'));
      } else {
        repository.likeResult.complete();
      }
      await operation;
      expect(analytics.events,
          outcome == 'success' ? [AnalyticsEvent.communityLiked] : isEmpty);
      if (outcome == 'success') {
        await container
            .read(communityFeedProvider.notifier)
            .toggleLike('private-post');
        expect(analytics.events, [AnalyticsEvent.communityLiked],
            reason: 'unlike is not a preference signal');
      }
    });
  }
}
