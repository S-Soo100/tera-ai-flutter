import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// motion_clips 썸네일을 클라이언트에서 생성/캐시(임시 방식).
///
/// terra-api 썸네일 엔드포인트가 없어 presigned 영상 URL의 첫 프레임을 추출해
/// 앱 캐시(JPG)에 clipId로 저장한다. 백엔드에 `GET /clips/{id}/thumbnail/url`이
/// 생기면 이 클래스 대신 그 presigned URL을 쓰도록 [motionThumbnailProvider]만
/// 교체하면 된다.
///
/// 그리드가 카드 50개를 한 번에 빌드하므로 동시 추출을 [_maxConcurrent]개로 제한.
class MotionThumbnailRepository {
  static const _subdir = 'motion_thumbs';
  static const _maxConcurrent = 3;

  int _active = 0;
  final _waiters = <Completer<void>>[];
  final Map<String, Future<File?>> _inFlight = {};

  Future<Directory> _dir() async {
    final base = await getApplicationCacheDirectory();
    final d = Directory('${base.path}/$_subdir');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// 캐시된 썸네일 파일. 없으면 null.
  Future<File?> getCached(String clipId) async {
    final dir = await _dir();
    final f = File('${dir.path}/$clipId.jpg');
    return f.existsSync() ? f : null;
  }

  /// 캐시에 있으면 즉시 반환. 없으면 첫 프레임 추출→저장. 실패 시 null.
  Future<File?> getOrCreate(String clipId, String presignedUrl) async {
    final cached = await getCached(clipId);
    if (cached != null) return cached;

    final existing = _inFlight[clipId];
    if (existing != null) return existing;

    final future = _gen(clipId, presignedUrl);
    _inFlight[clipId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(clipId);
    }
  }

  Future<File?> _gen(String clipId, String presignedUrl) async {
    await _acquire();
    try {
      final dir = await _dir();
      final path = await VideoThumbnail.thumbnailFile(
        video: presignedUrl,
        thumbnailPath: '${dir.path}/$clipId.jpg',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 70,
      );
      // resolve된 video_thumbnail이 XFile?을 반환하면 `path?.path`로 맞춰라.
      if (path == null) return null;
      final f = File(path);
      return f.existsSync() ? f : null;
    } catch (_) {
      return null; // 추출 실패 → 카드가 아이콘 폴백
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future; // _release가 슬롯을 넘겨줌(active는 그대로)
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(); // 대기자에게 슬롯 이양
    } else {
      _active--;
    }
  }
}
