import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/activity_summary.dart';
import '../domain/activity_window.dart';

enum ActivityDataStatus { exact, mixed, legacyEstimate, noVideo }

class ActivityData {
  const ActivityData(
      {this.intervals = const [],
      this.coverage = const [],
      this.videoClipCount = 0,
      this.exactClipCount = 0,
      this.fallbackClipCount = 0,
      this.fallbackReasons = const {},
      this.dataStatus = ActivityDataStatus.noVideo});
  final List<ActivityInterval> intervals;
  final List<ActivityCoverage> coverage;
  final int videoClipCount;
  final int exactClipCount;
  final int fallbackClipCount;
  final Map<String, int> fallbackReasons;
  final ActivityDataStatus dataStatus;

  /// Zero on recorded videos, not proof that the entire day was observed.
  bool get observedVideoZero => videoClipCount > 0 && intervals.isEmpty;
}

abstract interface class ActivityRepository {
  Future<ActivityData> load(
      {required String cameraId, required ActivityWindow window});
}

/// petcam-lab owner-activity-v1. Interval quality survives decoding and
/// collection coverage deliberately stays empty: clip counts cannot prove it.
///
/// ⚠️ **화면에서는 더 쓰지 않는다**(2026-09-21 사용자 결정) — 활동 시간은
/// "실제 움직인 구간"이 아니라 "하이라이트 규칙 통과 영상의 길이 합"이 됐고,
/// 그 계산은 [PassedClipActivityRepository]가 한다. 서버 계약 디코더로서
/// 남겨 둔다(정책이 되돌아오면 여기가 출발점이다).
class HttpActivityRepository implements ActivityRepository {
  HttpActivityRepository(
      {required String baseUrl,
      required Future<String?> Function() tokenProvider,
      http.Client? client})
      : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _client = client ?? http.Client();
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final http.Client _client;
  void dispose() => _client.close();

  @override
  Future<ActivityData> load(
      {required String cameraId, required ActivityWindow window}) async {
    if (!window.endUtc.isAfter(window.startUtc) ||
        window.endUtc.difference(window.startUtc) > const Duration(days: 31)) {
      throw ArgumentError('Activity request must span at most 31 days');
    }
    final intervals = <ActivityInterval>[];
    final cursors = <String>{};
    String? cursor;
    var videoCount = 0;
    var exactCount = 0;
    var fallbackCount = 0;
    var fallbackReasons = <String, int>{};
    var dataStatus = ActivityDataStatus.noVideo;
    do {
      final token = await _tokenProvider();
      if (token == null || token.isEmpty) {
        throw StateError('Activity authentication required');
      }
      final uri =
          Uri.parse('$_baseUrl/activity/intervals').replace(queryParameters: {
        'camera_id': cameraId,
        'from': window.startUtc.toUtc().toIso8601String(),
        'to': window.endUtc.toUtc().toIso8601String(),
        'limit': '500',
        if (cursor != null) 'cursor': cursor,
      });
      final response = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token'
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw ActivityRequestException(response.statusCode);
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid activity response');
      }
      if (decoded['camera_id'] != cameraId ||
          decoded['contract_version'] != 'owner-activity-v1' ||
          _instant(decoded['from']) != window.startUtc.toUtc() ||
          _instant(decoded['to']) != window.endUtc.toUtc()) {
        throw const FormatException('Activity response scope mismatch');
      }
      final raw = decoded['intervals'];
      if (raw is! List<Object?>) {
        throw const FormatException('Missing activity intervals');
      }
      for (final item in raw) {
        if (item is! Map<String, Object?>) {
          throw const FormatException('Invalid activity interval');
        }
        final quality = switch (item['quality']) {
          'exact' => ActivityQuality.exact,
          'legacy_estimate' => ActivityQuality.legacyEstimate,
          'mixed' => ActivityQuality.mixed,
          _ => throw const FormatException('Unknown activity quality'),
        };
        final start = _instant(item['start_at']);
        final end = _instant(item['end_at']);
        if (!end.isAfter(start) ||
            start.isBefore(window.startUtc) ||
            end.isAfter(window.endUtc)) {
          throw const FormatException('Activity interval outside query');
        }
        intervals.add(ActivityInterval(
            cameraId: cameraId,
            startUtc: start,
            endUtc: end,
            quality: quality));
      }
      videoCount = _count(decoded['video_clip_count']);
      exactCount = _count(decoded['exact_clip_count']);
      fallbackCount = _count(decoded['fallback_clip_count']);
      final reasons = decoded['fallback_reasons'];
      if (reasons is! Map<String, Object?> ||
          videoCount != exactCount + fallbackCount) {
        throw const FormatException('Invalid activity counts');
      }
      fallbackReasons = {
        for (final name in ['missing', 'pending', 'failed'])
          name: _count(reasons[name])
      };
      if (fallbackReasons.values.fold<int>(0, (a, b) => a + b) !=
          fallbackCount) {
        throw const FormatException('Invalid fallback reasons');
      }
      dataStatus = switch (decoded['data_status']) {
        'exact' => ActivityDataStatus.exact,
        'mixed' => ActivityDataStatus.mixed,
        'legacy_estimate' => ActivityDataStatus.legacyEstimate,
        'no_video' => ActivityDataStatus.noVideo,
        _ => throw const FormatException('Unknown activity data status'),
      };
      final more = decoded['has_more'];
      if (more is! bool) {
        throw const FormatException('Invalid activity pagination');
      }
      if (!more) break;
      final next = decoded['next_cursor'];
      if (next is! String ||
          next.isEmpty ||
          raw.isEmpty ||
          !cursors.add(next)) {
        throw const FormatException('Activity cursor made no progress');
      }
      cursor = next;
    } while (true);
    return ActivityData(
        intervals: List.unmodifiable(intervals),
        videoClipCount: videoCount,
        exactClipCount: exactCount,
        fallbackClipCount: fallbackCount,
        fallbackReasons: Map.unmodifiable(fallbackReasons),
        dataStatus: dataStatus);
  }

  static DateTime _instant(Object? value) {
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      {
        throw const FormatException('Activity timestamp requires timezone');
      }
    }
    final result = DateTime.tryParse(value);
    if (result == null) {
      throw const FormatException('Invalid activity timestamp');
    }
    return result.toUtc();
  }

  static int _count(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid activity count');
    }
    return value;
  }
}

class ActivityRequestException implements Exception {
  const ActivityRequestException(this.statusCode);
  final int statusCode;
}
