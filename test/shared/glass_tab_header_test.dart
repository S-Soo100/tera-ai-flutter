import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/theme/app_styles.dart';
import 'package:vivnanaut/shared/widgets/glass_tab_header.dart';

// 구 ScreenHeader 테스트(7238167에서 삭제)의 불변 3종을 GlassTabHeader로 이식.
// 탭을 옮길 때 제목이 미묘하게 움직이면 "다른 앱"처럼 느껴진다 — 눈으로는
// 몇 pt 차이를 못 짚어서 실기기에서도 한참 뒤에야 발견된다. 수치로 못박는다.

Future<void> _pump(
  WidgetTester tester, {
  required int actionCount,
  double width = 402,
  String title = '크랑이',
  String? capsule = '1번 사육장',
  bool picker = true,
}) async {
  tester.view.physicalSize = Size(width, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: GlassTabHeader(
            title: title,
            capsuleLabel: capsule,
            onPickCapsule: picker ? () {} : null,
            actions: [
              for (var i = 0; i < actionCount; i++)
                IconButton(
                  icon: const Icon(Icons.circle),
                  tooltip: 'a$i',
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('캡슐 있음/없음에 헤더 높이가 같다 — 캡슐 없는 탭도 줄을 예약한다',
      (tester) async {
    await _pump(tester, actionCount: 2);
    final withCapsule = tester.getSize(find.byType(GlassTabHeader)).height;

    await _pump(tester, actionCount: 2, capsule: null, picker: false);
    final withoutCapsule = tester.getSize(find.byType(GlassTabHeader)).height;

    // 높이가 흔들리면 탭을 옮길 때마다 제목 베이스라인과 아래 내용이 튄다.
    expect(withCapsule, withoutCapsule);
    expect(withCapsule, GlassTabHeader.height);
  });

  testWidgets('액션 0~3개에서 높이·제목 시작점이 불변이다', (tester) async {
    final heights = <double>{};
    final titleXs = <double>{};
    for (var n = 0; n <= 3; n++) {
      await _pump(tester, actionCount: n);
      heights.add(tester.getSize(find.byType(GlassTabHeader)).height);
      titleXs.add(tester.getTopLeft(find.text('크랑이')).dx);
    }
    expect(heights, {GlassTabHeader.height});
    expect(titleXs, {AppStyles.spacing16});
  });

  testWidgets('좁은 폭(320) + 액션 3개 — 제목은 ellipsis로 버티고 넘치지 않는다',
      (tester) async {
    await _pump(
      tester,
      actionCount: 3,
      width: 320,
      title: '아주아주긴개체이름입니다만잘려도됩니다',
      capsule: '아주아주긴사육장이름입니다',
    );
    // 오버플로가 나면 FlutterError가 잡힌다 — 없어야 한다.
    expect(tester.takeException(), isNull);
    expect(find.byType(GlassTabHeader), findsOneWidget);
    final text = tester.widget<Text>(
        find.text('아주아주긴개체이름입니다만잘려도됩니다'));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.byType(GlassTabHeader)).height,
        GlassTabHeader.height);
  });
}
