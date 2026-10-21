import 'dart:io';
import 'dart:typed_data';

/// mp4 파일의 실제 길이·영상 크기 — 직접 녹화를 서버에 등록할 때 쓴다.
///
/// 녹화 타이머 값은 파일보다 몇 초 길다(인코더가 첫 프레임까지 늦게 붙는다,
/// 2026-10-21 실측 타이머 120초 → 파일 113.2초). 서버 `duration_ms` 검사는
/// 파일 기준이어야 하므로 `moov/mvhd`의 duration/timescale을 직접 읽는다.
/// 영상 크기는 첫 영상 트랙 `tkhd`의 width/height(16.16 고정소수점).
class Mp4Info {
  const Mp4Info({required this.durationMs, this.width, this.height});

  final int durationMs;
  final int? width;
  final int? height;
}

/// moov 박스를 통째로 읽을 상한 — 2분 녹화 moov는 수십 KB다. 넘으면 이상한
/// 파일로 보고 포기한다(30MB 파일을 메모리에 올리지 않게).
const int _kMaxMoovBytes = 8 * 1024 * 1024;

/// 파일에서 길이·크기를 읽는다. 못 읽으면(파일 없음·moov 없음·길이 0) null.
/// 파일 전체를 읽지 않고 최상위 박스 머리만 건너뛰며 moov만 올린다 —
/// Android MediaMuxer는 moov를 파일 끝에 쓴다.
Future<Mp4Info?> readMp4Info(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    final length = await raf.length();
    var pos = 0;
    while (pos + 8 <= length) {
      await raf.setPosition(pos);
      final head = await raf.read(16);
      if (head.length < 8) return null;
      final bd = ByteData.sublistView(head);
      var size = bd.getUint32(0);
      final type = String.fromCharCodes(head.sublist(4, 8));
      var headerLen = 8;
      if (size == 1) {
        if (head.length < 16) return null;
        size = bd.getUint64(8);
        headerLen = 16;
      } else if (size == 0) {
        size = length - pos; // 파일 끝까지
      }
      if (size < headerLen) return null;
      if (type == 'moov') {
        final bodyLen = size - headerLen;
        if (bodyLen > _kMaxMoovBytes || pos + size > length) return null;
        await raf.setPosition(pos + headerLen);
        final body = await raf.read(bodyLen);
        return parseMoov(Uint8List.fromList(body));
      }
      pos += size;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    await raf?.close();
  }
}

/// moov 본문(머리 8바이트 뺀 것)에서 길이·크기를 꺼낸다. 테스트용으로 공개.
Mp4Info? parseMoov(Uint8List moov) {
  final bd = ByteData.sublistView(moov);
  int? durationMs;
  int? width;
  int? height;
  for (final box in _children(bd, 0, moov.length)) {
    if (box.type == 'mvhd') {
      durationMs = _mvhdDurationMs(bd, box.start, box.end);
    } else if (box.type == 'trak' && width == null) {
      for (final sub in _children(bd, box.start, box.end)) {
        if (sub.type != 'tkhd') continue;
        final wh = _tkhdSize(bd, sub.start, sub.end);
        if (wh != null && wh.$1 > 0 && wh.$2 > 0) {
          width = wh.$1;
          height = wh.$2;
        }
      }
    }
  }
  if (durationMs == null || durationMs <= 0) return null;
  return Mp4Info(durationMs: durationMs, width: width, height: height);
}

/// [start, end) 안의 자식 박스(본문 범위).
Iterable<({String type, int start, int end})> _children(
    ByteData bd, int start, int end) sync* {
  var pos = start;
  while (pos + 8 <= end) {
    var size = bd.getUint32(pos);
    final type = String.fromCharCodes([
      bd.getUint8(pos + 4),
      bd.getUint8(pos + 5),
      bd.getUint8(pos + 6),
      bd.getUint8(pos + 7),
    ]);
    var headerLen = 8;
    if (size == 1) {
      if (pos + 16 > end) return;
      size = bd.getUint64(pos + 8);
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < headerLen || pos + size > end) return;
    yield (type: type, start: pos + headerLen, end: pos + size);
    pos += size;
  }
}

int? _mvhdDurationMs(ByteData bd, int start, int end) {
  if (start + 4 > end) return null;
  final version = bd.getUint8(start);
  final int timescale;
  final int duration;
  if (version == 1) {
    // version/flags 4 + creation 8 + modification 8 + timescale 4 + duration 8
    if (start + 32 > end) return null;
    timescale = bd.getUint32(start + 20);
    duration = bd.getUint64(start + 24);
  } else {
    // version/flags 4 + creation 4 + modification 4 + timescale 4 + duration 4
    if (start + 20 > end) return null;
    timescale = bd.getUint32(start + 12);
    duration = bd.getUint32(start + 16);
  }
  if (timescale == 0) return null;
  return (duration * 1000) ~/ timescale;
}

/// tkhd 본문 끝 8바이트가 width/height(16.16).
(int, int)? _tkhdSize(ByteData bd, int start, int end) {
  final version = start < end ? bd.getUint8(start) : -1;
  final payload = version == 1 ? 96 : 84;
  if (start + payload > end) return null;
  final w = bd.getUint32(start + payload - 8) >> 16;
  final h = bd.getUint32(start + payload - 4) >> 16;
  return (w, h);
}
