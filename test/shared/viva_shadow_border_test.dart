import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/viva_shadow.dart';

void main() {
  // 테스트 렌더러는 흐림을 그리지 않아 퍼짐(spread)으로 칠하는 범위만 본다.
  testWidgets('그림자는 면 바깥에만 칠하고 메뉴 글자 쪽(면 안)은 덮지 않는다',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: Container(
            color: const Color(0xFFFFFFFF),
            alignment: Alignment.center,
            child: const SizedBox(
                width: 100,
                height: 100,
                child: Material(
                    color: Color(0xFFFFFFFF),
                    shape: VivaShadowRoundedBorder(
                        shadow: BoxShadow(
                            color: Color(0xFF000000), spreadRadius: 10),
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    child: SizedBox.expand())))));
    late ByteData data;
    late int width;
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      width = image.width;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    int red(Offset p) =>
        data.getUint8(((p.dy.toInt() * width) + p.dx.toInt()) * 4);
    final center = tester.getCenter(find.byType(Material));
    expect(red(center), 255, reason: '면 안');
    expect(red(center + const Offset(45, 0)), 255, reason: '면 안쪽 가장자리');
    expect(red(center + const Offset(55, 0)), 0, reason: '면 바깥 그림자');
    expect(red(center + const Offset(65, 0)), 255, reason: '그림자 밖');
  });

  test('그림자가 다르면 다른 테두리', () {
    const a = VivaShadowRoundedBorder(shadow: BoxShadow(blurRadius: 1));
    const b = VivaShadowRoundedBorder(shadow: BoxShadow(blurRadius: 2));
    expect(a == b, isFalse);
    expect(a, const VivaShadowRoundedBorder(shadow: BoxShadow(blurRadius: 1)));
  });
}
