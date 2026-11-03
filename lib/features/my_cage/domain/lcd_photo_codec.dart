import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 화면 보호 사진 처리 — 사진첩 원본 정리 → (자르기) → 업로드용 JPEG
/// (기획 `2026-11-03-lcd-screen-settings-design.md` §3-6·§11-5).
///
/// 순수 Dart(`image` 4.x). 무거운 작업이라 화면은 isolate(`Isolate.run`)로
/// 부른다 — 여기 함수들은 동기라 단위 테스트가 바로 부를 수 있다.

/// 기기 화면 비율 5:4(160×128과 같은 비율).
const kLcdPhotoAspectW = 5;
const kLcdPhotoAspectH = 4;

/// 업로드 JPEG의 긴 변 상한 — 기기는 160×128이라 충분하다(§3-6).
const kLcdPhotoMaxEdge = 1280;

/// 업로드 JPEG 품질.
const kLcdPhotoQuality = 90;

/// 사진첩에서 받을 때의 긴 변 상한(§11-5) — 자르기 화면의 확대 여유.
const kLcdPickMaxEdge = 2048;

/// 서버 업로드 상한 5MB(가이드 §3-4). 넘으면 보내기 전에 막는다.
const kLcdPhotoMaxBytes = 5 * 1024 * 1024;

// ── 고르기 결과 ──────────────────────────────────────────────────────────────

/// 사진첩 → 자르기 → 업로드용 JPEG 결과.
sealed class LcdPhotoPick {
  const LcdPhotoPick();
}

/// 업로드할 JPEG(5:4, 긴 변 ≤1280, 품질 90).
final class LcdPhotoPicked extends LcdPhotoPick {
  const LcdPhotoPicked(this.bytes);
  final Uint8List bytes;
}

/// 사진첩·자르기를 닫았거나 권한이 없다 — 조용히 원래 화면.
final class LcdPhotoCancelled extends LcdPhotoPick {
  const LcdPhotoCancelled();
}

/// 고른 사진을 읽지 못했다 — "사진을 읽을 수 없어요".
final class LcdPhotoUnreadable extends LcdPhotoPick {
  const LcdPhotoUnreadable();
}

/// 정리된 원본 JPEG 품질 — 자르기 전 단계라 높게 둔다.
const _kSourceQuality = 95;

/// 사진첩 원본을 자르기 화면에 넘길 모양으로 정리한다. 읽지 못하면 null.
///
/// - EXIF 회전을 픽셀에 굽는다(Android image_picker는 줄인 뒤에도 회전 태그만
///   남긴다 — 그대로 두면 자르기 틀과 실제 픽셀 방향이 어긋난다).
/// - 긴 변이 [kLcdPickMaxEdge]를 넘으면 줄인다.
/// - 바꿀 것이 없으면 원본 바이트를 그대로 돌려준다(다시 인코딩하지 않음).
Uint8List? prepareLcdPhotoSource(Uint8List bytes) {
  final decoded = _decode(bytes);
  if (decoded == null) return null;
  final rotated = _hasRotation(decoded);
  final tooBig = math.max(decoded.width, decoded.height) > kLcdPickMaxEdge;
  if (!rotated && !tooBig) return bytes;
  var image = img.bakeOrientation(decoded);
  if (tooBig) image = _fitLongEdge(image, kLcdPickMaxEdge);
  _dropOrientation(image);
  return img.encodeJpg(image, quality: _kSourceQuality);
}

/// 자른 결과를 업로드용 JPEG로 만든다. 읽지 못하면 null.
///
/// EXIF 회전을 굽고 → 가운데 기준 정확한 5:4로 다듬고(자르기 계산의 소수점
/// 오차 정리) → 긴 변 [kLcdPhotoMaxEdge] 이하로 줄여 → 품질 [kLcdPhotoQuality].
Uint8List? encodeLcdPhoto(Uint8List cropped) {
  final decoded = _decode(cropped);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final rect = lcdAspectRect(image.width, image.height);
  if (rect.width <= 0 || rect.height <= 0) return null;
  if (rect.width != image.width || rect.height != image.height) {
    image = img.copyCrop(image,
        x: rect.x, y: rect.y, width: rect.width, height: rect.height);
  }
  final target = lcdPhotoOutputSize(rect.width, rect.height);
  if (target.width != image.width || target.height != image.height) {
    image = img.copyResize(image,
        width: target.width,
        height: target.height,
        interpolation: img.Interpolation.average);
  }
  _dropOrientation(image);
  return img.encodeJpg(image, quality: kLcdPhotoQuality);
}

/// [width]×[height] 안에서 가운데 기준 가장 큰 **정확한** 5:4 사각형.
/// 5:4가 하나도 안 들어가면(가로 5px·세로 4px 미만) 크기 0.
({int x, int y, int width, int height}) lcdAspectRect(int width, int height) {
  final unit = math.min(width ~/ kLcdPhotoAspectW, height ~/ kLcdPhotoAspectH);
  final w = unit * kLcdPhotoAspectW;
  final h = unit * kLcdPhotoAspectH;
  return (x: (width - w) ~/ 2, y: (height - h) ~/ 2, width: w, height: h);
}

/// 5:4 사각형([width]×[height])을 올릴 크기 — 긴 변이 [kLcdPhotoMaxEdge]를
/// 넘으면 1280×1024로, 아니면 그대로(키우지 않는다).
({int width, int height}) lcdPhotoOutputSize(int width, int height) {
  if (width <= kLcdPhotoMaxEdge && height <= kLcdPhotoMaxEdge) {
    return (width: width, height: height);
  }
  const unit = kLcdPhotoMaxEdge ~/ kLcdPhotoAspectW; // 256
  return (width: unit * kLcdPhotoAspectW, height: unit * kLcdPhotoAspectH);
}

img.Image? _decode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null; // 깨진 파일·HEIC 등 — 호출측이 "사진을 읽을 수 없어요".
  }
}

bool _hasRotation(img.Image image) {
  final ifd = image.exif.imageIfd;
  return ifd.hasOrientation && ifd.orientation != 1;
}

/// 회전은 이미 픽셀에 있다 — 태그가 남으면 보는 쪽이 한 번 더 돌린다.
void _dropOrientation(img.Image image) {
  if (image.exif.imageIfd.hasOrientation) {
    image.exif.imageIfd.orientation = null;
  }
}

img.Image _fitLongEdge(img.Image image, int maxEdge) {
  final landscape = image.width >= image.height;
  return img.copyResize(image,
      width: landscape ? maxEdge : null,
      height: landscape ? null : maxEdge,
      interpolation: img.Interpolation.average);
}
