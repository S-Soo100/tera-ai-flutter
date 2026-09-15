import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/clip_visibility_repository.dart';
import '../domain/clip_visibility.dart';

final clipVisibilityAccountProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((user) => user?.id)));
final clipVisibilityRepositoryProvider = Provider<ClipVisibilityRepository>(
    (ref) =>
        SupabaseClipVisibilityRepository(supabase: Supabase.instance.client));

final clipVisibilityProvider = StateNotifierProvider.autoDispose
    .family<ClipVisibilityController, ClipVisibilityState, String>(
        (ref, owner) {
  final account = ref.watch(clipVisibilityAccountProvider);
  final repository = ref.watch(clipVisibilityRepositoryProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final controller = ClipVisibilityController(
      repository: repository,
      accountId: owner,
      isCurrent: () => active && account == owner);
  unawaited(controller.refresh());
  return controller;
});
final currentClipVisibilityProvider = Provider<ClipVisibilityState>((ref) {
  final owner = ref.watch(clipVisibilityAccountProvider);
  return owner == null
      ? const ClipVisibilityState(loading: false)
      : ref.watch(clipVisibilityProvider(owner));
});
final hiddenClipIdsProvider = FutureProvider<Set<String>>((ref) async {
  final owner = ref.watch(clipVisibilityAccountProvider);
  if (owner == null) return const {};
  ref.watch(clipVisibilityProvider(owner));
  final controller = ref.watch(clipVisibilityProvider(owner).notifier);
  await controller.ready();
  return controller.hiddenIds;
});

/// A new screen entry or explicit refresh fetches other-device changes without
/// rebuilding the loaded camera feed on unrelated camera telemetry updates.
final clipVisibilityEntryRefreshProvider =
    FutureProvider.autoDispose.family<void, String>((ref, entry) async {
  final owner = ref.watch(clipVisibilityAccountProvider);
  if (owner == null) return;
  final controller = ref.watch(clipVisibilityProvider(owner).notifier);
  await Future<void>.value();
  await controller.refresh();
});

class ClipVisibilityController extends StateNotifier<ClipVisibilityState> {
  ClipVisibilityController(
      {required ClipVisibilityRepository repository,
      required String accountId,
      required bool Function() isCurrent})
      : _repository = repository,
        _accountId = accountId,
        _isCurrent = isCurrent,
        super(const ClipVisibilityState());
  final ClipVisibilityRepository _repository;
  final String _accountId;
  final bool Function() _isCurrent;
  Future<void>? _refreshing;
  Set<String> get hiddenIds => state.hiddenIds;

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> ready() async {
    if (state.loading) await refresh();
    if (!mounted || !_isCurrent()) {
      throw StateError('Clip visibility account changed');
    }
    if (state.loadError case final error?) throw error;
  }

  Future<void> _refresh() async {
    if (!mounted || !_isCurrent()) return;
    state = ClipVisibilityState(
        hiddenIds: state.hiddenIds, hidingIds: state.hidingIds);
    try {
      final ids = await _repository.hiddenClipIds(_accountId);
      if (!mounted || !_isCurrent()) return;
      // The ledger is additive: don't lose an acknowledged hide to an older read.
      state = ClipVisibilityState(
          hiddenIds: Set.unmodifiable({...state.hiddenIds, ...ids}),
          hidingIds: state.hidingIds,
          loading: false);
    } catch (error) {
      if (mounted && _isCurrent()) {
        state = ClipVisibilityState(
            hiddenIds: state.hiddenIds,
            hidingIds: state.hidingIds,
            loading: false,
            loadError: error);
      }
    }
  }

  Future<bool> hide(String clipId) async {
    if (!mounted || !_isCurrent() || state.hidingIds.contains(clipId)) {
      return false;
    }
    state = ClipVisibilityState(
        hiddenIds: state.hiddenIds,
        loading: state.loading,
        hidingIds: {...state.hidingIds, clipId},
        loadError: state.loadError);
    try {
      await _repository.hide(_accountId, clipId);
      if (!mounted || !_isCurrent()) return false;
      state = ClipVisibilityState(
          hiddenIds: Set.unmodifiable({...state.hiddenIds, clipId}),
          loading: state.loading,
          hidingIds: {...state.hidingIds}..remove(clipId),
          loadError: state.loadError);
      return true;
    } catch (error) {
      if (mounted && _isCurrent()) {
        state = ClipVisibilityState(
            hiddenIds: state.hiddenIds,
            loading: state.loading,
            hidingIds: {...state.hidingIds}..remove(clipId),
            loadError: state.loadError,
            saveError: error,
            failedClipId: clipId);
      }
      return false;
    }
  }
}
