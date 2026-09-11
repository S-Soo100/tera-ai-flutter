import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'analytics_providers.dart';
import 'analytics_recorder.dart';
import 'domain/analytics_consent_state.dart';

abstract interface class AnalyticsConsentRepository {
  bool load(String accountId);
  Future<void> save(String accountId, bool consent);
}

class HiveAnalyticsConsentRepository implements AnalyticsConsentRepository {
  const HiveAnalyticsConsentRepository();
  static const boxName = 'app_settings';
  String _key(String accountId) =>
      'clarity_consent_v1_${Uri.encodeComponent(accountId)}';
  @override
  bool load(String accountId) {
    if (!Hive.isBoxOpen(boxName)) return false;
    final Object? stored = Hive.box<Object?>(boxName).get(_key(accountId));
    return stored is bool && stored;
  }

  @override
  Future<void> save(String accountId, bool consent) async {
    if (!Hive.isBoxOpen(boxName)) throw StateError('Settings unavailable');
    await Hive.box<Object?>(boxName).put(_key(accountId), consent);
  }
}

final analyticsConsentRepositoryProvider = Provider<AnalyticsConsentRepository>(
  (ref) => const HiveAnalyticsConsentRepository(),
);
final analyticsConsentProvider =
    StateNotifierProvider<AnalyticsConsentController, AnalyticsConsentState>(
        (ref) {
  return AnalyticsConsentController(
      ref.watch(analyticsConsentRepositoryProvider),
      ref.watch(analyticsRecorderProvider));
});

class AnalyticsConsentController extends StateNotifier<AnalyticsConsentState> {
  AnalyticsConsentController(this._repository, this._recorder)
      : super(const AnalyticsConsentState());
  final AnalyticsConsentRepository _repository;
  final AnalyticsRecorder _recorder;
  int _generation = 0;
  Future<void> _saveTail = Future<void>.value();
  final _blockedAccounts = <String>{};
  final _latestWrite = <String, int>{};

  void selectAccount(String? accountId) {
    if (state.accountId == accountId) return;
    _generation++;
    _recorder.suspend();
    bool granted = false;
    bool failed = false;
    if (accountId != null && !_blockedAccounts.contains(accountId)) {
      try {
        granted = _repository.load(accountId);
      } catch (_) {
        failed = true;
      }
    }
    state = AnalyticsConsentState(
        accountId: accountId, granted: granted, saveFailed: failed);
  }

  Future<void> setGranted(bool granted) async {
    final account = state.accountId;
    if (account == null || state.saving) return;
    final generation = ++_generation;
    _latestWrite[account] = generation;
    // Even a failed write cannot restore capture during this process.
    _recorder.suspend();
    _blockedAccounts.add(account);
    state = AnalyticsConsentState(accountId: account, saving: true);
    bool success = false;
    final write = _saveTail.then((_) async {
      try {
        await _repository.save(account, granted);
        success = true;
      } catch (_) {/* Remain opted out, with a visible persistence error. */}
    });
    _saveTail = write;
    await write;
    if (success && _latestWrite[account] == generation) {
      _blockedAccounts.remove(account);
    }
    if (!mounted || generation != _generation || state.accountId != account) {
      return;
    }
    state = AnalyticsConsentState(
        accountId: account, granted: success && granted, saveFailed: !success);
  }
}
