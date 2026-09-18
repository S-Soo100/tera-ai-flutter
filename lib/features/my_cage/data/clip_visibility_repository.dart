import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ClipVisibilityRepository {
  Future<Set<String>> hiddenClipIds(String accountId);
  Future<void> hide(String accountId, String clipId);
}

/// Only writes the account's visibility ledger. Never calls DELETE, playback
/// APIs, storage APIs, favorites, memos or activity repositories.
class SupabaseClipVisibilityRepository implements ClipVisibilityRepository {
  SupabaseClipVisibilityRepository(
      {required SupabaseClient supabase, String? Function()? accountIdProvider})
      : _supabase = supabase,
        _accountId = accountIdProvider ?? (() => supabase.auth.currentUser?.id);
  static const table = 'user_hidden_clips';
  final SupabaseClient _supabase;
  final String? Function() _accountId;

  void _checkAccount(String accountId) {
    if (accountId.isEmpty || _accountId() != accountId) {
      throw StateError('Clip visibility account changed');
    }
  }

  @override
  Future<Set<String>> hiddenClipIds(String accountId) async {
    _checkAccount(accountId);
    final ids = <String>{};
    String? after;
    try {
      while (true) {
        _checkAccount(accountId);
        var query =
            _supabase.from(table).select('clip_id').eq('user_id', accountId);
        if (after != null) query = query.gt('clip_id', after);
        final rows = await query.order('clip_id').limit(1000);
        _checkAccount(accountId);
        for (final row in rows) {
          final id = row['clip_id'];
          if (id is! String || id.isEmpty) {
            throw const FormatException('Invalid hidden clip ID');
          }
          ids.add(id);
        }
        if (rows.length < 1000) return Set.unmodifiable(ids);
        final last = rows.last['clip_id'];
        if (last is! String || last == after) {
          throw const FormatException('Hidden clip cursor did not advance');
        }
        after = last;
      }
    } on PostgrestException catch (error) {
      // Read compatibility only while the additive table awaits deployment.
      // Writes deliberately propagate these errors and never fake local success.
      if (error.code == 'PGRST205' || error.code == '42P01') return const {};
      rethrow;
    }
  }

  @override
  Future<void> hide(String accountId, String clipId) async {
    _checkAccount(accountId);
    if (clipId.isEmpty) throw ArgumentError.value(clipId, 'clipId');
    // Owner RLS + source motion_clips access check is the authoritative guard.
    await _supabase.from(table).upsert(
        {'user_id': accountId, 'clip_id': clipId},
        onConflict: 'user_id,clip_id', ignoreDuplicates: true);
    _checkAccount(accountId);
  }
}
