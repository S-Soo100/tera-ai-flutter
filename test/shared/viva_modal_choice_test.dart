import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/shared/widgets/viva_modal.dart';

Future<void> _open(
    WidgetTester tester, Future<void> Function(BuildContext) open) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
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

void main() {
  testWidgets('취소 버튼 직접 탭 = cancel', (tester) async {
    VivaModalResult? result;
    await _open(tester, (c) async {
      result = await showVivaModalChoice(c,
          message: 'm', cancelLabel: 'later', confirmLabel: 'ok');
    });
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(result, VivaModalResult.cancel);
  });

  testWidgets('확인 버튼 = confirm', (tester) async {
    VivaModalResult? result;
    await _open(tester, (c) async {
      result = await showVivaModalChoice(c,
          message: 'm', cancelLabel: 'later', confirmLabel: 'ok');
    });
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    expect(result, VivaModalResult.confirm);
  });

  testWidgets('바깥 탭 = dismissed(취소와 구분)', (tester) async {
    VivaModalResult? result;
    await _open(tester, (c) async {
      result = await showVivaModalChoice(c,
          message: 'm', cancelLabel: 'later', confirmLabel: 'ok');
    });
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viva_modal_surface')), findsNothing);
    expect(result, VivaModalResult.dismissed);
  });

  testWidgets('dismissOn 자동 닫힘 = dismissed', (tester) async {
    VivaModalResult? result;
    final close = Completer<void>();
    await _open(tester, (c) async {
      result = await showVivaModalChoice(c,
          message: 'm',
          cancelLabel: 'later',
          confirmLabel: 'ok',
          dismissOn: close.future);
    });
    close.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viva_modal_surface')), findsNothing);
    expect(result, VivaModalResult.dismissed);
  });

  testWidgets('기존 showVivaModal은 그대로 — 확인 true, 취소·바깥·자동 닫힘 false',
      (tester) async {
    final results = <bool>[];
    Future<void> openOnce(Future<void>? dismissOn) => _open(tester, (c) async {
          results.add(await showVivaModal(c,
              message: 'm',
              cancelLabel: 'c',
              confirmLabel: 'ok',
              dismissOn: dismissOn));
        });

    await openOnce(null);
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pumpAndSettle();
    await openOnce(null);
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    await openOnce(null);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    final close = Completer<void>();
    await openOnce(close.future);
    close.complete();
    await tester.pumpAndSettle();

    expect(results, [true, false, false, false]);
  });
}
