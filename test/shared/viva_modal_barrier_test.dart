import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/widgets/viva_modal.dart';

void main() {
  testWidgets('확인 창은 뒤를 어둡게 하지 않고, 바깥 탭으로 닫힌다(Figma 1142:8956)',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showVivaModal(context,
                message: 'm', cancelLabel: 'c', confirmLabel: 'ok'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('viva_modal_surface')), findsOneWidget);
    final barriers = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((b) => b.dismissible)
        .toList();
    expect(barriers, isNotEmpty);
    for (final b in barriers) {
      expect(b.color, anyOf(isNull, Colors.transparent));
    }

    // 바깥 탭으로 닫히는 동작은 그대로 — 결과 false.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viva_modal_surface')), findsNothing);
    expect(result, isFalse);
  });
}
