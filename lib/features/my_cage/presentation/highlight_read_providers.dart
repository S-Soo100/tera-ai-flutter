import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/highlight_read_store.dart';

final highlightReadStoreProvider =
    Provider((ref) => const HighlightReadStore());
final highlightReadProvider = StateNotifierProvider.family<
    HighlightReadController, bool, HighlightReadKey>((ref, key) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final store = ref.watch(highlightReadStoreProvider);
  return HighlightReadController(owner == key.ownerId && store.read(key),
      () => owner == key.ownerId ? store.markRead(key) : Future.value());
});

class HighlightReadController extends StateNotifier<bool> {
  HighlightReadController(super.state, this._save);
  final Future<void> Function() _save;
  Future<void> markRead() async {
    if (state) return;
    await _save();
    if (mounted) state = true;
  }
}
