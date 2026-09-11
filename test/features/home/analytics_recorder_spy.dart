import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';

class AnalyticsRecorderSpy extends AnalyticsRecorder {
  final features = <AnalyticsFeature>[];
  final events = <AnalyticsEvent>[];
  @override
  int epoch = 0;
  @override
  void featureUsed(AnalyticsFeature feature, {int? epoch}) {
    if (epoch == null || epoch == this.epoch) features.add(feature);
  }

  @override
  void record(AnalyticsEvent event, {int? epoch}) {
    if (epoch == null || epoch == this.epoch) events.add(event);
  }
}
