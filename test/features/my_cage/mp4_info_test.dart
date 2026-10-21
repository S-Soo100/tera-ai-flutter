// mp4 길이·크기 파서 + 썸네일 JPEG 변환 + 녹화 행 JSON 하위 호환.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vivanaut/features/my_cage/data/live_recording_thumb.dart';
import 'package:vivanaut/features/my_cage/data/mp4_info.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';

Uint8List _box(String type, List<int> body) {
  final b = BytesBuilder();
  final size = ByteData(4)..setUint32(0, body.length + 8);
  b
    ..add(size.buffer.asUint8List())
    ..add(type.codeUnits)
    ..add(body);
  return b.toBytes();
}

Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
Uint8List _u64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();

Uint8List _mvhd({required int timescale, required int duration, int v = 0}) {
  final b = BytesBuilder()..add([v, 0, 0, 0]);
  if (v == 1) {
    b
      ..add(_u64(0))
      ..add(_u64(0))
      ..add(_u32(timescale))
      ..add(_u64(duration));
  } else {
    b
      ..add(_u32(0))
      ..add(_u32(0))
      ..add(_u32(timescale))
      ..add(_u32(duration));
  }
  b.add(List.filled(80, 0)); // rate·volume·matrix 등 나머지
  return _box('mvhd', b.toBytes());
}

Uint8List _tkhd({required int w, required int h, int v = 0}) {
  final b = BytesBuilder()..add([v, 0, 0, 0]);
  b.add(List.filled(v == 1 ? 32 : 20, 0)); // 시각·track id·duration
  b.add(List.filled(16, 0)); // reserved·layer·group·volume
  b.add(List.filled(36, 0)); // matrix
  b
    ..add(_u32(w << 16))
    ..add(_u32(h << 16));
  return _box('tkhd', b.toBytes());
}

Uint8List _moov(List<Uint8List> children) =>
    _box('moov', [for (final c in children) ...c]);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mp4info'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<Mp4Info?> read(List<Uint8List> boxes) async {
    final f = File('${dir.path}/a.mp4')
      ..writeAsBytesSync([for (final b in boxes) ...b]);
    return readMp4Info(f.path);
  }

  group('readMp4Info', () {
    test('moov가 파일 끝에 있어도(Android) 길이·크기를 읽는다', () async {
      final info = await read([
        _box('ftyp', 'isom0000'.codeUnits),
        _box('mdat', List.filled(5000, 7)),
        _moov([
          _mvhd(timescale: 1000, duration: 113200),
          _box('trak', [..._tkhd(w: 1280, h: 960)]),
        ]),
      ]);
      expect(info!.durationMs, 113200);
      expect(info.width, 1280);
      expect(info.height, 960);
    });

    test('version 1 mvhd·tkhd, 90kHz timescale', () async {
      final info = await read([
        _moov([
          _mvhd(timescale: 90000, duration: 90000 * 42, v: 1),
          _box('trak', [..._tkhd(w: 640, h: 480, v: 1)]),
        ]),
      ]);
      expect(info!.durationMs, 42000);
      expect(info.width, 640);
    });

    test('음성 트랙(크기 0) 뒤 영상 트랙의 크기를 쓴다', () async {
      final info = await read([
        _moov([
          _mvhd(timescale: 1000, duration: 5000),
          _box('trak', [..._tkhd(w: 0, h: 0)]),
          _box('trak', [..._tkhd(w: 1280, h: 960)]),
        ]),
      ]);
      expect(info!.width, 1280);
    });

    test('64비트 크기(size==1) 최상위 박스를 건너뛴다', () async {
      final mdatBody = List.filled(100, 1);
      final mdat = BytesBuilder()
        ..add(_u32(1))
        ..add('mdat'.codeUnits)
        ..add(_u64(mdatBody.length + 16))
        ..add(mdatBody);
      final info = await read([
        mdat.toBytes(),
        _moov([_mvhd(timescale: 1000, duration: 7000)]),
      ]);
      expect(info!.durationMs, 7000);
      expect(info.width, isNull);
    });

    test('moov 없음·길이 0·파일 없음 → null(타이머 값으로 대체)', () async {
      expect(await read([_box('mdat', List.filled(10, 0))]), isNull);
      expect(
          await read([
            _moov([_mvhd(timescale: 1000, duration: 0)])
          ]),
          isNull);
      expect(await readMp4Info('${dir.path}/none.mp4'), isNull);
    });

    test('잘린 박스는 예외 없이 null', () async {
      final moov = _moov([_mvhd(timescale: 1000, duration: 9000)]);
      expect(await read([moov.sublist(0, moov.length - 30)]), isNull);
    });
  });

  group('toJpegBytes', () {
    test('JPEG는 그대로, PNG는 JPEG로 바꾼다', () async {
      final image = img.Image(width: 4, height: 3);
      final jpg = Uint8List.fromList(img.encodeJpg(image));
      expect(identical(await toJpegBytes(jpg), jpg), isTrue);
      final png = Uint8List.fromList(img.encodePng(image));
      expect(isJpegBytes(png), isFalse);
      final out = await toJpegBytes(png);
      expect(out != null && isJpegBytes(out), isTrue);
    });

    test('이미지가 아니면 null', () async {
      expect(await toJpegBytes(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('LiveRecording JSON', () {
    test('업로드 필드가 없는 옛 행은 pending', () {
      final r = LiveRecording.tryFromJson({
        'id': 'a',
        'owner_id': 'u',
        'camera_id': 'c',
        'started_at': '2026-10-01T03:00:00.000Z',
        'duration_ms': 42000,
        'file_path': 'live_recordings/u/a.mp4',
      })!;
      expect(r.uploadState, LiveRecordingUploadState.pending);
      expect(r.recordingId, isNull);
      expect(r.uploadAttempts, 0);
      expect(r.uploadBadge, LiveRecordingUploadBadge.waiting);
    });

    test('업로드 필드 왕복·모르는 상태 값은 pending', () {
      final r = LiveRecording(
        id: 'a',
        ownerId: 'u',
        cameraId: 'c',
        startedAt: DateTime.utc(2026, 10, 21),
        durationMs: 55000,
        filePath: 'x.mp4',
        width: 1280,
        height: 960,
        recordingId: 'srv-1',
        uploadState: LiveRecordingUploadState.blocked,
        uploadError: LiveRecordingUploadError.quota,
        uploadAttempts: 2,
        nextAttemptAt: DateTime.utc(2026, 10, 21, 1),
      );
      final back = LiveRecording.tryFromJson(r.toJson())!;
      expect(back.recordingId, 'srv-1');
      expect(back.uploadState, LiveRecordingUploadState.blocked);
      expect(back.uploadError, 'quota');
      expect(back.uploadAttempts, 2);
      expect(back.nextAttemptAt, DateTime.utc(2026, 10, 21, 1));
      expect(back.width, 1280);
      final odd = LiveRecording.tryFromJson(
          {...r.toJson(), 'upload_state': 'weird'})!;
      expect(odd.uploadState, LiveRecordingUploadState.pending);
    });

    test('카드 표시', () {
      LiveRecording at(LiveRecordingUploadState s) => LiveRecording(
          id: 'a',
          ownerId: 'u',
          cameraId: 'c',
          startedAt: DateTime(2026),
          durationMs: 1,
          filePath: 'x',
          uploadState: s);
      expect(at(LiveRecordingUploadState.uploading).uploadBadge,
          LiveRecordingUploadBadge.uploading);
      expect(at(LiveRecordingUploadState.blocked).uploadBadge,
          LiveRecordingUploadBadge.waiting);
      expect(at(LiveRecordingUploadState.failed).uploadBadge,
          LiveRecordingUploadBadge.failed);
      expect(at(LiveRecordingUploadState.ready).uploadBadge,
          LiveRecordingUploadBadge.none);
    });
  });
}
