import '../domain/motion_clip.dart';
import '../domain/motion_clip_page.dart';
import 'camera_exceptions.dart';
import 'highlight_repository.dart';

typedef PassedRefLoader = Future<PassedClipRefPage> Function({
  required String cameraId,
  DateTime? since,
  DateTime? until,
  String? cursor,
});
typedef ClipHydrator = Future<List<MotionClip>> Function(List<String> clipIds);

/// 아직 판정되지 않은 영상 — `motion_clips` 원본에서 [after] **뒤**의 것만,
/// [range]가 있으면 그 안으로 잘라 최신순으로.
typedef PendingClipLoader = Future<List<MotionClip>> Function({
  required String cameraId,
  required DateTime after,
  ClipDateRange? range,
});

/// 카메라 탭 **전체 영상 목록**의 데이터 소스(정책 v2, 2026-09-19) — 거르지
/// 않은 `motion_clips` 대신 "하이라이트 규칙 O + 사람 확정 O 전부"만 보여준다.
///
/// petcam-api `/highlights`가 통과 clip_id를 cursor 페이지로 주고, 화면용
/// 메타(썸네일 키·행동 라벨)는 Supabase `motion_clips`에서 채운다. 반환형이
/// 기존 [MotionClipPage]라 피드 컨트롤러·플레이어·숨김 처리는 그대로다.
class PassedClipFeedSource {
  PassedClipFeedSource({
    required PassedRefLoader listRefs,
    required ClipHydrator hydrate,
    PendingClipLoader? listPending,
    this.retryDelay = const Duration(seconds: 1),
  })  : _listRefs = listRefs,
        _hydrate = hydrate,
        _listPending = listPending;

  final PassedRefLoader _listRefs;
  final ClipHydrator _hydrate;

  /// null이면 판정 전 영상을 붙이지 않는다(정책 v2 원안 그대로).
  final PendingClipLoader? _listPending;
  final Duration retryDelay;

  /// 판정된 것이 하나도 없을 때의 기준점 — 그 카메라 영상 전부가 판정 전이다.
  static final _beforeEverything = DateTime.utc(1970);

  /// 서버 `until` 미배포 동안 과거 범위를 찾으러 넘기는 페이지 상한.
  static const _maxSkipPages = 20;

  Future<MotionClipPage> loadPage(ClipFeedQuery query,
      {MotionClipCursor? before}) async {
    final page = await _passedPage(query, before: before);
    // 판정 전 영상은 **맨 위 페이지에만** 붙인다 — 아래 페이지는 이미 판정이
    // 끝난 과거라서 빠져 있다면 미통과가 맞다.
    if (before != null || _listPending == null) return page;
    final pending = await _pendingClips(query);
    if (pending.isEmpty) return page;
    final seen = {for (final clip in page.items) clip.id};
    final merged = [
      ...pending.where((clip) => seen.add(clip.id)),
      ...page.items,
    ]..sort((a, b) {
        final date = b.startedAt.compareTo(a.startedAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    return (
      items: List<MotionClip>.unmodifiable(merged),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// 아직 판정되지 않은 영상. 기준점은 **가장 최근 통과분의 촬영 시각**이다 —
  /// 판정은 시간순으로 진행되므로 그보다 뒤는 아직 안 본 것으로 본다.
  /// 조회가 실패하면 빈 목록이다(통과 목록까지 같이 죽이지 않는다).
  Future<List<MotionClip>> _pendingClips(ClipFeedQuery query) async {
    try {
      final judgedUpTo = await _judgedUpTo(query.cameraId);
      return await _listPending!(
          cameraId: query.cameraId,
          after: judgedUpTo ?? _beforeEverything,
          range: query.range);
    } catch (_) {
      return const [];
    }
  }

  /// 기간 선택과 무관하게 **전체**에서 가장 최근 통과분의 시각.
  Future<DateTime?> _judgedUpTo(String cameraId) async {
    final refs = await _listRefs(cameraId: cameraId);
    if (refs.startedAts.isEmpty) return null;
    return refs.startedAts.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<MotionClipPage> _passedPage(ClipFeedQuery query,
      {MotionClipCursor? before}) async {
    final range = query.range;
    var cursor = before?.token;
    for (var i = 0; i < _maxSkipPages; i++) {
      final refs = await _refsWithRetry(query.cameraId, range, cursor);
      // 서버가 until을 아직 모르면 상한 이후 영상이 섞여 온다 — 한 번 더 거른다.
      final wanted = <String>[
        for (var k = 0; k < refs.clipIds.length; k++)
          if (range == null ||
              refs.startedAts[k].isBefore(range.endExclusive.toUtc()))
            refs.clipIds[k],
      ];
      final clips = (await _hydrate(wanted)).toList()
        ..sort((a, b) {
          final date = b.startedAt.compareTo(a.startedAt);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });
      final hasMore = refs.hasMore && refs.nextCursor != null;
      if (clips.isNotEmpty || !hasMore) {
        return (
          items: List<MotionClip>.unmodifiable(clips),
          nextCursor: hasMore
              ? (
                  startedAt: clips.isNotEmpty
                      ? clips.last.startedAt
                      : (refs.oldestStartedAt ?? DateTime.utc(1970)),
                  id: clips.isNotEmpty ? clips.last.id : '',
                  token: refs.nextCursor,
                )
              : null,
          hasMore: hasMore,
        );
      }
      cursor = refs.nextCursor;
    }
    throw StateError('Passed clip range scan exceeded $_maxSkipPages pages');
  }

  /// `/highlights`는 조회 시 계산이라 간헐 504가 난다 — 1회만 재시도한다.
  Future<PassedClipRefPage> _refsWithRetry(
      String cameraId, ClipDateRange? range, String? cursor) async {
    Future<PassedClipRefPage> call() => _listRefs(
          cameraId: cameraId,
          since: range?.start,
          until: range?.endExclusive,
          cursor: cursor,
        );
    try {
      return await call();
    } on BackendException catch (e) {
      if (e.statusCode != 504) rethrow;
      await Future<void>.delayed(retryDelay);
      return call();
    }
  }
}
