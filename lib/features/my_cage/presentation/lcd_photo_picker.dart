import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/lcd_photo_codec.dart';
import 'lcd_photo_crop_screen.dart';

/// 보호 사진 한 장 — 사진첩 → 정리(EXIF 회전·긴 변 2048, isolate) → 5:4 자르기
/// 화면 → 업로드용 JPEG(§3-6·§11-5). `lcdPhotoPickerProvider`의 기본값.
///
/// 사진첩 권한 거절·취소는 조용히 [LcdPhotoCancelled](§2-6 "조용히 원래 화면").
/// iOS는 `requestFullMetadata: false`로 전체 사진 접근 권한 없이 고른다.
Future<LcdPhotoPick> pickLcdPhoto(BuildContext context) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kLcdPickMaxEdge.toDouble(),
      maxHeight: kLcdPickMaxEdge.toDouble(),
      // 품질을 주면 iOS가 HEIC를 JPEG로 바꿔 준다.
      imageQuality: 95,
      requestFullMetadata: false,
    );
  } catch (_) {
    return const LcdPhotoCancelled(); // 권한 거절 등
  }
  if (file == null) return const LcdPhotoCancelled();
  final raw = await file.readAsBytes();
  final source = await Isolate.run(() => prepareLcdPhotoSource(raw));
  if (source == null) return const LcdPhotoUnreadable();
  if (!context.mounted) return const LcdPhotoCancelled();
  return showLcdPhotoCrop(context, source);
}
