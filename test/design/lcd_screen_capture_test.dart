// 모듈 화면 설정(LCD) Figma 수치 검수용 캡처. Opt-in only:
//   flutter test --no-pub --dart-define=CAPTURE_LCD=true \
//     test/design/lcd_screen_capture_test.dart
// Writes /private/tmp/lcd-capture/<name>.png (393×852, 1x). 값은 테스트 대역에서
// 온다 — 기기·서버가 아니다. 미리보기 사진은 네트워크라 그려지지 않는다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_saver_screen.dart';

import '../features/my_cage/lcd_fixtures.dart';

const _enabled = bool.fromEnvironment('CAPTURE_LCD');
const _outDir = '/private/tmp/lcd-capture';

Future<void> _loadFonts() async {
  final f = FontLoader('Pretendard');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
  }
  await f.load();
}

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObjectList<RenderRepaintBoundary>(find.byType(RepaintBoundary))
      .firstWhere((b) => b.size == const Size(393, 852));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _open(WidgetTester tester, String path, DeviceLinkStatus link,
    {String? imageKey}) async {
  final repo = FakeLcdRepo()
    ..snapshot = LcdStateSnapshot(
        screen: DeviceLcdScreen(imageKey: imageKey),
        text: DeviceLcdText.unknown,
        previewUrl: imageKey == null ? null : 'https://preview.test/k.jpg');
  final rows = CommandRows();
  final feed = LcdLinkFeed(link);
  addTearDown(rows.close);
  addTearDown(feed.close);
  await pumpLcdRouter(tester, settle: false, initial: path, overrides: [
    ...lcdOverrides(
        repo: repo,
        rows: rows,
        link: feed.stream,
        refresh: () async => link,
        now: DateTime.utc(2026, 11, 3, 3),
        devices: const [lcdTestDevice]),
  ]);
  await _frames(tester);
}

void main() {
  setUpAll(() async {
    await initLcdTestStrings();
    await _loadFonts();
  });

  testWidgets('settings_off (1659:5964)', (tester) async {
    await _open(tester, lcdSettingsPath(kLcdDevice), lcdLink());
    await _capture(tester, 'settings_off');
  }, skip: !_enabled);

  testWidgets('settings_on (1660:6770)', (tester) async {
    await _open(
        tester,
        lcdSettingsPath(kLcdDevice),
        lcdLink(
            quiet: LcdQuietWindow.parse('20:00', '06:00')!,
            saver: LcdSaverSettings.defaults.copyWith(enabled: true),
            imageKey: 'k1'),
        imageKey: 'k1');
    await _capture(tester, 'settings_on');
  }, skip: !_enabled);

  testWidgets('quiet_time (1659:6267)', (tester) async {
    await _open(tester, lcdQuietTimePath(kLcdDevice),
        lcdLink(quiet: LcdQuietWindow.parse('18:00', '08:00')!));
    await _capture(tester, 'quiet_time');
  }, skip: !_enabled);

  testWidgets('saver_empty (1659:6396)', (tester) async {
    await _open(tester, lcdSaverPath(kLcdDevice), lcdLink());
    await _capture(tester, 'saver_empty');
  }, skip: !_enabled);

  testWidgets('saver_photo_menu (1660:6700)', (tester) async {
    await _open(
        tester,
        lcdSaverPath(kLcdDevice),
        lcdLink(
            saver: LcdSaverSettings.defaults
                .copyWith(enabled: true, imageSec: 300, infoSec: 15),
            imageKey: 'k1'),
        imageKey: 'k1');
    await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
    await _frames(tester);
    await _capture(tester, 'saver_photo');
  }, skip: !_enabled);
}
