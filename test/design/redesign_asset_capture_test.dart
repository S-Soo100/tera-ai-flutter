// Flutter's actual SVG loader and rasterizer; does not use a browser renderer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
  });

  test('신규 SVG 70개를 번들에서 읽어 실제 픽셀로 렌더한다', () async {
    final manifest = jsonDecode(File(
      'docs/design-audits/2026-09-15-redesign-asset-map.json',
    ).readAsStringSync()) as Map<String, dynamic>;
    final files = (manifest['files'] as List)
        .cast<Map<String, dynamic>>()
        .where((f) => (f['runtime'] as String).endsWith('.svg'))
        .toList();
    expect(files, hasLength(70));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFEEEEEE), BlendMode.src);
    for (var i = 0; i < files.length; i++) {
      final path = files[i]['runtime'] as String;
      final info = await vg.loadPicture(SvgAssetLoader(path), null);
      final image = await info.picture.toImage(
        info.size.width.ceil(),
        info.size.height.ceil(),
      );
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      var visiblePixels = 0;
      for (var p = 3; p < bytes.length; p += 4) {
        if (bytes[p] > 0) visiblePixels++;
      }
      expect(visiblePixels, greaterThan(0), reason: path);
      final x = (i % 7) * 100.0;
      final y = (i ~/ 7) * 90.0;
      canvas.drawImage(image, Offset(x + 10, y + 5), Paint());
      final text = path.replaceFirst('assets/icons/redesign_v2/', '');
      final label = (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 9, fontFamily: 'Pretendard'))
            ..pushStyle(ui.TextStyle(color: Colors.black))
            ..addText(text))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 98));
      canvas.drawParagraph(label, Offset(x + 1, y + 67));
      label.dispose();
      image.dispose();
      info.picture.dispose();
    }
    final sheet = recorder.endRecording();
    final image = await sheet.toImage(700, 900);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final out = Directory('build/design-audits')..createSync(recursive: true);
    File('${out.path}/redesign-svg-contact-sheet.png')
        .writeAsBytesSync(png.buffer.asUint8List());
    image.dispose();
    sheet.dispose();
  });

  testWidgets('3배율 PNG를 원본 픽셀 크기가 아닌 논리 크기로 표시한다', (tester) async {
    for (final provider in [
      FigmaImages.emptyPet,
      FigmaImages.emptyCamera,
      FigmaImages.emptyEnclosure,
      FigmaImages.petPlaceholder
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: Center(child: Image(image: provider)),
      )));
      await tester.runAsync(() => precacheImage(
            provider,
            tester.element(find.byType(Image)),
          ));
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byType(Image)),
          provider == FigmaImages.petPlaceholder
              ? const Size(56, 56)
              : const Size(345, 227));
      expect(tester.takeException(), isNull);
    }
  });
}
