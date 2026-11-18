import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/crecam_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart';

void main() {
  testWidgets('상세 헤더(하이라이트·북마크·플레이어) 아래 선은 0.5pt(Figma 945:4287)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CrecamDetailHeaderArea(child: SizedBox(height: 44)))));
    final box = tester.widget<Container>(find.descendant(
        of: find.byType(CrecamDetailHeaderArea),
        matching: find.byType(Container)));
    final border = (box.foregroundDecoration as BoxDecoration).border as Border;
    expect(border.bottom.width, 0.5);
  });

  group('업데이트 상대 시각(Figma 1081:4122~4162)', () {
    test('오늘·어제·N일 전(29일까지)', () {
      expect(
          crecamUpdatedLabelKey(0), (key: 'crecam_updated_today', arg: null));
      expect(crecamUpdatedLabelKey(1),
          (key: 'crecam_updated_yesterday', arg: null));
      expect(crecamUpdatedLabelKey(7), (key: 'crecam_updated_days', arg: '7'));
      expect(
          crecamUpdatedLabelKey(29), (key: 'crecam_updated_days', arg: '29'));
    });

    test('30일마다 한 달 전·두 달 전…열두 달 전', () {
      expect(crecamUpdatedLabelKey(30),
          (key: 'crecam_updated_month_1', arg: null));
      expect(crecamUpdatedLabelKey(59),
          (key: 'crecam_updated_month_1', arg: null));
      expect(crecamUpdatedLabelKey(60),
          (key: 'crecam_updated_month_2', arg: null));
      expect(crecamUpdatedLabelKey(12 * 30 + 29),
          (key: 'crecam_updated_month_12', arg: null));
    });

    test('열세 달부터는 숫자로', () {
      expect(crecamUpdatedLabelKey(13 * 30),
          (key: 'crecam_updated_months', arg: '13'));
    });

    test('미래 날짜(시계 어긋남)는 오늘', () {
      expect(
          crecamUpdatedLabelKey(-2), (key: 'crecam_updated_today', arg: null));
    });
  });
}
