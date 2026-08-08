import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/shared/widgets/screen_header.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int actionCount,
  double width = 402,
  String title = '크랑이',
  String? subtitle = '테스트',
}) async {
  tester.view.physicalSize = Size(width, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScreenHeader(
          title: title,
          subtitle: subtitle,
          onPick: () {},
          actions: [
            for (var i = 0; i < actionCount; i++)
              HeaderAction(
                icon: Icons.circle,
                tooltip: 'a$i',
                onPressed: () {},
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('폭 배분 — 액션이 늘어도 보조 라벨이 살아남는다', () {
    // 회귀 방지: 예전엔 `Flexible(라벨) + Spacer()`였다. 둘 다 flex라 남은 폭을
    // 반씩 나눠 가져, 액션이 2개에서 3개로 늘자 라벨 몫이 부족해져 보조가
    // 통째로 사라졌다(실기기에서 `테스트`가 없어졌다).
    for (final n in [1, 2, 3, 4]) {
      testWidgets('액션 $n개 — 제목과 보조가 모두 보인다', (tester) async {
        await _pump(tester, actionCount: n);
        expect(find.text('크랑이'), findsOneWidget);
        expect(find.text('테스트'), findsOneWidget);
      });
    }

    testWidgets('좁은 기기(320)에서 액션 3개여도 보조가 남는다', (tester) async {
      await _pump(tester, actionCount: 3, width: 320);
      expect(find.text('크랑이'), findsOneWidget);
      expect(find.text('테스트'), findsOneWidget);
    });

    testWidgets('폭이 정말 모자라면 보조부터 줄고 제목은 버틴다', (tester) async {
      await _pump(
        tester,
        actionCount: 3,
        width: 320,
        title: '아주아주긴개체이름입니다',
        subtitle: '아주아주긴사육장이름입니다',
      );
      // 제목은 잘리더라도 위젯 자체가 사라지지 않는다.
      expect(find.byType(ScreenHeader), findsOneWidget);
    });
  });

  testWidgets('보조가 없으면 제목만 그린다', (tester) async {
    await _pump(tester, actionCount: 3, subtitle: null);
    expect(find.text('크랑이'), findsOneWidget);
    expect(find.text('테스트'), findsNothing);
  });
}
