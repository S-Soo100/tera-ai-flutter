import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../domain/clip_memo.dart';

abstract interface class ClipMemoRepository {
  Future<ClipMemo?> read(String accountId, String clipId);

  /// Stores text verbatim. Blank text is rejected; use [remove] to delete.
  Future<void> save(String accountId, String clipId, String text);
  Future<void> remove(String accountId, String clipId);
}

/// Account-scoped, device-local memos with no bookmark or server dependency.
///
/// The caller owns the lifecycle of an opened, dedicated [Box<String>].
/// Operations for an account are serialized across repository instances sharing
/// that box in the same isolate. Close the box only after pending calls finish.
class HiveClipMemoRepository implements ClipMemoRepository {
  HiveClipMemoRepository({
    required Box<String> box,
    DateTime Function()? clock,
    int Function(int)? nextInt,
  })  : _box = box,
        _clock = clock ?? DateTime.now,
        _nextInt = nextInt ?? Random().nextInt;

  static const boxName = 'clip_memos';
  static final _queues = Expando<Map<String, Future<void>>>();

  final Box<String> _box;
  final DateTime Function() _clock;
  final int Function(int) _nextInt;

  String _memoKey(String accountId, String clipId) =>
      'memo:${jsonEncode([accountId, clipId])}';

  String _lastColorKey(String accountId) =>
      'last-color:${jsonEncode(accountId)}';

  Future<T> _serialized<T>(
      String accountId, String clipId, Future<T> Function() operation) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Must not be blank');
    }
    if (clipId.trim().isEmpty) {
      throw ArgumentError.value(clipId, 'clipId', 'Must not be blank');
    }
    final queues = _queues[_box] ??= <String, Future<void>>{};
    final previous = queues[accountId];
    final done = Completer<void>();
    queues[accountId] = done.future;
    try {
      if (previous != null) await previous;
      return await operation();
    } finally {
      done.complete();
      if (identical(queues[accountId], done.future)) {
        queues.remove(accountId);
      }
    }
  }

  ClipMemo? _read(String accountId, String clipId) {
    final raw = _box.get(_memoKey(accountId, clipId));
    if (raw == null) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid clip memo record');
    }
    final text = decoded['text'];
    final colorIndex = decoded['colorIndex'];
    final timestamp = decoded['updatedAt'];
    final updatedAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (decoded['clipId'] != clipId ||
        text is! String ||
        text.trim().isEmpty ||
        colorIndex is! int ||
        colorIndex < 0 ||
        colorIndex >= 6 ||
        updatedAt == null) {
      throw const FormatException('Invalid clip memo fields');
    }
    return ClipMemo(
      clipId: clipId,
      text: text,
      colorIndex: colorIndex,
      updatedAt: updatedAt.toUtc(),
    );
  }

  int _assignColor(String accountId) {
    final raw = _box.get(_lastColorKey(accountId));
    if (raw == null) return _nextInt(6);
    final previous = int.tryParse(raw);
    if (previous == null || previous < 0 || previous >= 6) {
      throw const FormatException('Invalid clip memo color history');
    }
    final candidate = _nextInt(5);
    return candidate >= previous ? candidate + 1 : candidate;
  }

  @override
  Future<ClipMemo?> read(String accountId, String clipId) =>
      _serialized(accountId, clipId, () async => _read(accountId, clipId));

  @override
  Future<void> save(String accountId, String clipId, String text) =>
      _serialized(accountId, clipId, () async {
        if (text.trim().isEmpty) {
          throw ArgumentError.value(text, 'text', 'Must not be blank');
        }
        final existing = _read(accountId, clipId);
        final colorIndex = existing?.colorIndex ?? _assignColor(accountId);
        await _box.putAll({
          _memoKey(accountId, clipId): jsonEncode({
            'clipId': clipId,
            'text': text,
            'colorIndex': colorIndex,
            'updatedAt': _clock().toUtc().toIso8601String(),
          }),
          if (existing == null) _lastColorKey(accountId): '$colorIndex',
        });
      });

  @override
  Future<void> remove(String accountId, String clipId) => _serialized(
      accountId, clipId, () => _box.delete(_memoKey(accountId, clipId)));
}
