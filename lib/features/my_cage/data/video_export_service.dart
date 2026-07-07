import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 영상 기기 저장(사진앱) + 공유. 로컬 파일이 있으면 재다운로드 없이 사용,
/// 없으면 presigned URL을 임시파일로 내려받아 처리.
class VideoExportService {
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
    await Gal.putVideo(file.path, album: 'Tera AI');
  }

  /// OS 공유 시트로 영상 공유.
  Future<void> share(String clipId,
      {File? localFile, String? presignedUrl}) async {
    final file = await _resolveFile(clipId, localFile, presignedUrl);
    // share_plus 13.x: 구 Share.shareXFiles는 @Deprecated → SharePlus.instance.share 사용.
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
