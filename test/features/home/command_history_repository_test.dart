import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/home/data/command_history_repository.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/shared/domain/control_log.dart';

Map<String, Object?> _row(int id, DateTime at, {String action = 'fan_on'}) => {
      'id': id.toString().padLeft(6, '0'),
      'action': action,
      'status': 'acked',
      'result': 'ok',
      'issued_at': at.toUtc().toIso8601String(),
      'payload': <String, Object?>{},
    };

TelemetryBucket _bucket(DateTime at, double temp) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: temp,
      tMin: temp,
      tMax: temp,
      hAvg: 60,
      hMin: 60,
      hMax: 60,
    );

void main() {
  final from = DateTime.utc(2026, 9, 15);
  final to = from.add(const Duration(days: 1));

  test('timer expiry is not invented as a continuous run until a later off',
      () {
    final on = _row(1, from)..['payload'] = {'duration_ms': 60000};
    final stop = from.add(const Duration(days: 2));
    final logs = buildControlLog(
        commandRows: [on, _row(2, stop, action: 'fan_off')],
        buckets: [_bucket(from, 30), _bucket(stop, 25)]);
    expect(logs.last.duration, isNull);
    expect(logs.last.deltaTemperature, isNull);
  });

  test('more than 2000 rows and equal-time page boundary keep every ID once',
      () async {
    var page = 0;
    final client = SupabaseClient('https://test.supabase.co', 'test-key',
        httpClient: MockClient((request) async {
      final query = request.url.queryParameters;
      expect(query['order'], 'issued_at.asc.nullslast,id.asc.nullslast');
      expect(query['status'], 'eq.acked');
      expect(query['result'], 'eq.ok');
      expect(query['device_id'], 'eq.device');
      expect(query['offset'], isNull);
      if (page > 0) {
        expect(
            query['or'],
            contains(
                'id.gt.${(page * 500 - 1).clamp(0, 2500).toString().padLeft(6, '0')}'));
      }
      final start = page++ * 500;
      return http.Response(
          jsonEncode([
            for (var i = start; i < start + 500 && i < 2501; i++) _row(i, from),
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final rows = await CommandHistoryRepository(client)
        .readPeriod('device', from: from, to: to);
    expect(rows.length, 2501);
    expect(rows.map((row) => row['id']).toSet().length, 2501);
    expect(page, 7); // an empty page ends the bounded interval query
  });

  test(
      'server-limited short pages still continue until the interval is exhausted',
      () async {
    var calls = 0;
    final client = SupabaseClient('https://test.supabase.co', 'test-key',
        httpClient: MockClient((request) async {
      final page = calls++;
      return http.Response(jsonEncode(page < 2 ? [_row(page, from)] : []), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final rows = await CommandHistoryRepository(client)
        .readPeriod('device', from: from, to: to);
    expect(rows.length, 2);
    expect(calls, 3);
  });

  test(
      'failed second page throws instead of returning partial or empty success',
      () async {
    var calls = 0;
    final client = SupabaseClient('https://test.supabase.co', 'test-key',
        httpClient: MockClient((request) async {
      if (calls++ == 0) {
        return http.Response(jsonEncode([_row(1, from)]), 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      return http.Response(
          jsonEncode({'message': 'failed', 'code': 'XX000'}), 500,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    await expectLater(
        CommandHistoryRepository(client)
            .readPeriod('device', from: from, to: to),
        throwsA(isA<PostgrestException>()));
  });

  test('failed context lookup never becomes an empty successful history',
      () async {
    final client = SupabaseClient('https://test.supabase.co', 'test-key',
        httpClient: MockClient((request) async => http.Response(
            jsonEncode({'message': 'unavailable', 'code': 'XX000'}), 500,
            request: request, headers: {'content-type': 'application/json'})));
    addTearDown(client.dispose);
    await expectLater(
        CommandHistoryRepository(client).readPreceding('device', before: from),
        throwsA(isA<PostgrestException>()));
  });

  test('latest prior off does not manufacture a start for today', () {
    final logs = buildControlLog(commandRows: [
      _row(1, from.subtract(const Duration(days: 3)), action: 'fan_off'),
      _row(2, from.add(const Duration(hours: 2)), action: 'fan_off'),
    ], buckets: [], visibleFrom: from, visibleTo: to);
    expect(logs.single.duration, isNull);
    expect(logs.single.deltaTemperature, isNull);
  });

  test(
      'latest successful actuator context pairs a continuous fan started three days ago',
      () async {
    final start = from.subtract(const Duration(days: 3));
    final stop = from.add(const Duration(hours: 2));
    var contextRequests = 0;
    var periodRequests = 0;
    final client = SupabaseClient('https://test.supabase.co', 'test-key',
        httpClient: MockClient((request) async {
      final q = request.url.queryParameters;
      final latest = q['order'] == 'issued_at.desc.nullslast,id.desc.nullslast';
      if (latest) {
        contextRequests++;
        expect(q['limit'], '1');
        expect(q['result'], 'eq.ok');
        final isFan = q['action'] == 'in.("fan_on","fan_off","fan_toggle")';
        return http.Response(jsonEncode(isFan ? [_row(1, start)] : []), 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      final rows =
          periodRequests++ == 0 ? [_row(2, stop, action: 'fan_off')] : [];
      return http.Response(jsonEncode(rows), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final history = await CommandHistoryRepository(client)
        .readWithContext('device', from: from, to: to);
    expect(contextRequests, 5);
    expect(history.preceding, hasLength(1));
    final logs = buildControlLog(
        commandRows: [...history.preceding, ...history.rows],
        buckets: [_bucket(start, 30), _bucket(stop, 25)],
        visibleFrom: from,
        visibleTo: to);
    expect(logs, hasLength(1));
    expect(logs.single.deltaTemperature, -5);
    expect(logs.single.duration, const Duration(days: 3, hours: 2));
  });
}
