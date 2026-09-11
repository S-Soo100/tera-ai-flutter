import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_recorder.dart';

/// Local observation token only; no BLE identifier or credential is retained.
class PairingAnalyticsTicket {
  const PairingAnalyticsTicket._(this.attempt, this.epoch);
  final int attempt;
  final int epoch;
}

/// SDK sessions may rotate while the OS permission dialog is open. Refresh the
/// epoch on a deliberate action; use independent attempts to reject old async
/// callbacks even when the SDK epoch did not change.
class PairingAnalyticsObserver {
  PairingAnalyticsObserver(this._analytics);

  final AnalyticsRecorder _analytics;
  int _attempt = 0;
  PairingAnalyticsTicket? _current;
  bool _failed = false;
  bool _succeeded = false;
  bool _submitted = false;

  PairingAnalyticsTicket startAttempt() {
    _attempt++;
    _submitted = false;
    final ticket = action();
    _record(AnalyticsEvent.pairStarted, ticket);
    return ticket;
  }

  PairingAnalyticsTicket action() {
    _submitted = false;
    _failed = false;
    _succeeded = false;
    return _current = PairingAnalyticsTicket._(_attempt, _analytics.epoch);
  }

  PairingAnalyticsTicket get current => _current!;

  PairingAnalyticsTicket deviceSelected() {
    _submitted = false;
    final ticket = action();
    _record(AnalyticsEvent.pairDeviceSelected, ticket);
    return ticket;
  }

  PairingAnalyticsTicket wifiSubmitted() {
    final ticket = action();
    _submitted = true;
    _record(AnalyticsEvent.pairWifiSubmitted, ticket);
    return ticket;
  }

  void failed(PairingAnalyticsTicket ticket) {
    if (!identical(ticket, _current) || _failed) return;
    _failed = true;
    _record(AnalyticsEvent.pairFailed, ticket);
  }

  /// The BLE stream has no request ID. Its subscription captures an attempt;
  /// within that attempt Wi-Fi outcome belongs to the latest explicit submit.
  void bleFailed(int attempt) {
    if (attempt == _attempt && _current != null) failed(current);
  }

  void wifiSucceeded(int attempt) {
    if (attempt != _attempt || !_submitted || _succeeded) return;
    _succeeded = true;
    _record(AnalyticsEvent.pairWifiSucceeded, current);
  }

  void cancelled() => _record(AnalyticsEvent.pairCancelled, action());

  void _record(AnalyticsEvent event, PairingAnalyticsTicket ticket) {
    if (identical(ticket, _current)) {
      _analytics.record(event, epoch: ticket.epoch);
    }
  }
}
