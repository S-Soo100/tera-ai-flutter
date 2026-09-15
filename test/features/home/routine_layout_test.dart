import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

import 'schedule_fixtures.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// P10 Figma 실측 좌표(393×852, 상태바 62 / 홈 인디케이터 34) — 목록 1106:5317,
/// 빈 목록 1106:7142, 삭제 모드 1107:10246, 확인창 1107:9697, 기기 선택
/// 1106:4955, 편집기 1106:7234(환기팬)·1107:9131(냉각팬)·1107:9236(분무)·
/// 1107:9325(수정).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  Future<void> pump(WidgetTester tester, List<Schedule> items) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(FakeScheduleRepo(items)),
          currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
        ],
        child: EasyLocalization(
            supportedLocales: const [Locale('ko')],
            startLocale: const Locale('ko'),
            path: 'assets/l10n',
            assetLoader: const _Strings(),
            child: Builder(
                builder: (c) => MaterialApp(
                    theme: AppTheme.light,
                    locale: c.locale,
                    supportedLocales: c.supportedLocales,
                    localizationsDelegates: c.localizationDelegates,
                    builder: (c, child) => MediaQuery(
                        data: MediaQuery.of(c).copyWith(
                            padding:
                                const EdgeInsets.only(top: 62, bottom: 34)),
                        child: child!),
                    home: const RoutineSettingsScreen())))));
    await tester.pumpAndSettle();
  }

  Rect boxOf(WidgetTester tester, Key key) => tester.getRect(find
      .ancestor(of: find.byKey(key), matching: find.byType(Container))
      .first);

  testWidgets('목록 — 헤더·휴지통·줄 72/8·아이콘 40·스위치 80×32·CTA 696', (tester) async {
    await pump(tester, figmaScheduleRows());
    expect(find.text('기기 예약 설정'), findsOneWidget);
    expect(tester.getRect(find.byKey(RoutineSettingsScreen.deleteModeKey)),
        const Rect.fromLTWH(337, 62, 44, 44));
    expect(tester.getRect(find.byKey(const Key('schedule_pair_f'))),
        const Rect.fromLTWH(12, 122, 369, 72));
    expect(tester.getRect(find.byKey(const Key('schedule_pair_l'))).top, 202);
    expect(tester.getRect(find.byKey(const Key('schedule_pair_c'))).top, 282);
    final fanIcon = find
        .byWidgetPredicate((w) => w is FigmaIcon && w.name == FigmaIcons.fanOn);
    expect(tester.getRect(fanIcon), const Rect.fromLTWH(28, 138, 40, 40));
    final title = tester.getRect(find.text('12:00~15:30').first);
    expect(title.left, 76);
    expect(title.top, closeTo(138, 0.5));
    final sub = tester.getRect(find.text('토 일 · 켜짐').first);
    expect(sub.left, 76);
    expect(sub.top, closeTo(161, 0.5));
    expect(find.text('토 일 · 꺼짐'), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('schedule_pair_toggle_f'))),
        const Rect.fromLTWH(285, 142, 80, 32));
    expect(tester.getRect(find.byKey(RoutineSettingsScreen.addKey)),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(find.text('예약 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 목록 — 흰 상자 369×64, 문구 x28', (tester) async {
    await pump(tester, const []);
    expect(tester.getRect(find.byKey(RoutineSettingsScreen.emptyKey)),
        const Rect.fromLTWH(12, 122, 369, 64));
    final text = tester.getRect(find.text('예약이 없습니다. 예약을 추가해 주세요.'));
    expect(text.left, 28);
    expect(text.top, closeTo(140, 0.5));
    expect(tester.getRect(find.byKey(RoutineSettingsScreen.addKey)).top, 696);
  });

  testWidgets('삭제 모드 — 스위치 x253, 체크 x341/y146, 빨간 CTA, 확인창 345×144',
      (tester) async {
    await pump(tester, figmaScheduleRows());
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('schedule_pair_toggle_f'))),
        const Rect.fromLTWH(253, 142, 80, 32));
    expect(tester.getRect(find.byKey(const Key('schedule_pair_check_f'))),
        const Rect.fromLTWH(341, 146, 24, 24));
    expect(find.byKey(RoutineSettingsScreen.deleteSelectedKey), findsNothing);
    await tester.tap(find.byKey(const Key('schedule_pair_check_f')));
    await tester.tap(find.byKey(const Key('schedule_pair_check_l')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(RoutineSettingsScreen.deleteSelectedKey)),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(find.text('2개 항목 삭제'), findsOneWidget);
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteSelectedKey));
    await tester.pumpAndSettle();
    final dialog = tester.getRect(find
        .ancestor(
            of: find.text('예약을 삭제하시겠습니까?'), matching: find.byType(Material))
        .first);
    expect(dialog.width, 345);
    expect(dialog.height, 144);
    expect(dialog.top, 354);
    expect(tester.getRect(find.text('예약을 삭제하시겠습니까?')).top, 378);
    expect(tester.getRect(find.byKey(const Key('routine_delete_cancel'))),
        const Rect.fromLTWH(48, 430, 142, 44));
    expect(
        tester.getRect(find.byKey(const Key('routine_delete_ok'))).left, 203);
    await tester.tap(find.byKey(const Key('routine_delete_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule_pair_f')), findsNothing);
    expect(find.byKey(const Key('schedule_pair_c')), findsOneWidget);
    expect(find.byKey(RoutineSettingsScreen.addKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기기 선택 — 제목 y120, 4타일 180.5×72 @ y161/241', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('어떤 기기의 예약을 추가할까요?'));
    expect(title.top, 120);
    expect(title.center.dx, 196.5, reason: '원본은 369 폭 가운데 정렬');
    expect(tester.getRect(find.byKey(const Key('routine_device_fan'))),
        const Rect.fromLTWH(12, 161, 180.5, 72));
    expect(tester.getRect(find.byKey(const Key('routine_device_mist'))).left,
        200.5);
    expect(
        tester.getRect(find.byKey(const Key('routine_device_cool'))).top, 241);
    expect(tester.getRect(find.byKey(const Key('routine_device_led'))).topLeft,
        const Offset(200.5, 241));
    final fanIcon = find
        .byWidgetPredicate((w) => w is FigmaIcon && w.name == FigmaIcons.fanOn);
    expect(tester.getRect(fanIcon), const Rect.fromLTWH(28, 177, 40, 40));
    expect(tester.getRect(find.text('환기팬')).left, 76);
    expect(tester.getRect(find.text('환기팬')).top, closeTo(187.5, 0.5));
  });

  testWidgets('환기팬 편집기 — 시작 118 / 오전오후 86×70 / 시·분 108×70 / 종료 283 / 반복 448',
      (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_device_fan')));
    await tester.pumpAndSettle();
    expect(find.text('환기팬 예약'), findsOneWidget);
    expect(tester.getRect(find.text('시작')).topLeft, const Offset(36, 118));
    expect(tester.getRect(find.byKey(const Key('routine_start_am'))),
        const Rect.fromLTWH(24, 165, 86, 35));
    expect(tester.getRect(find.byKey(const Key('routine_start_pm'))).top, 200);
    expect(boxOf(tester, const Key('routine_start_hour')),
        const Rect.fromLTWH(130, 165, 108, 70));
    expect(boxOf(tester, const Key('routine_start_minute')),
        const Rect.fromLTWH(261, 165, 108, 70));
    expect(tester.getRect(find.byKey(const Key('routine_start_hour_up'))),
        const Rect.fromLTWH(130, 141, 108, 24));
    expect(tester.getRect(find.byKey(const Key('routine_start_hour_down'))).top,
        235);
    expect(tester.getCenter(find.text(':').first).dx, closeTo(249.5, 0.5));
    expect(tester.getRect(find.text('종료')).top, 283);
    expect(tester.getRect(find.byKey(const Key('routine_end_am'))).top, 330);
    expect(tester.getRect(find.text('반복')).top, 448);
    expect(tester.getRect(find.byKey(const Key('routine_day_1'))),
        const Rect.fromLTWH(24, 475, (345 - 24) / 7, 44));
    expect(tester.getRect(find.byKey(const Key('routine_day_7'))).left,
        closeTo(323.1, 0.2));
    expect(tester.getRect(find.byKey(const Key('routine_save'))),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(find.byKey(const Key('routine_delete')), findsNothing);
    // 기본 오후 12:00 → 오후 2:00, 12시간제 표기.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('냉각팬 편집기 — 종료 칩 111×44 @ y310, 반복 378/405', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_device_cool')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('routine_after_30'))),
        const Rect.fromLTWH(24, 310, 111, 44));
    expect(tester.getRect(find.byKey(const Key('routine_after_60'))).left, 141);
    expect(
        tester.getRect(find.byKey(const Key('routine_after_120'))).left, 258);
    expect(find.text('30분 뒤'), findsOneWidget);
    expect(find.text('2시간 뒤'), findsOneWidget);
    expect(tester.getRect(find.text('반복')).top, 378);
    expect(tester.getRect(find.byKey(const Key('routine_day_1'))).top, 405);
  });

  testWidgets('분무 편집기 — 시작만, 반복 283/310', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_device_mist')));
    await tester.pumpAndSettle();
    expect(find.text('분무 예약'), findsOneWidget);
    expect(find.text('종료'), findsNothing);
    expect(tester.getRect(find.text('반복')).top, 283);
    expect(tester.getRect(find.byKey(const Key('routine_day_1'))).top, 310);
  });

  testWidgets('수정 — 저장 696 위에, "예약 삭제" 752 (글자 중심 780)', (tester) async {
    await pump(tester, figmaScheduleRows());
    await tester.tap(find.byKey(const Key('schedule_pair_f')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('routine_save'))),
        const Rect.fromLTWH(12, 696, 369, 56));
    expect(tester.getRect(find.byKey(const Key('routine_delete'))),
        const Rect.fromLTWH(12, 752, 369, 56));
    expect(tester.getCenter(find.text('예약 삭제')).dy, 780);
    // 12:00 → 오후 12, 15:30 → 오후 3:30.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
