// v4 일일·주간 분석 리포트 조회(계획 2026-11-03 Task 2).
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/home/data/env_report_repository.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';

/// 가짜 PostgREST — GET은 [rows]를 돌려주고 요청을 기록한다.
class _FakeServer {
  List<Map<String, dynamic>> rows = [];
  bool fail = false;
  final List<http.Request> requests = [];

  SupabaseClient client() => SupabaseClient('https://example.test', 'anon',
          httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response('{"message":"boom","code":"XX000"}', 500,
              request: request, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode(rows), 200,
            request: request, headers: {'content-type': 'application/json'});
      }));
}

/// 가짜 구독 — 실시간 행과 재합류를 손으로 넣는다.
class _FakeChannel {
  void Function(Map<String, dynamic>)? onRow;
  VoidCallback? onRejoined;
  String? table;
  bool closed = false;

  VoidCallback subscribe(String table, String deviceId,
      {required void Function(Map<String, dynamic>) onRow,
      required VoidCallback onRejoined}) {
    this.table = table;
    this.onRow = onRow;
    this.onRejoined = onRejoined;
    return () => closed = true;
  }
}

Map<String, dynamic> _dailyRow(String title,
        {String date = '2026-11-02', String device = 'd1'}) =>
    {
      'device_id': device,
      'report_date': date,
      'temp_card': {'element': 'temp', 'status': 'caution', 'title': title},
      'humid_card': null,
    };

void main() {
  test('일일 — 기기·날짜로 조회하고 행을 파싱한다', () async {
    final server = _FakeServer()
      ..rows = [
        {
          'device_id': 'd1',
          'report_date': '2026-11-02',
          'temp_card': {
            'element': 'temp',
            'status': 'normal',
            'title': '주간과 야간 모두 적정 온도를 유지했어요'
          },
          'humid_card': null,
        }
      ];
    final r = await EnvReportRepository(server.client())
        .fetchDaily('d1', DateTime(2026, 11, 2, 15));
    final q = server.requests.single.url;
    expect(q.path, endsWith('/env_daily_reports'));
    expect(q.queryParameters['device_id'], 'eq.d1');
    expect(q.queryParameters['report_date'], 'eq.2026-11-02');
    expect(r!.cards.single.status, EnvReportStatus.normal);
  });

  test('일일 — 행이 없으면 null', () async {
    final server = _FakeServer();
    expect(
        await EnvReportRepository(server.client())
            .fetchDaily('d1', DateTime(2026, 11, 2)),
        isNull);
  });

  test('주간 — 월요일로 조회하고 notices까지 파싱한다', () async {
    final server = _FakeServer()
      ..rows = [
        {
          'device_id': 'd1',
          'week_start': '2026-11-02',
          'temp_card': null,
          'humid_card': null,
          'notices': [
            {
              'code': 'ERR_NO_DATA',
              'metric': 'h_a',
              'title': '주간 분석을 위한 데이터를 모으고 있어요',
              'body': '최소 3일의 데이터가 필요해요'
            }
          ],
        }
      ];
    final w = await EnvReportRepository(server.client())
        .fetchWeekly('d1', DateTime(2026, 11, 2));
    final q = server.requests.single.url;
    expect(q.path, endsWith('/env_weekly_reports'));
    expect(q.queryParameters['week_start'], 'eq.2026-11-02');
    expect(w!.noticesFor(EnvReportElement.humid).single.replacesCard, isTrue);
  });

  test('실패는 그대로 올린다', () async {
    final server = _FakeServer()..fail = true;
    await expectLater(
        EnvReportRepository(server.client())
            .fetchDaily('d1', DateTime(2026, 11, 2)),
        throwsA(isA<PostgrestException>()));
  });

  group('watch', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('realtime_update_replaces_card — 1차 조회 뒤 2차 UPDATE', () async {
      final server = _FakeServer()..rows = [_dailyRow('1차')];
      final ch = _FakeChannel();
      final got = <String?>[];
      final sub = EnvReportRepository(server.client())
          .watchDaily('d1', DateTime(2026, 11, 2), subscribe: ch.subscribe)
          .listen((r) => got.add(r?.tempCard?.title));
      await settle();
      await settle();
      expect(ch.table, 'env_daily_reports');
      ch.onRow!(_dailyRow('2차'));
      ch.onRow!(_dailyRow('2차')); // 같은 값은 다시 내보내지 않는다
      await settle();
      expect(got, ['1차', '2차']);
      await sub.cancel();
      expect(ch.closed, isTrue);
    });

    test('other_date_row_ignored — 다른 날·다른 기기 행은 무시', () async {
      final server = _FakeServer();
      final ch = _FakeChannel();
      final got = <String?>[];
      final sub = EnvReportRepository(server.client())
          .watchDaily('d1', DateTime(2026, 11, 2), subscribe: ch.subscribe)
          .listen((r) => got.add(r?.tempCard?.title));
      await settle();
      await settle();
      ch.onRow!(_dailyRow('어제 것', date: '2026-11-01'));
      ch.onRow!(_dailyRow('남의 것', device: 'd2'));
      await settle();
      expect(got, [null]);
      await sub.cancel();
    });

    test('rejoin_refetches — 끊긴 사이 생긴 행을 다시 조회로', () async {
      final server = _FakeServer();
      final ch = _FakeChannel();
      final got = <String?>[];
      final sub = EnvReportRepository(server.client())
          .watchDaily('d1', DateTime(2026, 11, 2), subscribe: ch.subscribe)
          .listen((r) => got.add(r?.tempCard?.title));
      await settle();
      await settle();
      server.rows = [_dailyRow('복귀 뒤')];
      ch.onRejoined!();
      await settle();
      await settle();
      expect(got, [null, '복귀 뒤']);
      expect(server.requests, hasLength(2));
      await sub.cancel();
    });

    test('first_fetch_error_then_row_recovers', () async {
      final server = _FakeServer()..fail = true;
      final ch = _FakeChannel();
      final got = <Object?>[];
      final sub = EnvReportRepository(server.client())
          .watchDaily('d1', DateTime(2026, 11, 2), subscribe: ch.subscribe)
          .listen((r) => got.add(r?.tempCard?.title),
              onError: (Object e) => got.add('error'));
      await settle();
      await settle();
      ch.onRow!(_dailyRow('회복'));
      await settle();
      expect(got, ['error', '회복']);
      await sub.cancel();
    });

    test('주간 — 같은 월요일 INSERT만 반영', () async {
      final server = _FakeServer();
      final ch = _FakeChannel();
      final got = <String?>[];
      final sub = EnvReportRepository(server.client())
          .watchWeekly('d1', DateTime(2026, 10, 26), subscribe: ch.subscribe)
          .listen((r) => got.add(r?.tempCard?.title));
      await settle();
      await settle();
      expect(ch.table, 'env_weekly_reports');
      ch.onRow!({
        'device_id': 'd1',
        'week_start': '2026-11-02',
        'temp_card': {'element': 'temp', 'title': '다른 주'}
      });
      ch.onRow!({
        'device_id': 'd1',
        'week_start': '2026-10-26',
        'temp_card': {'element': 'temp', 'title': '그 주'}
      });
      await settle();
      expect(got, [null, '그 주']);
      await sub.cancel();
    });
  });
}
