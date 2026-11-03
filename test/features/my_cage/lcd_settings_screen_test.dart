import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_quiet_time_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_settings_screen.dart';

import 'lcd_fixtures.dart';

/// 정오 KST(꺼짐 예약 밖).
final _noon = DateTime.utc(2026, 11, 3, 3);

/// 23:00 KST(20:00~8:00 예약 안).
final _night = DateTime.utc(2026, 11, 3, 14);

const _quiet20to8 = LcdQuietWindow.defaults;
const _quiet20to6 = LcdQuietWindow(startMinute: 20 * 60, endMinute: 6 * 60);

class _Env {
  _Env();
  final repo = FakeLcdRepo();
  final rows = CommandRows();
  final store = MemoryQuietStore();
}

Future<_Env> _pump(
  WidgetTester tester, {
  required DeviceLinkStatus link,
  bool online = true,
  DateTime? now,
  void Function(FakeLcdRepo repo)? setUp,
  LcdQuietWindow? remembered,
  bool settle = true,
}) async {
  final env = _Env();
  setUp?.call(env.repo);
  if (remembered != null) env.store.values['u1/$kLcdDevice'] = remembered;
  await pumpLcdRouter(tester,
      settle: settle,
      overrides: lcdOverrides(
          repo: env.repo,
          rows: env.rows,
          link: Stream.value(link),
          quietStore: env.store,
          online: online,
          now: now ?? _noon,
          devices: const [lcdTestDevice]));
  addTearDown(env.rows.close);
  return env;
}

bool _switchValue(WidgetTester tester, Key key) => tester
    .widget<ScheduleSwitch>(find.descendant(
        of: find.byKey(key), matching: find.byType(ScheduleSwitch)))
    .value;

/// 위젯이 흐리게(불투명도 0.4) 그려졌나.
bool _dimmed(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)))
    .any((o) => o.opacity == 0.4);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(initLcdTestStrings);

  group('수치 (Figma 1659:5964 · 1660:6770, 393×852)', () {
    testWidgets('예약 꺼짐 — 묶음 y130/y202/y324, 줄 48, 줄 사이 2, 각주 y429',
        (tester) async {
      await _pump(tester, link: lcdLink());
      Rect r(Key k) => tester.getRect(find.byKey(k));
      expect(r(LcdSettingsScreen.powerRowKey),
          const Rect.fromLTWH(24, 130, 345, 48));
      expect(r(LcdSettingsScreen.textRowKey),
          const Rect.fromLTWH(24, 202, 345, 48));
      expect(r(LcdSettingsScreen.saverRowKey),
          const Rect.fromLTWH(24, 252, 345, 48));
      expect(r(LcdSettingsScreen.quietRowKey),
          const Rect.fromLTWH(24, 324, 345, 48));
      expect(r(LcdSettingsScreen.timeRowKey),
          const Rect.fromLTWH(24, 374, 345, 48));
      expect(r(LcdSettingsScreen.quietNoteKey).top, 429);
      expect(r(LcdSettingsScreen.quietNoteKey).left, 36);

      // 스위치 80×32, 줄 오른쪽 8.
      final sw = tester.getRect(find.descendant(
          of: find.byKey(LcdSettingsScreen.powerSwitchKey),
          matching: find.byType(ScheduleSwitch)));
      expect(sw, const Rect.fromLTWH(281, 138, 80, 32));

      // 제목 x36 18/600 #3C3C3C.
      final title = find.text('화면 전원 · 켜짐');
      expect(tester.getRect(title).left, 36);
      final style = tester.widget<Text>(title).style!;
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, const Color(0xFF3C3C3C));

      // 오른쪽 값 16/500 #949090.
      expect(find.text('viva-iot-0001'), findsOneWidget);
      // 사진 없이 꺼져 있으면 Figma대로 '꺼짐'('사진 없음'은 켜 놨을 때만).
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '꺼짐');
      expect(find.text('20:00~8:00'), findsOneWidget);
      expect(find.text('설정한 시간 동안 화면을 끄고, 이후 자동으로 다시 켜집니다'), findsOneWidget);
      expect(_switchValue(tester, LcdSettingsScreen.powerSwitchKey), isTrue);
      expect(_switchValue(tester, LcdSettingsScreen.quietSwitchKey), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('예약 켜짐·사진 있음 — 시간 20:00~6:00, 보호 사진 켜짐', (tester) async {
      await _pump(tester,
          link: lcdLink(
              quiet: _quiet20to6,
              imageKey: 'k1',
              saver: LcdSaverSettings.defaults.copyWith(enabled: true)));
      expect(_switchValue(tester, LcdSettingsScreen.quietSwitchKey), isTrue);
      expect(find.text('20:00~6:00'), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '켜짐');
    });

    testWidgets('보호기가 켜져 있어도 사진이 없으면 "사진 없음"', (tester) async {
      await _pump(tester,
          link: lcdLink(
              saver: LcdSaverSettings.defaults.copyWith(enabled: true)));
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '사진 없음');
    });
  });

  group('전원', () {
    testWidgets('끄면 바로 꺼짐 + 반짝임, 같은 종류는 대기 중 다시 안 보낸다', (tester) async {
      final env = await _pump(tester, link: lcdLink());
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey));
      await _frames(tester);
      expect(env.repo.calls, ['power:d1:false']);
      expect(find.text('화면 전원 · 꺼짐'), findsOneWidget);
      expect(_switchValue(tester, LcdSettingsScreen.powerSwitchKey), isFalse);
      expect(find.byKey(LcdSettingsScreen.powerPendingKey), findsOneWidget);

      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey),
          warnIfMissed: false);
      await _frames(tester);
      expect(env.repo.calls, ['power:d1:false'], reason: '대기 중엔 잠긴다');
    });

    testWidgets('기기가 응답하지 않으면 원위치 + ControlFeedback 안내', (tester) async {
      final env = await _pump(tester, link: lcdLink());
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey));
      await _frames(tester);
      env.rows.emit('c1', 'no_ack');
      await _frames(tester);
      expect(find.text('화면 전원 · 켜짐'), findsOneWidget);
      expect(find.byKey(LcdSettingsScreen.powerPendingKey), findsNothing);
      expect(find.text('기기 응답을 받지 못했어요'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('8초 동안 결과가 없으면 "응답이 늦어요"', (tester) async {
      await _pump(tester, link: lcdLink());
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey));
      await _frames(tester);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      expect(find.text('기기 응답이 늦어요. 잠시만 기다려 주세요'), findsOneWidget);
      expect(find.byKey(LcdSettingsScreen.powerPendingKey), findsOneWidget,
          reason: '대기는 유지');
    });

    testWidgets('구 펌웨어로 거절되면 업데이트 안내', (tester) async {
      final env = await _pump(tester, link: lcdLink());
      env.repo.error = unsupportedFirmware;
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey));
      await _frames(tester);
      expect(find.text('기기 업데이트가 필요해요'), findsOneWidget);
      expect(find.text('화면 전원 · 켜짐'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('기기 구분 (§12-4)', () {
    testWidgets('구 펌웨어 — 세 줄 흐리게·조작 불가 + 업데이트 안내', (tester) async {
      final env =
          await _pump(tester, link: lcdLink(support: LcdSupport.needsUpdate));
      expect(find.byKey(LcdSettingsScreen.updateNoteKey), findsOneWidget);
      expect(find.text('기기 업데이트 후 쓸 수 있어요'), findsOneWidget);
      for (final k in [
        LcdSettingsScreen.powerRowKey,
        LcdSettingsScreen.saverRowKey,
        LcdSettingsScreen.quietRowKey,
        LcdSettingsScreen.timeRowKey,
      ]) {
        expect(
            _dimmed(
                tester,
                find
                    .descendant(of: find.byKey(k), matching: find.byType(Text))
                    .first),
            isTrue,
            reason: '$k');
      }
      expect(
          _dimmed(tester, find.byKey(LcdSettingsScreen.textValueKey)), isFalse,
          reason: '문구 줄은 쓸 수 있다');
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey),
          warnIfMissed: false);
      await tester.tap(find.byKey(LcdSettingsScreen.quietSwitchKey),
          warnIfMissed: false);
      await tester.tap(find.byKey(LcdSettingsScreen.timeRowKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(env.repo.calls, isEmpty);
      expect(env.repo.getStateCalls, 0, reason: '구 펌웨어는 GET /lcd 없이 그린다');
      expect(find.byType(LcdQuietTimeScreen), findsNothing);
    });

    testWidgets('허브 — 문구 줄만', (tester) async {
      await _pump(tester, link: lcdLink(support: LcdSupport.hub));
      expect(find.byKey(LcdSettingsScreen.textRowKey), findsOneWidget);
      expect(find.byKey(LcdSettingsScreen.powerRowKey), findsNothing);
      expect(find.byKey(LcdSettingsScreen.saverRowKey), findsNothing);
      expect(find.byKey(LcdSettingsScreen.quietRowKey), findsNothing);
      expect(find.byKey(LcdSettingsScreen.quietNoteKey), findsNothing);
    });
  });

  group('오프라인', () {
    testWidgets('스위치 막음 + 안내, 예약이 꺼져 있으면 시간은 고칠 수 있다', (tester) async {
      final env = await _pump(tester, link: lcdLink(), online: false);
      expect(find.text('기기가 연결돼 있지 않아 지금은 보낼 수 없어요'), findsOneWidget);
      await tester.tap(find.byKey(LcdSettingsScreen.powerSwitchKey),
          warnIfMissed: false);
      await tester.tap(find.byKey(LcdSettingsScreen.quietSwitchKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(env.repo.calls, isEmpty);
      await tester.tap(find.byKey(LcdSettingsScreen.timeRowKey));
      await tester.pumpAndSettle();
      expect(find.byType(LcdQuietTimeScreen), findsOneWidget);
    });

    testWidgets('예약이 켜져 있으면 오프라인에서 시간 줄도 막는다', (tester) async {
      await _pump(tester, link: lcdLink(quiet: _quiet20to6), online: false);
      await tester.tap(find.byKey(LcdSettingsScreen.timeRowKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(LcdQuietTimeScreen), findsNothing);
    });
  });

  group('불러오기', () {
    testWidgets('불러오기 전엔 반짝임 — 스위치가 없어 쓸 수 없다', (tester) async {
      final gate = Completer<void>();
      final env = await _pump(tester,
          link: lcdLink(), settle: false, setUp: (r) => r.stateGate = gate);
      expect(find.byKey(LcdSettingsScreen.loadingKey), findsOneWidget);
      expect(find.byKey(LcdSettingsScreen.powerSwitchKey), findsNothing);
      expect(find.byKey(LcdSettingsScreen.quietSwitchKey), findsNothing);
      expect(find.byKey(LcdSettingsScreen.textRowKey), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(LcdSettingsScreen.powerSwitchKey), findsOneWidget);
      expect(env.repo.calls, isEmpty);
    });

    testWidgets('실패하면 재시도 — 누르면 다시 읽는다', (tester) async {
      final env = await _pump(tester,
          link: lcdLink(), setUp: (r) => r.stateError = Exception('down'));
      expect(find.byKey(LcdSettingsScreen.retryKey), findsOneWidget);
      expect(find.text('화면 설정을 불러오지 못했어요'), findsOneWidget);
      expect(find.byKey(LcdSettingsScreen.powerSwitchKey), findsNothing);
      expect(env.repo.getStateCalls, 1);
      env.repo.stateError = null;
      await tester.tap(find.byKey(LcdSettingsScreen.retryKey));
      await tester.pumpAndSettle();
      expect(env.repo.getStateCalls, 2);
      expect(find.byKey(LcdSettingsScreen.powerSwitchKey), findsOneWidget);
    });
  });

  group('꺼짐 예약', () {
    testWidgets('켜면 마지막 시간으로 보내고, 대기 중엔 스위치·시간 줄을 함께 잠근다', (tester) async {
      final env = await _pump(tester, link: lcdLink(), remembered: _quiet20to6);
      expect(find.text('20:00~6:00'), findsOneWidget, reason: '폰 기억값');
      await tester.tap(find.byKey(LcdSettingsScreen.quietSwitchKey));
      await _frames(tester);
      expect(env.repo.calls, ['quiet:d1:20:00~6:00']);
      expect(find.byKey(LcdSettingsScreen.quietPendingKey), findsOneWidget);
      expect(_switchValue(tester, LcdSettingsScreen.quietSwitchKey), isTrue);
      await tester.tap(find.byKey(LcdSettingsScreen.timeRowKey),
          warnIfMissed: false);
      await _frames(tester);
      expect(find.byType(LcdQuietTimeScreen), findsNothing);
    });

    testWidgets('끄면 예약 해제(DELETE)', (tester) async {
      final env = await _pump(tester, link: lcdLink(quiet: _quiet20to6));
      await tester.tap(find.byKey(LcdSettingsScreen.quietSwitchKey));
      await _frames(tester);
      expect(env.repo.calls, ['quiet_clear:d1']);
      expect(find.text('20:00~6:00'), findsOneWidget, reason: '시간 줄은 그대로');
    });
  });

  group('전원 보조 글자·각주 (§12-1 / §11-3)', () {
    testWidgets('구 규칙 — 전원 켜짐 + 예약 시간 안이면 "지금은 꺼짐 예약 시간이라 … 켜져요"',
        (tester) async {
      await _pump(tester, link: lcdLink(quiet: _quiet20to8), now: _night);
      expect(find.text('지금은 꺼짐 예약 시간이라 오전 8:00에 켜져요'), findsOneWidget);
      expect(find.text('설정한 시간 동안 화면을 끄고, 이후 자동으로 다시 켜집니다'), findsOneWidget);
    });

    testWidgets('구 규칙 — 예약 시간 밖이면 보조 글자 없음', (tester) async {
      await _pump(tester, link: lcdLink(quiet: _quiet20to8), now: _noon);
      expect(find.byKey(LcdSettingsScreen.powerNoteKey), findsNothing);
    });

    testWidgets('구 규칙 — 전원 꺼짐이면 각주가 "다시 켤 때까지 꺼져 있어요"', (tester) async {
      await _pump(tester,
          link: lcdLink(power: false, quiet: _quiet20to8), now: _night);
      expect(find.byKey(LcdSettingsScreen.powerNoteKey), findsNothing,
          reason: '이미 꺼져 있다 — 예약 시간 안내 안 함');
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.quietNoteKey)).data,
          '다시 켤 때까지 꺼져 있어요');
    });

    testWidgets('신 규칙 — 화면 꺼짐 + 예약 시간 안이면 예약 안내, 각주는 Figma 그대로',
        (tester) async {
      await _pump(tester,
          link: lcdLink(
              power: true,
              screenOn: false,
              lcdOverride: true,
              quiet: _quiet20to8),
          now: _night);
      expect(find.text('화면 전원 · 꺼짐'), findsOneWidget,
          reason: '스위치 = 실제 화면 상태(lcd_screen_on)');
      expect(find.text('지금은 꺼짐 예약 시간이라 오전 8:00에 켜져요'), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.quietNoteKey)).data,
          '설정한 시간 동안 화면을 끄고, 이후 자동으로 다시 켜집니다');
    });

    testWidgets('신 규칙 — 수동 조작 중이면 "… 부터 예약대로 돌아가요"', (tester) async {
      await _pump(tester,
          link: lcdLink(
              screenOn: true,
              lcdOverride: true,
              quiet: _quiet20to8,
              // 2026-11-04 08:00 KST.
              overrideUntil: DateTime.utc(2026, 11, 3, 23)),
          now: _night);
      expect(find.text('오전 8:00부터 예약대로 돌아가요'), findsOneWidget);
    });

    testWidgets('신 규칙 — 예약 없이 꺼져 있으면 "다시 켤 때까지 꺼져 있어요"(전원 줄 아래)',
        (tester) async {
      await _pump(tester,
          link: lcdLink(power: false, screenOn: false, lcdOverride: true));
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.powerNoteKey)).data,
          '다시 켤 때까지 꺼져 있어요');
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.quietNoteKey)).data,
          '설정한 시간 동안 화면을 끄고, 이후 자동으로 다시 켜집니다');
    });

    testWidgets('신 펌웨어라도 화면 상태 보고 전(null)이면 구 규칙', (tester) async {
      await _pump(tester,
          link: lcdLink(power: false, lcdOverride: true, quiet: _quiet20to8),
          now: _night);
      expect(find.text('화면 전원 · 꺼짐'), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.quietNoteKey)).data,
          '다시 켤 때까지 꺼져 있어요');
    });

    testWidgets('예약 명령 대기 중엔 예약 시간 안내를 숨긴다', (tester) async {
      await _pump(tester, link: lcdLink(quiet: _quiet20to8), now: _night);
      expect(find.byKey(LcdSettingsScreen.powerNoteKey), findsOneWidget);
      await tester.tap(find.byKey(LcdSettingsScreen.quietSwitchKey));
      await _frames(tester);
      expect(find.byKey(LcdSettingsScreen.powerNoteKey), findsNothing);
    });
  });

  testWidgets('화면 표시 문구 줄 → 문구 화면, 안내 한 줄', (tester) async {
    await _pump(tester, link: lcdLink());
    await tester.tap(find.byKey(LcdSettingsScreen.textRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lcd_text_field')), findsOneWidget);
    expect(find.text('중복되지 않는 이름으로 설정해 주세요'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .controller!
            .text,
        'viva-iot-0001');
  });

  group('홈 줄 (HomeLcdRow)', () {
    Future<void> pumpHome(WidgetTester tester, DeviceLinkStatus link) async {
      final env = _Env();
      addTearDown(env.rows.close);
      await pumpLcdRouter(tester,
          initial: '/',
          home: const Scaffold(body: HomeLcdRow()),
          overrides: [
            ...lcdOverrides(
                repo: env.repo,
                rows: env.rows,
                link: Stream.value(link),
                now: _noon,
                devices: const [lcdTestDevice]),
            currentSetProvider.overrideWith((ref) async => EnclosureSet(
                enclosure: Enclosure(
                    id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
                device: lcdTestDevice,
                camera: null,
                pet: null)),
          ]);
    }

    testWidgets('라벨은 "모듈 화면 설정", 누르면 모듈 화면 설정 화면', (tester) async {
      await pumpHome(tester, lcdLink());
      expect(find.text('모듈 화면 설정'), findsOneWidget);
      expect(find.text('viva-iot-0001'), findsOneWidget);
      await tester.tap(find.byKey(HomeLcdRow.rowKey));
      await tester.pumpAndSettle();
      expect(find.byType(LcdSettingsScreen), findsOneWidget);
    });

    testWidgets('구 펌웨어·허브도 줄은 보인다', (tester) async {
      await pumpHome(tester, lcdLink(support: LcdSupport.hub));
      expect(find.byKey(HomeLcdRow.rowKey), findsOneWidget);
    });

    testWidgets('LCD 없는 허브면 줄을 숨긴다', (tester) async {
      await pumpHome(tester, lcdLink(support: LcdSupport.noLcd));
      expect(find.byKey(HomeLcdRow.rowKey), findsNothing);
    });
  });
}
