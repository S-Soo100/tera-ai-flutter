import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vivanaut/features/my_cage/domain/lcd_photo_codec.dart';

/// 왼쪽 절반 빨강·오른쪽 절반 파랑 사진(방향 확인용).
img.Image _halves(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, x < w / 2 ? 255 : 0, 0, x < w / 2 ? 0 : 255);
    }
  }
  return im;
}

Uint8List _jpeg(img.Image im, {int? orientation}) {
  if (orientation != null) im.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(im, quality: 95);
}

bool _reddish(img.Pixel p) => p.r > 150 && p.b < 100;
bool _bluish(img.Pixel p) => p.b > 150 && p.r < 100;

void main() {
  group('lcdAspectRect — 가운데 정확한 5:4', () {
    test('가로로 긴 사진은 좌우를 깎는다', () {
      final r = lcdAspectRect(2000, 1000);
      expect(r, (x: 375, y: 0, width: 1250, height: 1000));
      expect(r.width * 4, r.height * 5);
    });

    test('세로로 긴 사진은 위아래를 깎는다', () {
      final r = lcdAspectRect(1000, 2000);
      expect(r, (x: 0, y: 600, width: 1000, height: 800));
    });

    test('소수점 오차가 있는 자르기 결과(1003×801)도 정확히 5:4', () {
      final r = lcdAspectRect(1003, 801);
      expect(r.width * 4, r.height * 5);
      expect(r.width, 1000);
      expect(r.height, 800);
      expect(r.x, 1);
      expect(r.y, 0);
    });

    test('5×4보다 작으면 크기 0', () {
      expect(lcdAspectRect(4, 100).width, 0);
    });
  });

  group('lcdPhotoOutputSize — 긴 변 1280', () {
    test('크면 1280×1024', () {
      expect(lcdPhotoOutputSize(2000, 1600), (width: 1280, height: 1024));
    });
    test('작으면 키우지 않는다', () {
      expect(lcdPhotoOutputSize(500, 400), (width: 500, height: 400));
      expect(lcdPhotoOutputSize(1280, 1024), (width: 1280, height: 1024));
    });
  });

  group('encodeLcdPhoto', () {
    test('긴 변 1280 · 정확한 5:4 · 읽을 수 있는 JPEG', () {
      final out = encodeLcdPhoto(_jpeg(_halves(2003, 1601)))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 1280);
      expect(decoded.height, 1024);
      expect(out.length, lessThan(kLcdPhotoMaxBytes));
    });

    test('작은 자르기 결과는 키우지 않고 5:4로만 다듬는다', () {
      final out = encodeLcdPhoto(_jpeg(_halves(503, 400)))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 500);
      expect(decoded.height, 400);
    });

    test('EXIF 회전(6 = 시계 방향 90°)을 픽셀에 굽고 태그는 남기지 않는다', () {
      // 원본 픽셀 500×400 가로(왼쪽 빨강) + 회전 6 → 보이는 모양 400×500 세로
      // (위쪽 빨강) → 가운데 5:4 = 400×320.
      final out = encodeLcdPhoto(_jpeg(_halves(500, 400), orientation: 6))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 400);
      expect(decoded.height, 320);
      expect(decoded.exif.imageIfd.orientation ?? 1, 1);
      expect(_reddish(decoded.getPixel(200, 10)), isTrue, reason: '위 = 빨강');
      expect(_bluish(decoded.getPixel(200, 310)), isTrue, reason: '아래 = 파랑');
    });

    test('읽을 수 없는 바이트는 null', () {
      expect(encodeLcdPhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('prepareLcdPhotoSource — 자르기 전 정리', () {
    test('회전 없고 2048 이하면 원본 그대로(다시 인코딩하지 않음)', () {
      final src = _jpeg(_halves(800, 600));
      expect(identical(prepareLcdPhotoSource(src), src), isTrue);
    });

    test('EXIF 회전을 굽는다 — 자르기 틀과 픽셀 방향이 같아진다', () {
      final out =
          prepareLcdPhotoSource(_jpeg(_halves(600, 400), orientation: 6))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 400);
      expect(decoded.height, 600);
      expect(decoded.exif.imageIfd.orientation ?? 1, 1);
      expect(_reddish(decoded.getPixel(200, 20)), isTrue);
      expect(_bluish(decoded.getPixel(200, 580)), isTrue);
    });

    test('긴 변이 2048을 넘으면 줄인다', () {
      final out = prepareLcdPhotoSource(_jpeg(_halves(3000, 1500)))!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 2048);
      expect(decoded.height, 1024);
    });

    test('읽을 수 없는 바이트는 null', () {
      expect(prepareLcdPhotoSource(Uint8List.fromList([0, 1, 2])), isNull);
    });
  });
}
