import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/widgets.dart';
import 'analytics_recorder.dart';
import 'clarity_setup.dart';
import 'clarity_session_monitor.dart';

/// The only module allowed to call the concrete SDK. Manual initialize keeps
/// the MaterialApp/Router subtree stable when consent changes.
class ClarityAnalyticsSdk implements AnalyticsSdk {
  ClarityAnalyticsSdk(
    this.config, {
    ClaritySessionMonitor? sessionMonitor,
    bool Function(String, String)? tagWriter,
  })  : _sessionMonitor = sessionMonitor ??
            ClaritySessionMonitor(
              readSessionUrl: Clarity.getCurrentSessionUrl,
              requestSession: (callback) =>
                  Clarity.startNewSession((_) => callback()),
            ),
        _tagWriter = tagWriter ?? Clarity.setCustomTag;
  final ClarityRuntimeConfig config;
  final ClaritySessionMonitor _sessionMonitor;
  final bool Function(String, String) _tagWriter;
  BuildContext? _context;
  void Function()? _onSession;
  bool _recordingReady = false;
  void bind(BuildContext context) {
    _context = context;
  }

  void unbind() {
    _recordingReady = false;
    _sessionMonitor.cancel();
    _context = null;
  }

  @override
  bool initialize(void Function() onSession) {
    final context = _context;
    if (!config.canCollect || context == null || !context.mounted) return false;
    _onSession = onSession;
    if (!Clarity.setOnSessionStartedCallback((_) {
      if (_recordingReady) _sessionReady();
    })) {
      return false;
    }
    return Clarity.initialize(
        context, buildClarityConfig(projectId: config.resolvedProjectId));
  }

  @override
  bool startNewSession(void Function() onSession) {
    _onSession = onSession;
    _recordingReady = false;
    return _sessionMonitor.start(_sessionReady);
  }

  void _sessionReady() {
    _recordingReady = true;
    try {
      _tagWriter('environment', config.environmentName);
    } catch (_) {/* Optional tagging must never affect the app. */}
    _onSession?.call();
  }

  @override
  bool pause() {
    _recordingReady = false;
    _sessionMonitor.cancel();
    return Clarity.pause();
  }

  @override
  bool resume() => Clarity.resume();
  @override
  bool setScreen(String screen) => Clarity.setCurrentScreenName(screen);
  @override
  bool sendEvent(String event) => Clarity.sendCustomEvent(event);
  @override
  bool setTag(String key, String value) => _tagWriter(key, value);
  @override
  bool setConsent(bool granted) => Clarity.consent(false, granted);
}
