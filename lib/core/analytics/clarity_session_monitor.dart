import 'dart:async';

/// Confirms the SDK session boundary even when Clarity's consent processing
/// replaces our native callback. URLs are only compared in memory, never
/// emitted, persisted, logged, or returned to application callers.
class ClaritySessionMonitor {
  ClaritySessionMonitor({
    required String? Function() readSessionUrl,
    required bool Function(void Function()) requestSession,
  })  : _readSessionUrl = readSessionUrl,
        _requestSession = requestSession;

  final String? Function() _readSessionUrl;
  final bool Function(void Function()) _requestSession;
  Timer? _timer;
  int _generation = 0;
  String? _previousUrl;
  void Function()? _onReady;

  bool start(void Function() onReady) {
    cancel();
    final generation = _generation;
    try {
      _previousUrl = _readSessionUrl();
      _onReady = onReady;
      if (!_requestSession(() => _confirm(generation))) {
        cancel();
        return false;
      }
      // The SDK may have called back synchronously.
      if (_onReady == null) return true;
      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (generation != _generation) return;
        if (timer.tick > 60) {
          cancel();
          return;
        }
        try {
          final currentUrl = _readSessionUrl();
          if (currentUrl != null && currentUrl != _previousUrl) {
            _confirm(generation);
            return;
          }
          if (timer.tick >= 60) cancel();
        } catch (_) {
          cancel();
        }
      });
      return true;
    } catch (_) {
      cancel();
      return false;
    }
  }

  void _confirm(int generation) {
    if (generation != _generation || _onReady == null) return;
    final callback = _onReady!;
    cancel();
    callback();
  }

  /// Used for pause/unbind as well as success, failure and timeout. The
  /// generation check also rejects callbacks still retained by the SDK.
  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _previousUrl = null;
    _onReady = null;
  }
}
