import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/lcd_setting_tile.dart';

/// LCD 문구 진입점(홈 `HomeLcdRow`, 2026-09-07 이동) + 시트([showLcdSheet]).
///
/// 네트워크를 타지 않는 대역. 호출 기록으로 "정말 REST로 갔는가"를 본다.
class _FakeLcdRepo implements LcdRepository {
  _FakeLcdRepo({this.fail = false, this.pending});

  final bool fail;
  final Completer<void>? pending;
  final List<String> calls = [];

  @override
  Future<void> setText(String deviceId, String text) async {
    calls.add('set:$deviceId:$text');
    await pending?.future;
    if (fail) throw Exception('boom');
  }

  @override
  Future<void> clear(String deviceId) async {
    calls.add('clear:$deviceId');
    await pending?.future;
    if (fail) throw Exception('boom');
  }
}

Future<void> _pump(WidgetTester tester, _FakeLcdRepo repo,
    {String? deviceId = 'd1'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lcdRepositoryProvider.overrideWithValue(repo),
        currentSetProvider.overrideWith((ref) async => deviceId == null
            ? null
            : EnclosureSet(
                enclosure: Enclosure(
                    id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
                device: Device(
                    id: deviceId,
                    ownerId: null,
                    enclosureId: null,
                    name: null,
                    isOnline: true,
                    lastSeenAt: null),
                camera: null,
                pet: null,
              )),
      ],
      child: const MaterialApp(
        home: Scaffold(body: HomeLcdRow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('적용을 누르면 현재 기기로 setText가 나간다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('lcd_text_field')), '밥 6시');
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['set:d1:밥 6시']);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('기본값 복원은 clear를 부른다 — 빈 텍스트 전송이 아니라', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lcd_reset')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['clear:d1']);
  });

  testWidgets('20자 상한 — 붙여넣기 후 전송도 20자 이내다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('lcd_text_field')), 'a' * 80);
    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    expect(field.controller!.text.length, 20);
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['set:d1:${'a' * 20}']);
  });

  testWidgets('실패하면 시트를 닫지 않고 사유를 보여준다', (tester) async {
    final repo = _FakeLcdRepo(fail: true);
    await _pump(tester, repo);

    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '재시도 문구');
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lcd_text_field')), findsOneWidget,
        reason: '시트가 열린 채여야 재시도할 수 있다');
    expect(find.byType(SnackBar), findsOneWidget);
    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    expect(field.controller!.text, '재시도 문구');
    expect(field.readOnly, isFalse);
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['set:d1:재시도 문구', 'set:d1:재시도 문구']);
  });

  testWidgets('프로그램 입력도 공백 포함 20자까지만 전송한다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    field.controller!.text = '123456789 123456789 12345';
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['set:d1:123456789 123456789 ']);
  });

  testWidgets('전송 중 연속 적용은 한 번만 보내고 입력과 복원을 잠근다', (tester) async {
    final pending = Completer<void>();
    final repo = _FakeLcdRepo(pending: pending);
    await _pump(tester, repo);
    await tester.tap(find.byKey(HomeLcdRow.rowKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '전송 문구');

    final apply =
        tester.widget<FilledButton>(find.byKey(const Key('lcd_apply')));
    apply.onPressed!();
    apply.onPressed!();
    await tester.pump();

    expect(repo.calls, ['set:d1:전송 문구']);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .readOnly,
        isTrue);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('lcd_reset')))
            .onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lcd_text_field')), findsNothing);
  });

  testWidgets('기기가 없는 세트에서는 로우를 그리지 않는다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, deviceId: null);

    expect(find.byKey(HomeLcdRow.rowKey), findsNothing);
  });
}
