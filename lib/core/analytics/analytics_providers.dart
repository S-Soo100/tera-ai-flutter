import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_recorder.dart';

/// Standalone feature widgets do not initialize analytics, Hive or auth.
/// The application provides the SDK adapter through this dependency.
final analyticsSdkProvider = Provider<AnalyticsSdk?>((ref) => null);

final analyticsRecorderProvider = Provider<AnalyticsRecorder>((ref) {
  final recorder = AnalyticsRecorder(sdk: ref.watch(analyticsSdkProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});
