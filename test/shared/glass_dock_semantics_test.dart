import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/shared/widgets/glass_dock.dart';

void main() {
  testWidgets('독 버튼 semantics 노드에 tap 액션이 있다 — 스크린리더 활성화 보장',
      (tester) async {
    // excludeSemantics는 자식 InkWell의 tap 액션까지 지운다. Semantics 노드에
    // onTap을 직접 달지 않으면 스크린리더가 라벨은 읽되 탭을 못 한다.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlassDock(
          items: const [
            GlassDockItem(iconAsset: 'nav_home', label: '홈'),
            GlassDockItem(iconAsset: 'nav_camera', label: '카메라'),
          ],
          currentIndex: 0,
          onSelected: (_) {},
        ),
      ),
    ));

    // 선택된 버튼·비선택 버튼 모두 tap 액션을 가져야 한다.
    for (final label in const ['홈', '카메라']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        containsSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          isInMutuallyExclusiveGroup: true,
        ),
        reason: '$label 버튼 노드에 tap 액션이 없으면 스크린리더로 탭 전환이 불가능하다',
      );
    }

    handle.dispose();
  });
}
