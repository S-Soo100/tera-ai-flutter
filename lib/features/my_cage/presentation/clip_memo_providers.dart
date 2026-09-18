import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/clip_memo_repository.dart';
import '../domain/clip_memo.dart';

typedef ClipMemoKey = ({String ownerId, String clipId});

/// Dedicated, lazily opened box. Hive owns its app lifetime: route disposal must
/// not close a box while an account-scoped write is still finishing.
final clipMemoRepositoryProvider =
    FutureProvider<ClipMemoRepository>((ref) async {
  final box = await Hive.openBox<String>(HiveClipMemoRepository.boxName);
  return HiveClipMemoRepository(box: box);
});

final clipMemoAccountProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((user) => user?.id)));

final clipMemoProvider =
    FutureProvider.autoDispose.family<ClipMemo?, ClipMemoKey>((ref, key) async {
  final owner = ref.watch(clipMemoAccountProvider);
  if (owner != key.ownerId) return null;
  var active = true;
  ref.onDispose(() => active = false);
  final repository = await ref.watch(clipMemoRepositoryProvider.future);
  if (!active) return null;
  final memo = await repository.read(key.ownerId, key.clipId);
  return active ? memo : null;
});

final clipMemoControllerProvider = StateNotifierProvider.autoDispose
    .family<ClipMemoController, AsyncValue<void>, ClipMemoKey>((ref, key) {
  final owner = ref.watch(clipMemoAccountProvider);
  final repository = ref.watch(clipMemoRepositoryProvider.future);
  var active = true;
  ref.onDispose(() => active = false);
  return ClipMemoController(
    key: key,
    repository: () => repository,
    isCurrent: () => active && owner == key.ownerId,
    onChanged: () => ref.invalidate(clipMemoProvider(key)),
  );
});

/// A local-only writer. A stale editor can finish a write to its original
/// account key, but cannot publish it into the next account's reader or UI.
class ClipMemoController extends StateNotifier<AsyncValue<void>> {
  ClipMemoController({
    required ClipMemoKey key,
    required Future<ClipMemoRepository> Function() repository,
    required bool Function() isCurrent,
    required void Function() onChanged,
  })  : _key = key,
        _repository = repository,
        _isCurrent = isCurrent,
        _onChanged = onChanged,
        super(const AsyncData(null));

  final ClipMemoKey _key;
  final Future<ClipMemoRepository> Function() _repository;
  final bool Function() _isCurrent;
  final void Function() _onChanged;

  Future<bool> save(String text) =>
      _run((repository) => repository.save(_key.ownerId, _key.clipId, text));
  Future<bool> remove() =>
      _run((repository) => repository.remove(_key.ownerId, _key.clipId));

  Future<bool> _run(Future<void> Function(ClipMemoRepository) operation) async {
    if (!mounted || !_isCurrent() || state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final repository = await _repository();
      if (!mounted || !_isCurrent()) return false;
      await operation(repository);
      if (!mounted || !_isCurrent()) return false;
      state = const AsyncData(null);
      _onChanged();
      return true;
    } catch (error, stack) {
      if (mounted && _isCurrent()) state = AsyncError(error, stack);
      return false;
    }
  }
}
