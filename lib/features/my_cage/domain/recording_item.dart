import 'live_recording.dart';
import 'motion_clip.dart';
import 'motion_clip_page.dart';
import 'player_entry.dart';

/// 서버에 올라간 직접 녹화 한 건 — Supabase 직결 `live_recordings`
/// (`status='ready'`, RLS 본인만, 합의 결과 2026-10-20).
class ServerLiveRecording {
  const ServerLiveRecording({
    required this.id,
    required this.cameraId,
    required this.startedAt,
    required this.durationMs,
    required this.hasThumbnail,
    this.sizeBytes,
    this.width,
    this.height,
    this.createdAt,
  });

  final String id;

  /// null = 카메라가 지워졌다("삭제된 카메라" — 보관함에서만 의미).
  final String? cameraId;
  final DateTime startedAt;
  final int durationMs;
  final bool hasThumbnail;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final DateTime? createdAt;

  /// 직결 SELECT에서 고르는 열(계약 그대로).
  static const columns = 'id, camera_id, started_at, duration_ms, size_bytes, '
      'width, height, has_thumbnail, created_at';

  /// 한 행. 필수 열이 없거나 타입이 다르면 null(그 행만 버린다).
  static ServerLiveRecording? tryFromJson(Map<String, Object?> j) {
    final id = j['id'];
    final started = j['started_at'];
    final duration = j['duration_ms'];
    if (id is! String || id.isEmpty || started is! String || duration is! num) {
      return null;
    }
    final startedAt = DateTime.tryParse(started);
    if (startedAt == null) return null;
    final camera = j['camera_id'];
    final created = j['created_at'];
    final thumb = j['has_thumbnail'];
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return ServerLiveRecording(
      id: id,
      cameraId: camera is String && camera.isNotEmpty ? camera : null,
      startedAt: startedAt,
      durationMs: duration.toInt(),
      hasThumbnail: thumb is bool && thumb,
      sizeBytes: asInt(j['size_bytes']),
      width: asInt(j['width']),
      height: asInt(j['height']),
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }
}

/// 서버 목록 + 그 목록을 받은 계정 — 계정을 바꾸는 동안 이전 계정 목록이
/// 잠깐 남아 보이지 않게 합칠 때 계정을 맞춰 본다.
typedef ServerRecordingList = ({
  String ownerId,
  List<ServerLiveRecording> items
});

/// 화면에 보이는 직접 녹화 한 건 — 이 폰의 녹화([local]) 또는 서버에만 있는
/// 녹화([server]). 같은 녹화가 둘 다 있으면 로컬이 이긴다(폰 파일로 재생).
class RecordingItem {
  const RecordingItem.local(LiveRecording this.local) : server = null;
  const RecordingItem.server(ServerLiveRecording this.server) : local = null;

  final LiveRecording? local;
  final ServerLiveRecording? server;

  PlayerEntry get entry => switch (local) {
        final l? => RecordingEntry(l.id),
        null => ServerRecordingEntry(server!.id),
      };

  /// 재생목록·선택·메모 키([PlayerEntry.key]).
  String get key => entry.key;

  String? get cameraId => local?.cameraId ?? server?.cameraId;
  DateTime get startedAt => local?.startedAt ?? server!.startedAt;
  int get durationMs => local?.durationMs ?? server!.durationMs;
  Duration get duration => Duration(milliseconds: durationMs);

  /// 서버 녹화 id — 폰 파일이 없을 때 서버 URL로 받는 데 쓴다. 로컬은
  /// 업로드가 끝났을 때만(등록만 된 pending은 서버에 파일이 없다).
  String? get serverId => switch (local) {
        final l? => l.uploadState == LiveRecordingUploadState.ready
            ? l.recordingId
            : null,
        null => server!.id,
      };

  /// 올리는 중 — 흐리게, 누를 수 없음(2026-10-21 사용자 결정). 대기·실패는
  /// 흐리게 하지 않는다.
  bool get uploading =>
      local?.uploadState == LiveRecordingUploadState.uploading;

  LiveRecordingUploadBadge get uploadBadge =>
      local?.uploadBadge ?? LiveRecordingUploadBadge.none;
}

/// 이 폰 녹화와 서버 녹화를 합친다(최신순).
///
/// - 서버 행의 id가 어떤 로컬 행의 `recordingId`와 같으면 서버 쪽을 뺀다(로컬
///   우선). [deletingServerIds]는 사용자가 지웠고 서버 DELETE가 아직인 녹화
///   (로컬 `deleting` 행·서버 전용 삭제 중) — 서버 목록에서 되살아나지 않게 뺀다.
/// - [local]에는 `deleting` 행이 없어야 한다(`LiveRecordingRepository.list`).
List<RecordingItem> mergeRecordings({
  required List<LiveRecording> local,
  required List<ServerLiveRecording> server,
  Set<String> deletingServerIds = const {},
}) {
  final known = <String>{
    for (final r in local)
      if (r.recordingId case final id?) id,
    ...deletingServerIds,
  };
  final out = <RecordingItem>[
    for (final r in local)
      if (r.uploadState != LiveRecordingUploadState.deleting)
        RecordingItem.local(r),
    for (final s in server)
      if (!known.contains(s.id)) RecordingItem.server(s),
  ];
  // 같은 서버 id가 두 번 오면 하나만.
  final seen = <String>{};
  out.retainWhere((i) => seen.add(i.key));
  out.sort(compareRecordingItems);
  return List.unmodifiable(out);
}

/// 최신순, 같은 시각이면 키 내림차순(고정 순서).
int compareRecordingItems(RecordingItem a, RecordingItem b) {
  final t = b.startedAt.compareTo(a.startedAt);
  return t != 0 ? t : b.key.compareTo(a.key);
}

/// 카메라 탭 목록에 들어갈 녹화 — 그 카메라 것 + 기간([range], 로컬 자정
/// 경계 — 일반 영상과 같은 기준).
List<RecordingItem> recordingsForFeed(
        List<RecordingItem> all, String cameraId, ClipDateRange? range) =>
    [
      for (final r in all)
        if (r.cameraId == cameraId &&
            (range == null ||
                (!r.startedAt.isBefore(range.start) &&
                    r.startedAt.isBefore(range.endExclusive))))
          r
    ];

/// 카메라 탭 시간대별 목록의 한 칸.
sealed class FeedEntry {
  const FeedEntry();
  String get key;
  DateTime get startedAt;
  String? get cameraId;
}

final class ClipFeedEntry extends FeedEntry {
  const ClipFeedEntry(this.clip);
  final MotionClip clip;
  @override
  String get key => clip.id;
  @override
  DateTime get startedAt => clip.startedAt;
  @override
  String? get cameraId => clip.cameraId;
}

final class RecordingFeedEntry extends FeedEntry {
  const RecordingFeedEntry(this.item);
  final RecordingItem item;
  @override
  String get key => item.key;
  @override
  DateTime get startedAt => item.startedAt;
  @override
  String? get cameraId => item.cameraId;

  /// 누를 수 있는지(재생·선택) — 올리는 중이면 아니다.
  bool get enabled => !item.uploading;
}

/// 커서 페이지로 받은 일반 영상([clips], 최신순)에 녹화를 시각순으로 끼운다.
///
/// 녹화는 개수가 적어 카메라별 전체를 한 번에 받지만, 영상은 60개씩 온다 —
/// 아직 안 불러온 구간의 녹화를 지금 붙이면 목록 끝에 섞여 순서가 틀어지고,
/// 다음 페이지가 오면 위치가 바뀐다. 그래서 **불러온 가장 오래된 영상보다
/// 오래되지 않은 녹화만** 넣고([hasMore]가 true일 때), 목록 끝(hasMore false)에
/// 닿으면 남은 녹화를 모두 붙인다. 페이지가 늘수록 경계가 내려가 녹화가
/// 사라지거나 두 번 나오지 않는다.
List<FeedEntry> mergeFeedWithRecordings({
  required List<MotionClip> clips,
  required bool hasMore,
  required List<RecordingItem> recordings,
}) {
  final DateTime? floor;
  if (!hasMore) {
    floor = null;
  } else if (clips.isEmpty) {
    // 첫 페이지 전(또는 아직 더 있음) — 경계를 모르니 아무것도 안 붙인다.
    return [for (final c in clips) ClipFeedEntry(c)];
  } else {
    floor =
        clips.map((c) => c.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }
  final out = <FeedEntry>[
    for (final c in clips) ClipFeedEntry(c),
    for (final r in recordings)
      if (floor == null || !r.startedAt.isBefore(floor)) RecordingFeedEntry(r),
  ];
  final seen = <String>{};
  out.retainWhere((e) => seen.add(e.key));
  out.sort((a, b) {
    final t = b.startedAt.compareTo(a.startedAt);
    return t != 0 ? t : b.key.compareTo(a.key);
  });
  return List.unmodifiable(out);
}

/// 플레이어가 다음 페이지를 붙일 때의 재생목록과 새 경계.
///
/// [floor]는 지금까지 불러온 가장 오래된 일반 영상의 시각(목록 화면이 넘긴
/// 값, null = 아직 영상 없음). 이미 있는 항목 뒤에 새 페이지 영상과, 경계
/// 사이(새 페이지의 가장 오래된 영상 ≤ 녹화 < [floor])의 녹화를 시각순으로
/// 붙인다. 목록 끝([hasMore] false)이면 [floor]보다 오래된 녹화를 모두 붙인다.
/// 목록 화면의 [mergeFeedWithRecordings]와 같은 경계 규칙이다 — 플레이어를
/// 연 뒤 업로드가 끝난 녹화처럼 경계 안쪽인데 목록에 없던 것은 끝에 엉뚱하게
/// 붙이지 않는다.
({List<String> keys, DateTime? floor}) appendFeedPage({
  required List<String> existing,
  required List<MotionClip> pageClips,
  required bool hasMore,
  required DateTime? floor,
  required List<RecordingItem> recordings,
}) {
  final have = existing.toSet();
  final fresh = [
    for (final c in pageClips)
      if (!have.contains(c.id)) c
  ];
  DateTime? next = floor;
  for (final c in fresh) {
    if (next == null || c.startedAt.isBefore(next)) next = c.startedAt;
  }
  // 아직 더 있는데 새 영상이 없으면 경계를 모른다 — 녹화는 다음 페이지에.
  final lower = hasMore ? (fresh.isEmpty ? null : next) : null;
  final recs = <RecordingItem>[
    if (!hasMore || fresh.isNotEmpty)
      for (final r in recordings)
        if (!have.contains(r.key) &&
            !r.uploading &&
            (floor == null || r.startedAt.isBefore(floor)) &&
            (lower == null || !r.startedAt.isBefore(lower)))
          r
  ];
  final appended = <FeedEntry>[
    for (final c in fresh) ClipFeedEntry(c),
    for (final r in recs) RecordingFeedEntry(r),
  ]..sort((a, b) {
      final t = b.startedAt.compareTo(a.startedAt);
      return t != 0 ? t : b.key.compareTo(a.key);
    });
  final seen = {...have};
  return (
    keys: [
      ...existing,
      for (final e in appended)
        if (seen.add(e.key)) e.key
    ],
    floor: next,
  );
}
