import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart';

/// 2026-10-20 디자이너 코멘트 — 상세 화면 상단바는 #FAFAFA(Figma Rectangle 113)
/// 인데 앱은 흰색이었다. 본문 바닥(흰색)·모달 바탕(surfaceHeader)과 다른 역할이다.
void main() {
  test('라이트 상단바 = #FAFAFA, 본문 바닥·모달 바탕은 흰색 그대로', () {
    expect(GlassPalette.light.appBar, VivaColors.fillBack);
    expect(GlassPalette.light.wallpaper, Colors.white);
    expect(GlassPalette.light.surfaceHeader, Colors.white);
  });

  testWidgets('상세 상단바 래퍼가 appBar 색을 칠한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [GlassPalette.light]),
      home: const CrecamDetailHeaderArea(child: SizedBox(height: 44)),
    ));
    final box = tester.widget<Container>(find.descendant(
        of: find.byType(CrecamDetailHeaderArea),
        matching: find.byType(Container)));
    expect((box.decoration as BoxDecoration).color, VivaColors.fillBack);
  });
}
