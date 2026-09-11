import 'analytics_events.dart';

/// SDK seam; methods return acceptance, never server delivery confirmation.
abstract interface class AnalyticsSdk {
  bool initialize(void Function() onSession);
  bool pause();
  bool resume();
  bool startNewSession(void Function() onSession);
  bool setScreen(String screen);
  bool sendEvent(String event);
  bool setTag(String key, String value);
  bool setConsent(bool granted);
}

/// Inert until the app boundary supplies an approved, visible session.
/// This provider-owned object holds no user data beyond an in-memory account
/// comparison. Account identifiers are never passed to [AnalyticsSdk].
class AnalyticsRecorder {
  AnalyticsRecorder({AnalyticsSdk? sdk}) : _sdk = sdk;

  final AnalyticsSdk? _sdk;
  final _features = <AnalyticsFeature>{};
  int _epoch = 0;
  int _generation = 0;
  bool _wanted = false;
  bool _ready = false;
  bool _initialized = false;
  bool _disposed = false;
  String? _accountId;
  String? _screenName;
  bool _consent = false;

  int get epoch => _epoch;

  void featureUsed(AnalyticsFeature feature, {int? epoch}) {
    if (!_accepts(epoch) || _features.contains(feature)) return;
    if (_safe(() => _sdk!.sendEvent(feature.wireName))) {
      _features.add(feature);
    }
  }

  void record(AnalyticsEvent event, {int? epoch}) {
    if (_accepts(epoch)) _safe(() => _sdk!.sendEvent(event.wireName));
  }

  bool _accepts(int? expectedEpoch) =>
      !_disposed &&
      _wanted &&
      _ready &&
      _sdk != null &&
      (expectedEpoch == null || expectedEpoch == _epoch);

  /// Called synchronously on exclusion/auth/consent changes. New allowed
  /// screens are activated by the host after their first completed frame.
  void synchronize({
    required bool enabled,
    required bool consent,
    required String? accountId,
    required String? screenName,
    required bool foreground,
  }) {
    if (_disposed) return;
    final wanted = enabled &&
        consent &&
        accountId != null &&
        screenName != null &&
        foreground &&
        _sdk != null;
    final boundaryChanged =
        wanted != _wanted || accountId != _accountId || consent != _consent;
    _accountId = accountId;
    _consent = consent;
    if (boundaryChanged) {
      _epoch++;
      _generation++;
      _ready = false;
      _wanted = wanted;
      _features.clear();
      if (_initialized) _safe(() => _sdk!.pause());
    }
    if (!wanted) return;
    if (screenName != _screenName || boundaryChanged) {
      _screenName = screenName;
      if (!_safe(() => _sdk.setScreen(screenName))) {
        suspend();
        return;
      }
    }
    if (!boundaryChanged && _initialized) return;
    final generation = _generation;
    void onSession() {
      if (_disposed || !_wanted || _generation != generation) return;
      _epoch++;
      _features.clear();
      _ready = true;
      _safe(() => _sdk.setTag('analytics_schema', '1'));
    }

    if (!_initialized) {
      // Persist the paused/consent state before asynchronous initialization.
      if (!_safe(() => _sdk.pause()) ||
          !_safe(() => _sdk.setConsent(true)) ||
          !_safe(() => _sdk.initialize(onSession))) {
        suspend();
        return;
      }
      _initialized = true;
    }
    if (!_safe(() => _sdk.startNewSession(onSession)) ||
        !_safe(() => _sdk.resume())) {
      suspend();
    }
  }

  /// Close our event gate before any await (e.g. consent persistence/logout).
  void suspend() {
    _epoch++;
    _generation++;
    _ready = false;
    _wanted = false;
    _features.clear();
    if (_initialized) _safe(() => _sdk!.pause());
  }

  void dispose() {
    suspend();
    _disposed = true;
  }

  bool _safe(bool Function() action) {
    try {
      return action();
    } catch (_) {
      return false;
    }
  }
}
