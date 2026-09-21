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
/// [range]가 있으면 그 안으로 잘라 최신순으로. [before]는 이어 읽기 커서다.
typedef PendingClipLoader = Future<MotionClipPage> Function({
  required String cameraId,
  required DateTime after,
  ClipDateRange? range,
  MotionClipCursor? before,
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

  /// 판정 전 구간을 읽는 중임을 커서에 실어 둔다. 판정 지점(`/highlights`
  /// 첫 페이지)을 페이지마다 다시 묻지 않기 위해 값까지 같이 싣는다.
  static const _pendingPrefix = 'pending:';

  /// 서버 `until` 미배포 동안 과거 범위를 찾으러 넘기는 페이지 상한.
  static const _maxSkipPages = 20;

  /// 한 페이지.
  ///
  /// **판정 전 구간을 먼저 다 읽고, 그다음 통과 목록으로 넘어간다.** 판정이
  /// 몇 주씩 밀리면 판정 전 영상이 수천 건이라(2026-09-21 실측: 한 카메라에
  /// 1187건) 맨 위에 60건만 얹는 방식으로는 가운데가 뚫린 목록이 된다.
  Future<MotionClipPage> loadPage(ClipFeedQuery query,
      {MotionClipCursor? before}) async {
    if (_listPending == null) return _passedPage(query, before: before);
    final token = before?.token;
    if (before != null &&
        (token == null || !token.startsWith(_pendingPrefix))) {
      return _passedPage(query, before: before);
    }
    final judgedUpTo = before == null
        ? await _judgedUpTo(query.cameraId)
        : _parseWatermark(token!);
    final page = await _pendingPage(query, judgedUpTo, before);
    if (page.items.isNotEmpty) {
      final last = page.items.last;
      return (
        items: page.items,
        nextCursor: (
          startedAt: last.startedAt,
          id: last.id,
          token: '$_pendingPrefix${judgedUpTo?.toIso8601String() ?? ''}',
        ),
        // 판정 전 구간이 끝나도 그 아래에 통과 목록이 있다.
        hasMore: true,
      );
    }
    // 판정 전 구간을 다 읽었다 → 통과 목록 처음부터.
    return _passedPage(query, before: null);
  }

  static DateTime? _parseWatermark(String token) {
    final raw = token.substring(_pendingPrefix.length);
    return raw.isEmpty ? null : DateTime.parse(raw);
  }

  /// 판정 전 한 페이지. 조회가 실패하면 빈 페이지다 — 통과 목록까지 같이
  /// 죽이지 않는다.
  Future<MotionClipPage> _pendingPage(ClipFeedQuery query, DateTime? judgedUpTo,
      MotionClipCursor? before) async {
    try {
      return await _listPending!(
          cameraId: query.cameraId,
          after: judgedUpTo ?? _beforeEverything,
          range: query.range,
          before: before);
    } catch (_) {
      return (items: const <MotionClip>[], nextCursor: null, hasMore: false);
    }
  }

  /// 기간 선택과 무관하게 **전체**에서 가장 최근 통과분의 시각.
  /// 조회가 실패하면 null — 전부 판정 전으로 보고 원본을 보여준다.
  Future<DateTime?> _judgedUpTo(String cameraId) async {
    try {
      final refs = await _listRefs(cameraId: cameraId);
      if (refs.startedAts.isEmpty) return null;
      return refs.startedAts.reduce((a, b) => a.isAfter(b) ? a : b);
    } catch (_) {
      return null;
    }
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
