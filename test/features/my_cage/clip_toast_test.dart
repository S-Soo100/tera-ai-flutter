import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_toast.dart';

/// Figma 1081:6803(세로 y580~640) / 6895(가로 y249~309): 256×60, 가운데.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    // MediaQuery는 view 크기를 읽는다(surface만 바꾸면 800×600 가로로 남는다).
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showClipToast(context, text: '북마크에 저장되었습니다'),
                    child: const Text('show'))))));
    await tester.tap(find.text('show'));
    await tester.pump();
  }

  testWidgets('portrait toast sits 212 above the bottom and auto-dismisses',
      (tester) async {
    await pump(tester, const Size(393, 852));
    final toast = find.byKey(const Key('clip_toast'));
    expect(toast, findsOneWidget);
    final rect = tester.getRect(toast);
    // 폭은 글자에 따라(Pretendard 실측 256), 높이 60, 가로 가운데.
    expect(rect.height, 60);
    expect(rect.center.dx, 196.5);
    expect(rect.bottom, 640);
    expect(find.text('북마크에 저장되었습니다'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(toast, findsNothing);
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('landscape toast sits 84 above the bottom', (tester) async {
    await pump(tester, const Size(852, 393));
    final rect = tester.getRect(find.byKey(const Key('clip_toast')));
    expect(rect.center.dx, 426);
    expect(rect.bottom, 309);
    dismissClipToast();
    await tester.pump();
    expect(find.byKey(const Key('clip_toast')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });
}
