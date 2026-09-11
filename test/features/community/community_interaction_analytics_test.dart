import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';
import 'package:vivnanaut/features/community/presentation/community_providers.dart';
import 'package:vivnanaut/features/community/presentation/community_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/features/profile/domain/user_profile.dart';
import 'package:vivnanaut/features/profile/presentation/profile_providers.dart';

import '../home/analytics_recorder_spy.dart';

class _Profile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

class _Feed extends CommunityFeed {
  @override
  Future<List<CommunityPost>> build() async => [];
}

void main() {
  testWidgets(
      'community automatic display and scroll are excluded; user drag is usage',
      (tester) async {
    final analytics = AnalyticsRecorderSpy();
    await tester.pumpWidget(ProviderScope(overrides: [
      analyticsRecorderProvider.overrideWithValue(analytics),
      currentUserProvider.overrideWithValue(null),
      communityFeedProvider.overrideWith(_Feed.new),
      feedImageUrlsProvider.overrideWith((ref) async => {}),
      latestNoticeProvider.overrideWith((ref) async => null),
      profileNotifierProvider.overrideWith(_Profile.new),
      nowTickProvider.overrideWith((ref) => Stream.value(DateTime(2026))),
    ], child: const MaterialApp(home: CommunityScreen())));
    await tester.pumpAndSettle();
    expect(analytics.features, isEmpty);
    final context = tester.element(find.byType(ListView).first);
    final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 200,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1);
    ScrollUpdateNotification(
            metrics: metrics, context: context, scrollDelta: 20)
        .dispatch(context);
    expect(analytics.features, isEmpty);
    ScrollUpdateNotification(
            metrics: metrics,
            context: context,
            scrollDelta: 20,
            dragDetails: DragUpdateDetails(
                globalPosition: Offset.zero, delta: const Offset(0, -20)))
        .dispatch(context);
    expect(analytics.features, [AnalyticsFeature.community]);
    expect(analytics.events, isEmpty);
  });
}
