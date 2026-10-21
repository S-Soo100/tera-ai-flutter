// 직접 녹화 합치기(이 폰 + 서버)·카메라 탭 끼워넣기 규칙(2026-10-21 F단계).
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/player_entry.dart';
import 'package:vivanaut/features/my_cage/domain/recording_item.dart';

DateTime _t(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, 21, hour, minute);

LiveRecording _local(String id, DateTime at,
        {String camera = 'cam',
        String? recordingId,
        LiveRecordingUploadState state = LiveRecordingUploadState.ready}) =>
    LiveRecording(
        id: id,
        ownerId: 'u1',
        cameraId: camera,
        startedAt: at,
        durationMs: 30000,
        filePath: 'live_recordings/u1/$id.mp4',
        recordingId: recordingId,
        uploadState: state);

ServerLiveRecording _server(String id, DateTime at, {String? camera = 'cam'}) =>
    ServerLiveRecording(
        id: id,
        cameraId: camera,
        startedAt: at,
        durationMs: 40000,
        hasThumbnail: true);

MotionClip _clip(String id, DateTime at) =>
    MotionClip(id: id, cameraId: 'cam', startedAt: at, durationSec: 8);

RecordingItem _item(String id, DateTime at,
        {LiveRecordingUploadState state = LiveRecordingUploadState.ready}) =>
    RecordingItem.local(_local(id, at, state: state));

void main() {
  group('PlayerEntry 키', () {
    test('서버 녹화는 rec:srv:, 폰 녹화는 rec:, 나머지는 clip id', () {
      expect(PlayerEntry.parse('rec:srv:abc'), isA<ServerRecordingEntry>());
      expect(
          (PlayerEntry.parse('rec:srv:abc') as ServerRecordingEntry).serverId,
          'abc');
      expect(PlayerEntry.parse('rec:abc'), isA<RecordingEntry>());
      expect(PlayerEntry.parse('abc'), isA<ClipEntry>());
      expect(const ServerRecordingEntry('x').key, 'rec:srv:x');
      expect(PlayerEntry.parse('rec:srv:x').isRecording, isTrue);
      expect(PlayerEntry.parse('rec:x').isRecording, isTrue);
      expect(PlayerEntry.parse('x').isRecording, isFalse);
    });
  });

  group('ServerLiveRecording.tryFromJson', () {
    test('계약 열을 읽고 camera_id null = 삭제된 카메라', () {
      final r = ServerLiveRecording.tryFromJson({
        'id': 's1',
        'camera_id': null,
        'started_at': '2026-10-21T12:00:00Z',
        'duration_ms': 61000,
        'size_bytes': 1234,
        'width': 1280,
        'height': 960,
        'has_thumbnail': true,
        'created_at': '2026-10-21T12:03:00Z',
      })!;
      expect(r.cameraId, isNull);
      expect(r.startedAt, DateTime.utc(2026, 10, 21, 12));
      expect(r.durationMs, 61000);
      expect(r.hasThumbnail, isTrue);
      expect(r.width, 1280);
    });

    test('필수 열이 없거나 타입이 다르면 그 행만 버린다', () {
      expect(ServerLiveRecording.tryFromJson({'id': 's1'}), isNull);
      expect(
          ServerLiveRecording.tryFromJson({
            'id': 's1',
            'started_at': 'nope',
            'duration_ms': 1,
          }),
          isNull);
      expect(
          ServerLiveRecording.tryFromJson({
            'id': 1,
            'started_at': '2026-10-21T12:00:00Z',
            'duration_ms': 1,
          }),
          isNull);
    });
  });

  group('mergeRecordings', () {
    test('같은 녹화는 로컬 우선 하나, 서버 전용은 rec:srv:, 최신순', () {
      final merged = mergeRecordings(local: [
        _local('a', _t(10), recordingId: 's-a'),
        _local('b', _t(12)),
      ], server: [
        _server('s-a', _t(10)),
        _server('s-c', _t(11)),
      ]);
      expect(merged.map((r) => r.key), ['rec:b', 'rec:srv:s-c', 'rec:a']);
      expect(merged.last.local, isNotNull);
    });

    test('지우는 중인 녹화는 서버 목록에서 되살아나지 않는다', () {
      final merged = mergeRecordings(
          local: const [],
          server: [_server('s-a', _t(10)), _server('s-b', _t(9))],
          deletingServerIds: {'s-a'});
      expect(merged.map((r) => r.key), ['rec:srv:s-b']);
    });

    test('serverId — 폰 녹화는 업로드가 끝났을 때만, 서버 녹화는 그 id', () {
      expect(
          RecordingItem.local(_local('a', _t(1),
                  recordingId: 's', state: LiveRecordingUploadState.pending))
              .serverId,
          isNull);
      expect(RecordingItem.local(_local('a', _t(1), recordingId: 's')).serverId,
          's');
      expect(RecordingItem.server(_server('s', _t(1))).serverId, 's');
    });

    test('올리는 중만 uploading — 대기·실패는 아니다', () {
      bool up(LiveRecordingUploadState s) =>
          RecordingItem.local(_local('a', _t(1), state: s)).uploading;
      expect(up(LiveRecordingUploadState.uploading), isTrue);
      expect(up(LiveRecordingUploadState.pending), isFalse);
      expect(up(LiveRecordingUploadState.failed), isFalse);
      expect(up(LiveRecordingUploadState.blocked), isFalse);
    });
  });

  group('recordingsForFeed', () {
    test('그 카메라 것만, 기간은 [start, endExclusive)', () {
      final all = mergeRecordings(local: [
        _local('in', DateTime(2026, 10, 21, 23, 59)),
        _local('edge', DateTime(2026, 10, 21)),
        _local('next', DateTime(2026, 10, 22)),
        _local('other', DateTime(2026, 10, 21, 9), camera: 'cam2'),
      ], server: [
        _server('gone', DateTime(2026, 10, 21, 8), camera: null),
      ]);
      final range =
          (start: DateTime(2026, 10, 21), endExclusive: DateTime(2026, 10, 22));
      expect(recordingsForFeed(all, 'cam', range).map((r) => r.key),
          ['rec:in', 'rec:edge']);
      expect(recordingsForFeed(all, 'cam', null).map((r) => r.key),
          ['rec:next', 'rec:in', 'rec:edge']);
    });
  });

  group('mergeFeedWithRecordings — 페이지 경계', () {
    final recs = [
      _item('r-new', _t(20)),
      _item('r-mid', _t(15)),
      _item('r-old', _t(5)),
    ];

    test('불러온 가장 오래된 영상보다 오래되지 않은 녹화만 시각순으로', () {
      final entries = mergeFeedWithRecordings(
          clips: [_clip('c1', _t(18)), _clip('c2', _t(12))],
          hasMore: true,
          recordings: recs);
      expect(entries.map((e) => e.key), ['rec:r-new', 'c1', 'rec:r-mid', 'c2']);
    });

    test('같은 시각의 녹화는 경계 안(포함)', () {
      final entries = mergeFeedWithRecordings(
          clips: [_clip('c1', _t(15))], hasMore: true, recordings: recs);
      expect(entries.map((e) => e.key), ['rec:r-new', 'rec:r-mid', 'c1']);
    });

    test('목록 끝이면 남은 녹화를 모두 붙인다', () {
      final entries = mergeFeedWithRecordings(
          clips: [_clip('c1', _t(18)), _clip('c2', _t(12))],
          hasMore: false,
          recordings: recs);
      expect(entries.map((e) => e.key),
          ['rec:r-new', 'c1', 'rec:r-mid', 'c2', 'rec:r-old']);
    });

    test('첫 페이지 전(영상 없음, 더 있음)엔 녹화도 없다 — 영상이 없으면 녹화만', () {
      expect(
          mergeFeedWithRecordings(
              clips: const [], hasMore: true, recordings: recs),
          isEmpty);
      expect(
          mergeFeedWithRecordings(
                  clips: const [], hasMore: false, recordings: recs)
              .map((e) => e.key),
          ['rec:r-new', 'rec:r-mid', 'rec:r-old']);
    });

    test('페이지가 늘어도 녹화가 사라지거나 두 번 나오지 않는다', () {
      final page1 = [_clip('c1', _t(18)), _clip('c2', _t(12))];
      final page2 = [_clip('c3', _t(8)), _clip('c4', _t(3))];
      final first = mergeFeedWithRecordings(
          clips: page1, hasMore: true, recordings: recs);
      final second = mergeFeedWithRecordings(
          clips: [...page1, ...page2], hasMore: true, recordings: recs);
      final last = mergeFeedWithRecordings(
          clips: [...page1, ...page2], hasMore: false, recordings: recs);
      expect(first.map((e) => e.key).where((k) => k.startsWith('rec:')),
          ['rec:r-new', 'rec:r-mid']);
      expect(second.map((e) => e.key),
          ['rec:r-new', 'c1', 'rec:r-mid', 'c2', 'c3', 'rec:r-old', 'c4']);
      expect(last.map((e) => e.key).toSet().length, last.length);
      // 앞 페이지의 순서는 다음 페이지가 와도 그대로다.
      expect(
          second.map((e) => e.key).take(first.length), first.map((e) => e.key));
    });

    test('올리는 중인 녹화도 칸은 있다(enabled false)', () {
      final entries = mergeFeedWithRecordings(
          clips: const [],
          hasMore: false,
          recordings: [
            _item('up', _t(1), state: LiveRecordingUploadState.uploading)
          ]);
      expect((entries.single as RecordingFeedEntry).enabled, isFalse);
    });
  });

  group('appendFeedPage — 플레이어 다음 페이지', () {
    final recs = [
      _item('r-new', _t(20)),
      _item('r-mid', _t(10)),
      _item('r-old', _t(5)),
      _item('r-up', _t(9), state: LiveRecordingUploadState.uploading),
    ];

    test('경계 사이 녹화만 시각순으로 붙이고 새 경계를 돌려준다', () {
      final out = appendFeedPage(
          existing: const ['rec:r-new', 'c1'],
          pageClips: [_clip('c2', _t(11)), _clip('c3', _t(7))],
          hasMore: true,
          floor: _t(18),
          recordings: recs);
      // r-mid(10시)는 7시 이후라 붙고, r-old(5시)는 다음 페이지, 올리는 중은 뺀다.
      expect(out.keys, ['rec:r-new', 'c1', 'c2', 'rec:r-mid', 'c3']);
      expect(out.floor, _t(7));
    });

    test('목록 끝이면 경계보다 오래된 녹화를 모두', () {
      final out = appendFeedPage(
          existing: const ['c1'],
          pageClips: [_clip('c2', _t(11))],
          hasMore: false,
          floor: _t(18),
          recordings: recs);
      expect(out.keys, ['c1', 'c2', 'rec:r-mid', 'rec:r-old']);
    });

    test('새 영상 없이 더 있으면 녹화도 다음에(경계 유지)', () {
      final out = appendFeedPage(
          existing: const ['c1'],
          pageClips: const [],
          hasMore: true,
          floor: _t(18),
          recordings: recs);
      expect(out.keys, ['c1']);
      expect(out.floor, _t(18));
    });

    test('경계 안쪽인데 목록에 없던 녹화(연 뒤 올라옴)는 끝에 붙이지 않는다', () {
      final out = appendFeedPage(
          existing: const ['c1'],
          pageClips: [_clip('c2', _t(11))],
          hasMore: false,
          floor: _t(18),
          recordings: recs);
      expect(out.keys, isNot(contains('rec:r-new')));
    });
  });
}
