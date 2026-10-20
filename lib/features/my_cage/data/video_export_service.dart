import 'dart:async';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 여러 영상 저장·공유를 사용자가 멈췄을 때.
class ExportCancelled implements Exception {
  const ExportCancelled();
}

/// 여러 영상 내려받기 취소 신호. [cancel]이 진행 중인 연결을 끊는다.
class ExportCancelToken {
  bool _cancelled = false;
  final Set<http.Client> _clients = {};
  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const ExportCancelled();
  }
}

/// 영상 기기 저장(사진앱) + 공유. 로컬 파일이 있으면 재다운로드 없이 사용,
/// 없으면 presigned URL을 임시파일로 내려받아 처리.
class VideoExportService {
  VideoExportService({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;

  Future<File> _resolveFile(
      String clipId, File? localFile, String? presignedUrl) async {
    if (localFile != null) return localFile;
    final resp = await http.get(Uri.parse(presignedUrl!));
    if (resp.statusCode != 200) {
      throw Exception('download failed: ${resp.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$clipId.mp4');
    await f.writeAsBytes(resp.bodyBytes);
    return f;
  }

  /// 사진앱(갤러리)에 저장. 권한 없으면 요청.
  Future<void> saveToGallery(String clipId,
      {File? localFile, String? presignedUrl}) async {
    final file = await _resolveFile(clipId, localFile, presignedUrl);
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putVideo(file.path, album: '비바나트');
  }

  /// OS 공유 시트로 영상 공유.
  Future<void> share(String clipId,
      {File? localFile, String? presignedUrl}) async {
    final file = await _resolveFile(clipId, localFile, presignedUrl);
    // share_plus 13.x: 구 Share.shareXFiles는 @Deprecated → SharePlus.instance.share 사용.
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  // ── 여러 영상 (영상 선택 모드) ──

  /// 사진앱 권한 — 없으면 한 번 묻는다. 거절이면 false.
  Future<bool> ensureGalleryAccess() async {
    if (await Gal.hasAccess()) return true;
    return Gal.requestAccess();
  }

  Future<void> putVideo(File file) => Gal.putVideo(file.path, album: '비바나트');

  /// 임시 폴더로 내려받는다. [onProgress]는 이 영상의 0~1(길이를 모르면
  /// 부르지 않는다). [cancel]되면 연결을 끊고 [ExportCancelled]를 던진다.
  Future<File> downloadToTemp(String clipId, String url,
      {void Function(double fraction)? onProgress,
      ExportCancelToken? cancel}) async {
    cancel?.throwIfCancelled();
    final client = _clientFactory();
    cancel?._clients.add(client);
    // 사진앱 앨범에 이 이름 그대로 들어간다 — 단건 저장과 같은 `<id>.mp4`.
    final dir =
        Directory('${(await getTemporaryDirectory()).path}/clip_select');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$clipId.mp4');
    IOSink? sink;
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) {
        throw HttpException('download failed: ${resp.statusCode}');
      }
      final total = resp.contentLength;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in resp.stream) {
        cancel?.throwIfCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      sink = null;
      cancel?.throwIfCancelled();
      return file;
    } catch (error) {
      await sink?.close();
      if (await file.exists()) await file.delete();
      if (cancel?.isCancelled ?? false) throw const ExportCancelled();
      rethrow;
    } finally {
      cancel?._clients.remove(client);
      client.close();
    }
  }

  /// 여러 영상을 한 번에 OS 공유 시트로.
  Future<void> shareFiles(List<File> files) => SharePlus.instance
      .share(ShareParams(files: [for (final f in files) XFile(f.path)]));
}
