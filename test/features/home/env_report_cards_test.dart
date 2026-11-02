// v4 일일·주간 분석 카드(계획 2026-11-03 Task 4, Figma A15·A20).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_report_cards.dart';
import 'package:vivanaut/shared/domain/keep_all_words.dart';

import '../notification/notification_test_host.dart';

EnvReportCard _card(EnvReportElement e,
        {String title = '제목',
        EnvReportStatus status = EnvReportStatus.caution,
        List<String> lines = const ['줄']}) =>
    EnvReportCard(
        element: e, code: '', status: status, title: title, lines: lines);

EnvDailyReport _daily({EnvReportCard? temp, EnvReportCard? humid}) =>
    EnvDailyReport(
        deviceId: 'd1',
        reportDate: DateTime(2026, 11, 2),
        tempCard: temp,
        humidCard: humid);

EnvWeeklyReport _weekly(
        {EnvReportCard? temp,
        EnvReportCard? humid,
        List<EnvReportNotice> notices = const []}) =>
    EnvWeeklyReport(
        deviceId: 'd1',
        weekStart: DateTime(2026, 11, 2),
        tempCard: temp,
        humidCard: humid,
        notices: notices);

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<BuildContext> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext ctx;
    await tester.pumpWidget(localizedNotificationHost((context) => MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: Builder(builder: (c) {
              ctx = c;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(alignment: Alignment.topCenter, child: child),
              );
            }),
          ),
        )));
    await tester.pumpAndSettle();
    return ctx;
  }

  Text textOf(WidgetTester tester, String s) =>
      tester.widget<Text>(find.text(keepAllWords(s)));

  group('일일', () {
    testWidgets('daily_one_card_only_renders_single_row', (tester) async {
      await pump(
          tester,
          EnvDailyReportCard(
              report: _daily(temp: _card(EnvReportElement.temp))));
      expect(find.text('온도'), findsOneWidget);
      expect(find.text('습도'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('두 줄 — 온도 먼저, 구분선 1, 칩 색·설명 자간(A15)', (tester) async {
      final ctx = await pump(
          tester,
          EnvDailyReportCard(
              report: _daily(
                  temp: _card(EnvReportElement.temp,
                      title: '낮은 온도가 기록됐어요',
                      lines: [
                        '14:21~16:20 적정 온도보다 최대 -3.1℃ 이탈',
                        '16:30~17:00 적정 온도보다 최대 -2℃ 이탈'
                      ]),
                  humid: _card(EnvReportElement.humid, title: '건조를 주의해 주세요'))));
      final glass = ctx.glass;
      expect(find.byType(Divider), findsOneWidget);
      final tempY = tester
          .getTopLeft(
              find.byKey(EnvDailyReportCard.rowKey(EnvReportElement.temp)))
          .dy;
      final humidY = tester
          .getTopLeft(
              find.byKey(EnvDailyReportCard.rowKey(EnvReportElement.humid)))
          .dy;
      expect(tempY, lessThan(humidY));
      expect(
          tester.widget<Text>(find.text('온도')).style!.color, glass.tempAccent);
      expect(
          tester.widget<Text>(find.text('습도')).style!.color, glass.humidAccent);
      final line = textOf(tester, '14:21~16:20 적정 온도보다 최대 -3.1℃ 이탈');
      expect(line.style!.letterSpacing, closeTo(-0.42, 1e-9));
      expect(find.text(keepAllWords('16:30~17:00 적정 온도보다 최대 -2℃ 이탈')),
          findsOneWidget);
    });

    testWidgets('카드가 없으면 아무것도 그리지 않는다', (tester) async {
      await pump(tester, EnvDailyReportCard(report: _daily()));
      expect(find.byKey(EnvDailyReportCard.cardKey), findsOneWidget);
      expect(find.text('온도'), findsNothing);
      expect(tester.getSize(find.byKey(EnvDailyReportCard.cardKey)).height, 0);
    });
  });

  group('주간', () {
    Widget section(EnvWeeklyReport r,
            [EnvReportElement e = EnvReportElement.temp]) =>
        EnvWeeklyReportSection(report: r, element: e);

    testWidgets('주간 칩 문구 경고/주의/적정, 설명 자간 −2%(A20)', (tester) async {
      for (final (status, chip) in [
        (EnvReportStatus.danger, '경고'),
        (EnvReportStatus.caution, '주의'),
        (EnvReportStatus.normal, '적정'),
      ]) {
        await pump(
            tester,
            section(_weekly(
                temp: _card(EnvReportElement.temp,
                    status: status, lines: ['총 3회 위험 온도 발생']))));
        expect(find.text(chip), findsOneWidget);
        expect(textOf(tester, '총 3회 위험 온도 발생').style!.letterSpacing,
            closeTo(-0.28, 1e-9));
      }
    });

    testWidgets('weekly_unknown_status_no_chip', (tester) async {
      await pump(
          tester,
          section(_weekly(
              temp: _card(EnvReportElement.temp,
                  title: '새 카드', status: EnvReportStatus.unknown))));
      expect(find.text(keepAllWords('새 카드')), findsOneWidget);
      for (final chip in ['경고', '주의', '적정']) {
        expect(find.text(chip), findsNothing);
      }
    });

    testWidgets('disconnect_notice_above_card', (tester) async {
      await pump(
          tester,
          section(_weekly(
              temp: _card(EnvReportElement.temp, title: '카드 제목'),
              notices: const [
                EnvReportNotice(
                    code: 'ERR_DISCONNECT',
                    element: EnvReportElement.temp,
                    title: '수집이 불안정했어요',
                    body: '연결 상태를 확인해 주세요'),
              ])));
      final notice = tester
          .getTopLeft(find
              .byKey(EnvWeeklyReportSection.noticeKey(EnvReportElement.temp)))
          .dy;
      final card = tester
          .getTopLeft(
              find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.temp)))
          .dy;
      expect(notice, lessThan(card));
      expect(find.text(keepAllWords('연결 상태를 확인해 주세요')), findsOneWidget);
    });

    testWidgets('ERR_NO_DATA면 카드 대신 안내만', (tester) async {
      await pump(
          tester,
          section(_weekly(
              temp: _card(EnvReportElement.temp, title: '카드 제목'),
              notices: const [
                EnvReportNotice(
                    code: 'ERR_NO_DATA',
                    element: EnvReportElement.temp,
                    title: '주간 분석을 위한 데이터를 모으고 있어요',
                    body: '최소 3일의 데이터가 필요해요'),
              ])));
      expect(find.byKey(EnvWeeklyReportSection.cardKey(EnvReportElement.temp)),
          findsNothing);
      expect(find.text(keepAllWords('주간 분석을 위한 데이터를 모으고 있어요')), findsOneWidget);
    });

    testWidgets('다른 지표 안내·카드는 그리지 않는다', (tester) async {
      final r = _weekly(
          humid: _card(EnvReportElement.humid, title: '습도 카드'),
          notices: const [
            EnvReportNotice(
                code: 'ERR_NO_DATA',
                element: EnvReportElement.humid,
                title: '습도 안내',
                body: '')
          ]);
      await pump(tester, section(r));
      expect(find.text(keepAllWords('습도 카드')), findsNothing);
      expect(find.text(keepAllWords('습도 안내')), findsNothing);
      expect(
          EnvWeeklyReportSection.hasContent(r, EnvReportElement.temp), isFalse);
      expect(
          EnvWeeklyReportSection.hasContent(r, EnvReportElement.humid), isTrue);
    });
  });

  group('주간 설명 한 문단(Figma A20)', () {
    test('마침표 없는 줄 뒤에는 ". "로 잇는다', () {
      expect(
          EnvWeeklyReportSection.joinLines(
              ['총 3회 위험 온도 발생. 적정 온도보다 최대 5.2℃ 이탈', '주간 시간에 온도 이탈이 집중되었어요']),
          '총 3회 위험 온도 발생. 적정 온도보다 최대 5.2℃ 이탈. 주간 시간에 온도 이탈이 집중되었어요');
    });
    test('마침표로 끝난 줄 뒤에는 공백만', () {
      expect(
          EnvWeeklyReportSection.joinLines(
              ['총 2회 위험 온도 발생.', '야간 시간에 온도 이탈이 집중되었어요']),
          '총 2회 위험 온도 발생. 야간 시간에 온도 이탈이 집중되었어요');
    });
    test('한 줄·빈 목록은 그대로', () {
      expect(EnvWeeklyReportSection.joinLines(['총 3회 적정 온도 범위를 벗어났어요']),
          '총 3회 적정 온도 범위를 벗어났어요');
      expect(EnvWeeklyReportSection.joinLines(const []), isNull);
    });
    testWidgets('주간 카드는 설명 Text 하나', (tester) async {
      await pump(
          tester,
          EnvWeeklyReportSection(
              report: _weekly(
                  temp: _card(EnvReportElement.temp,
                      status: EnvReportStatus.danger, lines: ['줄 하나', '줄 둘'])),
              element: EnvReportElement.temp));
      expect(find.text(keepAllWords('줄 하나. 줄 둘')), findsOneWidget);
      expect(find.text(keepAllWords('줄 하나')), findsNothing);
    });
  });
}
