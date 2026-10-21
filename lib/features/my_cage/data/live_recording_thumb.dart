import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 직접 녹화 썸네일을 JPEG로 맞춘다 — 서버 업로드 URL이 `image/jpeg`로
/// 서명돼 있어 PNG를 올리면 서명이 깨진다(합의 결과 2026-10-20).
///
/// flutter_webrtc `captureFrame`은 Android가 JPEG, iOS가 PNG를 돌려준다
/// (파일 이름은 둘 다 .png). JPEG면 그대로, 아니면 디코드해 다시 인코딩한다.
/// 못 하면 null — 호출부는 썸네일 없이(`has_thumbnail=false`) 진행한다.
bool isJpegBytes(Uint8List b) =>
    b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

Future<Uint8List?> toJpegBytes(Uint8List bytes) async {
  if (isJpegBytes(bytes)) return bytes;
  try {
    // 1280×960 인코딩은 수백 ms — UI 스레드를 막지 않게 isolate에서.
    return await compute(_encodeJpeg, bytes);
  } catch (_) {
    return null;
  }
}

Uint8List? _encodeJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}
