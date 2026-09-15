import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/shared/widgets/glass_tab_shell.dart';

// AppBar의 스크롤 밑 그림자/틴트 또는 탭 바닥의 회색이 다시 생기면 실패한다.
void main() {
  for (final withAppBar in [false, true]) {
    testWidgets('${withAppBar ? 'AppBar' : '탭 고정 헤더'} 스크롤 전후 흰 상단',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      final list = ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: 50,
        itemBuilder: (_, i) => SizedBox(height: 72, child: Text('Row $i')),
      );
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
        home: RepaintBoundary(
          key: boundaryKey,
          child: withAppBar
              ? Scaffold(
                  appBar: AppBar(title: const Text('Header')), body: list)
              : GlassTabShell(
                  child: Column(children: [
                    const SizedBox(
                        height: 56, child: Center(child: Text('Header'))),
                    Expanded(child: list),
                  ]),
                ),
        ),
      ));
      await tester.pumpAndSettle();

      Future<void> verifyPixels(String stage) async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final samples = await tester.runAsync(() async {
          final image = await boundary.toImage();
          final rgba =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          // 글자에서 떨어진 상단과 헤더 바로 아래의 배경을 확인한다.
          final samples = <List<int>>[];
          for (final y in [4, 28, 55, 57, 60]) {
            final offset = (y * image.width + 380) * 4;
            samples
                .add(rgba.buffer.asUint8List(rgba.offsetInBytes + offset, 4));
          }
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final out = Directory('build/design-audits')
            ..createSync(recursive: true);
          File('${out.path}/${withAppBar ? 'appbar' : 'tab'}-$stage.png')
              .writeAsBytesSync(png.buffer.asUint8List());
          image.dispose();
          return samples;
        });
        for (final sample in samples!) {
          expect(sample, [255, 255, 255, 255], reason: stage);
        }
      }

      await verifyPixels('before');
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Row 0'), findsNothing);
      await verifyPixels('scrolled');
    });
  }
}
