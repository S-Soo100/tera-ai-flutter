import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/presentation/widgets/control_feedback.dart';

void main() {
  testWidgets('다른 안내가 먼저 걷어 낸 안내를 닫아도 예외가 나지 않는다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final feedback = ControlFeedback.of(ctx);
    final closeFirst = feedback.show('first', actionLabel: 'undo', onAction: () {});
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    feedback.show('second');
    await tester.pump();
    expect(find.text('first'), findsNothing);
    closeFirst(); // 전엔 이미 걷힌 엔트리를 다시 remove해 예외가 났다.
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
