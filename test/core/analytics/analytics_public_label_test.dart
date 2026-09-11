import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_public_label.dart';
import 'package:vivnanaut/core/router/tab_branches.dart';
import 'package:vivnanaut/shared/widgets/glass_dock.dart';

void main() {
  test('공개 라벨 enum 순서는 메인 탭의 고정 번역 키 순서와 일치한다', () {
    expect(AnalyticsPublicLabelKind.values.map((kind) => kind.translationKey),
        kHomeTabLabelKeys);
  });

  testWidgets('root mask 아래에서 고정 Text leaf만 공개하고 스타일을 유지한다', (tester) async {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    await tester.pumpWidget(const MaterialApp(
      home: ClarityMask(
        child: Column(children: [
          AnalyticsPublicLabel(
            kind: AnalyticsPublicLabelKind.home,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('private user content'),
        ]),
      ),
    ));
    final unmask = tester.widget<ClarityUnmask>(find.byType(ClarityUnmask));
    expect(unmask.child, isA<Text>());
    final label = unmask.child! as Text;
    expect(label.data, 'tab_home');
    expect(label.style, style);
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(
        find.ancestor(
            of: find.byType(ClarityUnmask), matching: find.byType(ClarityMask)),
        findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('private user content'),
            matching: find.byType(ClarityUnmask)),
        findsNothing);
  });

  testWidgets('독에서 enum 없는 일반 라벨은 가림을 유지하고 탭 동작을 보존한다', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
        home: ClarityMask(
            child: GlassDock(
      items: const [
        GlassDockItem(
            iconAsset: 'nav_home',
            label: 'tab_home',
            analyticsPublicLabel: AnalyticsPublicLabelKind.home),
        GlassDockItem(iconAsset: 'nav_camera', label: 'private camera name'),
      ],
      currentIndex: 0,
      onSelected: (index) => selected = index,
    ))));
    expect(find.byType(ClarityUnmask), findsOneWidget);
    expect(find.text('private camera name'), findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('private camera name'),
            matching: find.byType(ClarityUnmask)),
        findsNothing);
    await tester.tap(find.text('tab_home'));
    expect(selected, 0);
    await tester.tap(find.text('private camera name'));
    expect(selected, 1);
  });
}
