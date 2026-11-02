import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/env_report.dart';

/// 리포트 테이블 실시간 구독을 연다(INSERT·UPDATE, 기기 필터). [onRow]는 새 행,
/// [onRejoined]는 끊겼다 다시 붙었을 때. 돌려준 함수로 닫는다.
///
/// 저장소가 채널을 만들지 않는 이유는 실시간 이탈 저장소와 같다 — 망·앱 복귀
/// 재구독(`bindResilientChannel`)은 구독하는 provider의 Ref 수명에 묶여야 한다.
typedef EnvReportSubscribe = VoidCallback Function(
  String table,
  String deviceId, {
  required void Function(Map<String, dynamic> row) onRow,
  required VoidCallback onRejoined,
});

/// 서버 v4 일일·주간 분석 리포트 — 읽기 전용(RLS 본인 기기 SELECT, Realtime
/// publication 포함 — 2026-11-03 운영 확인). 서버가 생성·갱신하고 앱은
/// 페이지(날짜·주)마다 한 행을 본다.
class EnvReportRepository {
  EnvReportRepository(this._client);

  final SupabaseClient _client;

  static const dailyTable = 'env_daily_reports';
  static const weeklyTable = 'env_weekly_reports';

  /// [date]의 달력 날짜 = `report_date`(그날 08:00 ~ 다음 날 08:00 KST). 없으면
  /// null(서버 스위치 꺼짐·생성 전). 실패는 그대로 올린다.
  Future<EnvDailyReport?> fetchDaily(String deviceId, DateTime date) async {
    final rows = await _client
        .from(dailyTable)
        .select(
            'device_id,report_date,window_start,window_end,temp_card,humid_card')
        .eq('device_id', deviceId)
        .eq('report_date', envReportDateKey(date))
        .limit(1);
    final list = (rows as List).whereType<Map<String, dynamic>>();
    return list.isEmpty ? null : EnvDailyReport.fromRow(list.first);
  }

  /// [monday]의 달력 날짜 = `week_start`(월 08:00 ~ 다음 월 08:00 KST).
  Future<EnvWeeklyReport?> fetchWeekly(String deviceId, DateTime monday) async {
    final rows = await _client
        .from(weeklyTable)
        .select('device_id,week_start,window_start,window_end,'
            'temp_card,humid_card,notices')
        .eq('device_id', deviceId)
        .eq('week_start', envReportDateKey(monday))
        .limit(1);
    final list = (rows as List).whereType<Map<String, dynamic>>();
    return list.isEmpty ? null : EnvWeeklyReport.fromRow(list.first);
  }

  /// 일일 리포트 한 행을 본다 — 처음 조회 후 실시간 INSERT(1차)·UPDATE(09:05 이후
  /// 2차)를 반영한다(서버 §3).
  Stream<EnvDailyReport?> watchDaily(String deviceId, DateTime date,
          {required EnvReportSubscribe subscribe}) =>
      _watch(
        table: dailyTable,
        deviceId: deviceId,
        subscribe: subscribe,
        fetch: () => fetchDaily(deviceId, date),
        fromRow: (row) {
          final r = EnvDailyReport.fromRow(row);
          return r != null &&
                  r.reportDate == DateTime(date.year, date.month, date.day)
              ? r
              : null;
        },
      );

  /// 주간 리포트 한 행을 본다 — 월요일 09:05 이후 INSERT 한 번.
  Stream<EnvWeeklyReport?> watchWeekly(String deviceId, DateTime monday,
          {required EnvReportSubscribe subscribe}) =>
      _watch(
        table: weeklyTable,
        deviceId: deviceId,
        subscribe: subscribe,
        fetch: () => fetchWeekly(deviceId, monday),
        fromRow: (row) {
          final r = EnvWeeklyReport.fromRow(row);
          return r != null &&
                  r.weekStart == DateTime(monday.year, monday.month, monday.day)
              ? r
              : null;
        },
      );

  /// 구독 먼저 → 조회 → 방출. 실시간 행은 기기·키가 같을 때만([fromRow]가 null을
  /// 주면 무시). 같은 값은 다시 내보내지 않는다. 처음 조회 실패는 오류로 내보내고,
  /// 그 뒤 맞는 실시간 행이 오면 그 값으로 회복한다. 재합류하면 다시 조회한다
  /// (실패는 무시 — 이전 값 유지). 조회 중에 온 실시간 행이 조회 결과보다 새롭다.
  Stream<T?> _watch<T extends Object>({
    required String table,
    required String deviceId,
    required EnvReportSubscribe subscribe,
    required Future<T?> Function() fetch,
    required T? Function(Map<String, dynamic> row) fromRow,
  }) {
    final controller = StreamController<T?>();
    var closed = false;
    var gen = 0;
    var emitted = false;
    T? last;
    T? live; // 진행 중인 조회 이후 실시간으로 받은 값

    void emit(T? v) {
      if (closed || (emitted && v == last)) return;
      emitted = true;
      last = v;
      controller.add(v);
    }

    Future<void> refetch() async {
      final mine = ++gen;
      live = null;
      try {
        final v = await fetch();
        if (closed || mine != gen) return;
        emit(live ?? v);
      } catch (e, st) {
        if (closed || mine != gen) return;
        if (!emitted) controller.addError(e, st);
      }
    }

    void onRow(Map<String, dynamic> row) {
      if (closed) return;
      final device = row['device_id'];
      if (device != null && device.toString() != deviceId) return;
      final v = fromRow(row);
      if (v == null) return;
      live = v;
      emit(v);
    }

    final close = subscribe(table, deviceId,
        onRow: onRow, onRejoined: () => unawaited(refetch()));
    unawaited(refetch());
    controller.onCancel = () {
      closed = true;
      close();
    };
    return controller.stream;
  }
}

final envReportRepositoryProvider = Provider.autoDispose<EnvReportRepository>(
    (ref) => EnvReportRepository(ref.watch(supabaseClientProvider)));
