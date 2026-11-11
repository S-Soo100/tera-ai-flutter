import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/dismiss_keyboard_on_tap.dart';

void main() {
  Widget app({VoidCallback? onButton}) => MaterialApp(
        builder: (context, child) => DismissKeyboardOnTap(child: child!),
        home: Scaffold(
          body: ListView(children: [
            const TextField(key: Key('field'), maxLines: 5),
            const SizedBox(height: 200, key: Key('blank')),
            TextButton(onPressed: onButton, child: const Text('btn')),
          ]),
        ),
      );

  testWidgets('입력칸 바깥 빈 곳을 탭하면 키보드(포커스)가 닫힌다', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText,
        isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('입력칸 자체를 탭하면 포커스가 유지된다', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('버튼 탭은 그대로 동작한다', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(app(onButton: () => pressed++));
    await tester.tap(find.text('btn'));
    await tester.pump();
    expect(pressed, 1);
  });
}
