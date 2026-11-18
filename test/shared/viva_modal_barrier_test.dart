import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/shared/widgets/viva_modal.dart';

Future<void> _open(WidgetTester tester, ThemeData theme,
    Future<void> Function(BuildContext) open) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
            onPressed: () => open(context), child: const Text('open')),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Color? _barrier(WidgetTester tester) => tester
    .widgetList<ModalBarrier>(find.byType(ModalBarrier))
    .where((b) => b.dismissible)
    .last
    .color;

void main() {
  testWidgets('라이트: 공용 확인 창은 뒤를 덮지 않고, 바깥 탭으로 닫힌다(Figma 1142:8956)',
      (tester) async {
    bool? result;
    await _open(tester, AppTheme.light, (context) async {
      result = await showVivaModal(context,
          message: 'm', cancelLabel: 'c', confirmLabel: 'ok');
    });
    expect(find.byKey(const Key('viva_modal_surface')), findsOneWidget);
    expect(_barrier(tester), anyOf(isNull, GlassPalette.light.modalBarrier));
    expect(GlassPalette.light.modalBarrier.a, 0);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viva_modal_surface')), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('라이트: 직접 부른 showDialog도 같은 바탕(테마) — 확인 창이 한 모양', (tester) async {
    await _open(
        tester,
        AppTheme.light,
        (context) => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('x'))));
    expect(_barrier(tester), anyOf(isNull, GlassPalette.light.modalBarrier));
  });

  testWidgets('다크: Figma 미정의라 기존처럼 어둡게 덮는다', (tester) async {
    await _open(tester, AppTheme.dark, (context) async {
      await showVivaModal(context, message: 'm');
    });
    expect(_barrier(tester), GlassPalette.dark.modalBarrier);
    expect(GlassPalette.dark.modalBarrier.a, greaterThan(0));
  });
}
