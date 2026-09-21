import 'dart:math' as math;

import '../../my_cage/data/passed_clip_feed_source.dart';
import '../domain/activity_summary.dart';
import '../domain/activity_window.dart';
import 'activity_repository.dart';

/// [PassedClipRefPage]와 같은 모양 — 테스트가 petcam-api 없이 페이지를 만든다.
typedef PassedClipRefPageLike = ({
  List<String> clipIds,
  List<DateTime> startedAts,
  DateTime? oldestStartedAt,
  String? nextCursor,
  bool hasMore,
});

/// 활동 시간을 **하이라이트 규칙을 통과한 영상의 길이 합**으로 센다
/// (2026-09-21 사용자 결정).
///
/// 이전에는 petcam-api `/activity/intervals`가 주는 "실제로 움직인 구간"을
/// 합산했다. 그 값은 1분짜리 영상 안에서 개체가 3초 움직이면 3초였다 —
/// 사용자가 "영상 한 편만큼 움직였다"고 읽는 것과 어긋났다. 이제 통과한
/// 영상 한 편은 그 길이만큼 활동으로 센다.
///
/// 집계 파이프라인([aggregateActivityDay])은 그대로다 — 구간이 겹치면
/// 합집합으로 한 번만 세고, 시간대 버킷·카메라 배정 구간 자르기도 같다.
class PassedClipActivityRepository implements ActivityRepository {
  PassedClipActivityRepository({
    required Future<PassedClipRefPageLike> Function({
      required String cameraId,
      DateTime? since,
      DateTime? until,
      String? cursor,
    }) listRefs,
    required ClipHydrator hydrate,
  })  : _listRefs = listRefs,
        _hydrate = hydrate;

  final Future<PassedClipRefPageLike> Function({
    required String cameraId,
    DateTime? since,
    DateTime? until,
    String? cursor,
  }) _listRefs;
  final ClipHydrator _hydrate;

  /// Supabase `inFilter`의 URL 길이 한계 — 통과 목록이 길면 나눠서 채운다.
  static const _hydrateBatch = 100;

  /// 커서가 제자리를 돌 때의 안전장치. 하루치 통과분이 이보다 많을 수는 없다.
  static const _maxPages = 50;

  @override
  Future<ActivityData> load({
    required String cameraId,
    required ActivityWindow window,
  }) async {
    final ids = <String>[];
    final seen = <String>{};
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final refs = await _listRefs(
          cameraId: cameraId,
          since: window.startUtc,
          until: window.endUtc,
          cursor: cursor);
      for (final id in refs.clipIds) {
        if (seen.add(id)) ids.add(id);
      }
      final next = refs.nextCursor;
      if (!refs.hasMore || next == null || next == cursor) break;
      cursor = next;
    }

    final intervals = <ActivityInterval>[];
    var clips = 0;
    for (var i = 0; i < ids.length; i += _hydrateBatch) {
      final batch = ids.sublist(i, math.min(i + _hydrateBatch, ids.length));
      for (final clip in await _hydrate(batch)) {
        // 원본이 지워진 id는 여기서 조용히 빠진다(목록과 같은 규칙).
        clips++;
        final start = clip.startedAt.toUtc();
        final rawEnd = start
            .add(Duration(microseconds: (clip.durationSec * 1000000).round()));
        // 창 끝을 넘긴 꼬리는 자른다 — 그 시간은 다음 날의 몫이다.
        final end = rawEnd.isAfter(window.endUtc) ? window.endUtc : rawEnd;
        if (!end.isAfter(start)) continue;
        intervals.add(ActivityInterval(
            cameraId: cameraId,
            startUtc: start,
            endUtc: end,
            // 길이를 아는 영상이라 추정이 아니다.
            quality: ActivityQuality.exact));
      }
    }

    return ActivityData(
      intervals: List.unmodifiable(intervals),
      videoClipCount: clips,
      exactClipCount: clips,
      fallbackClipCount: 0,
      fallbackReasons: const {'missing': 0, 'pending': 0, 'failed': 0},
      dataStatus:
          clips == 0 ? ActivityDataStatus.noVideo : ActivityDataStatus.exact,
    );
  }
}
