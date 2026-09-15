import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivanaut/features/my_pets/data/activity_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';

void main() {
  final window = ActivityWindow.day(2026, 9, 15);
  Map<String, Object?> page({bool more = false, String quality = 'exact'}) => {
        'camera_id': 'camera',
        'contract_version': 'owner-activity-v1',
        'from': window.startUtc.toIso8601String(),
        'to': window.endUtc.toIso8601String(),
        'intervals': [
          {
            'start_at': '2026-09-14T15:00:00Z',
            'end_at': '2026-09-14T15:00:30Z',
            'quality': quality
          }
        ],
        'video_clip_count': 1,
        'exact_clip_count': quality == 'exact' ? 1 : 0,
        'fallback_clip_count': quality == 'exact' ? 0 : 1,
        'fallback_reasons': {
          'missing': quality == 'exact' ? 0 : 1,
          'pending': 0,
          'failed': 0
        },
        'data_status': quality,
        'has_more': more,
        'next_cursor': more ? 'opaque' : null,
      };
  test(
      'auth, UTC range and opaque pagination retain estimated quality with unknown coverage',
      () async {
    var calls = 0;
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer jwt');
          expect(request.url.path, '/activity/intervals');
          expect(
              request.url.queryParameters['from'], '2026-09-14T15:00:00.000Z');
          expect(request.url.queryParameters.containsKey('hidden'), isFalse);
          if (calls++ == 0) {
            return http.Response(jsonEncode(page(more: true)), 200);
          }
          expect(request.url.queryParameters['cursor'], 'opaque');
          return http.Response(
              jsonEncode(page(quality: 'legacy_estimate')), 200);
        }));
    final data = await repo.load(cameraId: 'camera', window: window);
    expect(calls, 2);
    expect(data.intervals.last.quality, ActivityQuality.legacyEstimate);
    expect(data.coverage, isEmpty);
    expect(data.videoClipCount,
        1); // Metadata describes whole range, not each page.
  });
  test('wrong camera response is rejected', () async {
    final body = page()..['camera_id'] = 'other';
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)));
    expect(
        repo.load(cameraId: 'camera', window: window), throwsFormatException);
  });
  test(
      'no video remains missing; analysis zero is not collection complete zero',
      () async {
    final body = page()..['intervals'] = [];
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)));
    final data = await repo.load(cameraId: 'camera', window: window);
    expect(data.intervals, isEmpty);
    expect(data.observedVideoZero, isTrue);
    expect(data.dataStatus, ActivityDataStatus.exact);
    expect(data.coverage, isEmpty);
  });
  test('no_video preserves missing rather than an observed zero', () async {
    final body = page()
      ..['intervals'] = []
      ..['video_clip_count'] = 0
      ..['exact_clip_count'] = 0
      ..['data_status'] = 'no_video';
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)));
    final data = await repo.load(cameraId: 'camera', window: window);
    expect(data.dataStatus, ActivityDataStatus.noVideo);
    expect(data.observedVideoZero, isFalse);
  });
  test('timezone-less activity instant cannot depend on device timezone',
      () async {
    final body = page()
      ..['intervals'] = [
        {
          'start_at': '2026-09-14T15:00:00',
          'end_at': '2026-09-14T15:00:30Z',
          'quality': 'exact'
        }
      ];
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)));
    expect(
        repo.load(cameraId: 'camera', window: window), throwsFormatException);
  });
  test('repeated cursor aborts rather than looping forever', () async {
    final repo = HttpActivityRepository(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'jwt',
        client: MockClient(
            (_) async => http.Response(jsonEncode(page(more: true)), 200)));
    expect(
        repo.load(cameraId: 'camera', window: window), throwsFormatException);
  });
}
