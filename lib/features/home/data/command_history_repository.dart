import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/control_log.dart';

typedef CommandHistoryRow = Map<String, Object?>;

class CommandHistoryWindow {
  const CommandHistoryWindow({required this.rows, required this.preceding});
  final List<CommandHistoryRow> rows;

  /// At most one successful command per actuator, including OFF and unknown
  /// direction commands. These supply context and are never displayed as today.
  final List<CommandHistoryRow> preceding;
}

/// Reads commands by their existing TEXT status/result contract, not an assumed
/// JSON result. Every request is bounded and errors propagate to AsyncError.
class CommandHistoryRepository {
  const CommandHistoryRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 500;
  static const _columns = 'id,action,status,result,issued_at,payload,source';

  /// 예약이 낸 명령(`source='schedule'`) 최근 [since]부터, 최신순 최대 200건.
  Future<List<CommandHistoryRow>> recentScheduleRuns(String deviceId,
      {required DateTime since}) async {
    final rows = await client
        .from('commands')
        .select('source_id,status,result,issued_at')
        .eq('device_id', deviceId)
        .eq('source', 'schedule')
        .gte('issued_at', since.toUtc().toIso8601String())
        .order('issued_at', ascending: false)
        .limit(200);
    return [for (final r in rows) Map<String, Object?>.from(r)];
  }

  Future<List<CommandHistoryRow>> readPeriod(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) return const [];
    final rows = <CommandHistoryRow>[];
    ({DateTime at, String id})? cursor;
    while (true) {
      var query = client
          .from('commands')
          .select(_columns)
          .eq('device_id', deviceId)
          .eq('status', 'acked')
          .eq('result', 'ok')
          .inFilter('action', controlLogActions())
          .gte('issued_at', from.toUtc().toIso8601String())
          .lt('issued_at', to.toUtc().toIso8601String());
      if (cursor != null) {
        final time = cursor.at.toUtc().toIso8601String();
        query = query.or(
            'issued_at.gt.$time,and(issued_at.eq.$time,id.gt.${cursor.id})');
      }
      final page = await query
          .order('issued_at', ascending: true)
          .order('id', ascending: true)
          .limit(pageSize);
      // Do not treat a short page as EOF: PostgREST may have a smaller cap.
      if (page.isEmpty) return rows;
      for (final raw in page) {
        final row = Map<String, Object?>.from(raw);
        final next = _cursor(row);
        if (next.at.isBefore(from) ||
            !next.at.isBefore(to) ||
            (cursor != null && _compare(next, cursor) <= 0)) {
          throw const FormatException('Command history cursor did not advance');
        }
        rows.add(row);
        cursor = next;
      }
    }
  }

  Future<CommandHistoryWindow> readWithContext(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final (rows, preceding) = await (
      readPeriod(deviceId, from: from, to: to),
      readPreceding(deviceId, before: from),
    ).wait;
    return CommandHistoryWindow(rows: rows, preceding: preceding);
  }

  Future<List<CommandHistoryRow>> readPreceding(
    String deviceId, {
    required DateTime before,
  }) async {
    final pages = await Future.wait([
      for (final kind in MarkerKind.values)
        client
            .from('commands')
            .select(_columns)
            .eq('device_id', deviceId)
            .eq('status', 'acked')
            .eq('result', 'ok')
            .inFilter('action', controlLogActions(kind))
            .lt('issued_at', before.toUtc().toIso8601String())
            .order('issued_at', ascending: false)
            .order('id', ascending: false)
            .limit(1),
    ]);
    final preceding = <CommandHistoryRow>[];
    for (final page in pages) {
      if (page.isEmpty) continue;
      final row = Map<String, Object?>.from(page.single);
      if (!_cursor(row).at.isBefore(before)) {
        throw const FormatException(
            'Command history context is outside its range');
      }
      preceding.add(row);
    }
    return preceding;
  }

  static ({DateTime at, String id}) _cursor(CommandHistoryRow row) {
    final id = row['id'];
    final stamp = row['issued_at'];
    final at = stamp is String ? DateTime.tryParse(stamp) : null;
    // UUIDs are the deployed ID type. This also prevents values from injecting
    // PostgREST operators into a composite cursor.
    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        at == null) {
      throw const FormatException('Malformed command history row');
    }
    return (at: at, id: id);
  }

  static int _compare(
      ({DateTime at, String id}) a, ({DateTime at, String id}) b) {
    final time = a.at.compareTo(b.at);
    return time != 0 ? time : a.id.compareTo(b.id);
  }
}
