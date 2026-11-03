import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_quiet_time_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_settings_screen.dart';

import 'lcd_fixtures.dart';

final _noon = DateTime.utc(2026, 11, 3, 3);

class _Env {
  final repo = FakeLcdRepo();
  final rows = CommandRows();
  final store = MemoryQuietStore();
}

/// 설정 화면에서 꺼짐 시간 줄을 눌러 들어온다(완료 뒤 돌아가는 곳 확인용).
Future<_Env> _open(WidgetTester tester,
    {required DeviceLinkStatus link, bool online = true}) async {
  final env = _Env();
  addTearDown(env.rows.close);
  await pumpLcdRouter(tester,
      overrides: lcdOverrides(
          repo: env.repo,
          rows: env.rows,
          link: Stream.value(link),
          quietStore: env.store,
          online: online,
          now: _noon,
          devices: const [lcdTestDevice]));
  await tester.tap(find.byKey(LcdSettingsScreen.timeRowKey));
  await tester.pumpAndSettle();
  expect(find.byType(LcdQuietTimeScreen), findsOneWidget);
  return env;
}

Key _k(bool start, String part) => LcdQuietTimeScreen.partKey(start, part);

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
}

bool _doneEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(LcdQuietTimeScreen.doneKey))
        .onPressed !=
    null;

void main() {
  setUpAll(initLcdTestStrings);

  testWidgets('수치 (Figma 1659:6267, 393×852)', (tester) async {
    await _open(tester, link: lcdLink());
    expect(find.text('화면 꺼짐 시간'), findsOneWidget);
    final start = find.text('시작');
    expect(tester.getRect(start).topLeft, const Offset(36, 118));
    expect(tester.getRect(find.text('종료')).top, 282);
    expect(tester.getRect(find.byKey(_k(true, 'am'))),
        const Rect.fromLTWH(24, 164, 86, 35));
    expect(tester.getRect(find.byKey(_k(true, 'pm'))),
        const Rect.fromLTWH(24, 199, 86, 35));
    // 숫자 칸 = 글자 부모 상자(108×70).
    Rect cell(Key k) => tester.getRect(find
        .ancestor(of: find.byKey(k), matching: find.byType(Container))
        .first);
    expect(cell(_k(true, 'hour')), const Rect.fromLTWH(130, 164, 108, 70));
    expect(cell(_k(true, 'minute')), const Rect.fromLTWH(261, 164, 108, 70));
    expect(cell(_k(false, 'hour')).top, 328);
    // 화살표 터치 영역 108×44 — 칸 위 24 + 칸 안 20.
    expect(tester.getRect(find.byKey(_k(true, 'hour_up'))),
        const Rect.fromLTWH(130, 140, 108, 44));
    expect(tester.getRect(find.byKey(_k(true, 'hour_down'))),
        const Rect.fromLTWH(130, 214, 108, 44));
    expect(tester.getRect(find.byKey(LcdQuietTimeScreen.doneKey)),
        const Rect.fromLTWH(12, 696, 369, 56));

    // 기본 20:00~8:00 = 시작 오후 8:00, 종료 오전 8:00.
    expect(_text(tester, _k(true, 'hour')), '8');
    expect(_text(tester, _k(true, 'minute')), '00');
    final hourStyle = tester.widget<Text>(find.byKey(_k(true, 'hour'))).style!;
    expect(hourStyle.fontSize, 24);
    expect(hourStyle.fontWeight, FontWeight.w600);
    expect(hourStyle.color, const Color(0xFF1E1E1E));
    final pmText = tester.widget<Text>(find.descendant(
        of: find.byKey(_k(true, 'pm')), matching: find.text('오후')));
    expect(pmText.style!.fontWeight, FontWeight.w700, reason: '선택');
    expect(pmText.style!.color, const Color(0xFFFAFAFA));
    final pmMaterial = tester.widget<Material>(find
        .descendant(
            of: find.byKey(_k(true, 'pm')), matching: find.byType(Material))
        .first);
    expect(pmMaterial.color, const Color(0xFFC00306));
    expect(_doneEnabled(tester), isFalse, reason: '바뀐 게 없다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('시 1~12 순환 — 오전/오후는 바뀌지 않는다', (tester) async {
    await _open(tester, link: lcdLink());
    for (var i = 0; i < 4; i++) {
      await _tap(tester, _k(true, 'hour_up'));
    }
    expect(_text(tester, _k(true, 'hour')), '12');
    await _tap(tester, _k(true, 'hour_up'));
    expect(_text(tester, _k(true, 'hour')), '1');
    await _tap(tester, _k(true, 'hour_down'));
    expect(_text(tester, _k(true, 'hour')), '12');
    // 시작은 계속 오후(선택 = 빨강 면).
    final pm = tester.widget<Material>(find
        .descendant(
            of: find.byKey(_k(true, 'pm')), matching: find.byType(Material))
        .first);
    expect(pm.color, const Color(0xFFC00306));
  });

  testWidgets('칸 안쪽 위 20도 올리기로 눌린다(터치 44)', (tester) async {
    await _open(tester, link: lcdLink());
    // 칸 상단(y164) 아래 10 지점.
    await tester.tapAt(const Offset(184, 174));
    await tester.pump();
    expect(_text(tester, _k(true, 'hour')), '9');
  });

  testWidgets('분 10분 단위 순환, 오전/오후 독립', (tester) async {
    await _open(tester, link: lcdLink());
    await _tap(tester, _k(false, 'minute_up'));
    expect(_text(tester, _k(false, 'minute')), '10');
    await _tap(tester, _k(false, 'minute_down'));
    await _tap(tester, _k(false, 'minute_down'));
    expect(_text(tester, _k(false, 'minute')), '50');
    await _tap(tester, _k(false, 'pm'));
    await _tap(tester, _k(false, 'am'));
    await _tap(tester, _k(false, 'pm'));
    expect(_text(tester, _k(false, 'hour')), '8', reason: '시는 그대로');
  });

  testWidgets('서버 값이 10분 단위가 아니면 그대로 보이고, 처음 누를 때 가까운 10분', (tester) async {
    await _open(tester,
        link: lcdLink(
            quiet: const LcdQuietWindow(
                startMinute: 22 * 60 + 7, endMinute: 6 * 60)));
    expect(_text(tester, _k(true, 'minute')), '07');
    await _tap(tester, _k(true, 'minute_up'));
    expect(_text(tester, _k(true, 'minute')), '10');
  });

  testWidgets('시작=종료면 완료가 막힌다', (tester) async {
    await _open(tester, link: lcdLink());
    await _tap(tester, _k(true, 'am')); // 오전 8:00 ~ 오전 8:00
    expect(_doneEnabled(tester), isFalse);
    await _tap(tester, _k(true, 'hour_up'));
    expect(_doneEnabled(tester), isTrue);
  });

  testWidgets('예약이 꺼져 있으면 폰에만 기억하고 돌아간다(오프라인이어도)', (tester) async {
    final env = await _open(tester, link: lcdLink(), online: false);
    await _tap(tester, _k(true, 'hour_up')); // 21:00~8:00
    expect(_doneEnabled(tester), isTrue);
    await tester.tap(find.byKey(LcdQuietTimeScreen.doneKey));
    await tester.pumpAndSettle();
    expect(env.repo.calls, isEmpty);
    expect(env.store.values['u1/$kLcdDevice'],
        const LcdQuietWindow(startMinute: 21 * 60, endMinute: 8 * 60));
    expect(find.byType(LcdQuietTimeScreen), findsNothing);
    expect(find.text('21:00~8:00'), findsOneWidget, reason: '설정 화면 시간 줄');
  });

  testWidgets('예약이 켜져 있으면 바로 보내고 돌아가 설정 화면 줄이 반짝인다', (tester) async {
    final env =
        await _open(tester, link: lcdLink(quiet: LcdQuietWindow.defaults));
    await _tap(tester, _k(false, 'hour_down')); // 20:00~7:00
    await tester.tap(find.byKey(LcdQuietTimeScreen.doneKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(env.repo.calls, ['quiet:d1:20:00~7:00']);
    expect(find.byType(LcdQuietTimeScreen), findsNothing);
    expect(find.byKey(LcdSettingsScreen.quietPendingKey), findsOneWidget);
    expect(find.text('20:00~7:00'), findsOneWidget, reason: '목표 시간을 그린다');
  });

  testWidgets('예약이 켜져 있고 오프라인이면 완료를 막고 안내', (tester) async {
    final env = _Env();
    addTearDown(env.rows.close);
    await pumpLcdRouter(tester,
        initial: lcdQuietTimePath(kLcdDevice),
        overrides: lcdOverrides(
            repo: env.repo,
            rows: env.rows,
            link: Stream.value(lcdLink(quiet: LcdQuietWindow.defaults)),
            online: false,
            now: _noon));
    await _tap(tester, _k(true, 'hour_up'));
    expect(_doneEnabled(tester), isFalse);
    expect(find.byKey(LcdQuietTimeScreen.offlineNoteKey), findsOneWidget);
  });
}
