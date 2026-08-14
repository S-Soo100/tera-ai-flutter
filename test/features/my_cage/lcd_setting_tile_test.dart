import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/lcd_setting_tile.dart';

/// 네트워크를 타지 않는 대역. 호출 기록으로 "정말 REST로 갔는가"를 본다.
class _FakeLcdRepo implements LcdRepository {
  _FakeLcdRepo({this.fail = false});

  final bool fail;
  final List<String> calls = [];

  @override
  Future<void> setText(String deviceId, String text) async {
    calls.add('set:$deviceId:$text');
    if (fail) throw Exception('boom');
  }

  @override
  Future<void> clear(String deviceId) async {
    calls.add('clear:$deviceId');
    if (fail) throw Exception('boom');
  }
}

Future<void> _pump(WidgetTester tester, _FakeLcdRepo repo,
    {String? deviceId = 'd1'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lcdRepositoryProvider.overrideWithValue(repo),
        currentDeviceIdProvider.overrideWith((ref) async => deviceId),
      ],
      child: const MaterialApp(
        home: Scaffold(body: LcdSettingTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('적용을 누르면 현재 기기로 setText가 나간다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(LcdSettingTile.tileKey));
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

    await tester.tap(find.byKey(LcdSettingTile.tileKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lcd_reset')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['clear:d1']);
  });

  testWidgets('64자 하드 상한 — 필드가 그 이상을 받지 않는다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(LcdSettingTile.tileKey));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('lcd_text_field')), 'a' * 80);
    final field = tester
        .widget<TextField>(find.byKey(const Key('lcd_text_field')));
    expect(field.controller!.text.length, 64);
  });

  testWidgets('실패하면 시트를 닫지 않고 사유를 보여준다', (tester) async {
    final repo = _FakeLcdRepo(fail: true);
    await _pump(tester, repo);

    await tester.tap(find.byKey(LcdSettingTile.tileKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lcd_text_field')), findsOneWidget,
        reason: '시트가 열린 채여야 재시도할 수 있다');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('기기가 없으면 타일이 비활성 + 이유를 밝힌다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, deviceId: null);

    final tile = tester.widget<ListTile>(find.byKey(LcdSettingTile.tileKey));
    expect(tile.enabled, isFalse);
    expect(find.text('lcd_no_device'), findsOneWidget);
  });
}
