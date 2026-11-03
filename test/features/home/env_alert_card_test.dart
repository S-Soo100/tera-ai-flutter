// v4 실시간 이탈 카드(계획 Task 6, Figma A10·A12·A13).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_alert_card.dart';
import 'package:vivanaut/shared/domain/keep_all_words.dart';

import '../notification/notification_test_host.dart';

EnvAlert _alert(String id, String kind, String level, String message) =>
    EnvAlert.fromRow({
      'id': id,
      'device_id': 'd1',
      'kind': kind,
      'message': message,
      'context': {'rule': 'v4', 'level': level},
      'triggered_at': '2026-11-02T05:00:00Z',
      'resolved_at': null,
    })!;

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<void> pump(WidgetTester tester, List<EnvAlert> alerts) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(localizedNotificationHost((context) => MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: EnvAlertCard(alerts: alerts)),
            ),
          ),
        )));
    await tester.pumpAndSettle();
  }

  final humidCaution =
      _alert('h', 'env_humid_low', 'caution', '[건조 주의] 적정 습도보다 -5%p');
  final tempDanger =
      _alert('t', 'env_temp_low', 'danger', '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요');

  testWidgets('열린 행 0개면 카드 없음', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(EnvAlertCard.cardKey), findsNothing);
  });

  testWidgets('경고가 주의보다 위 — 칩·제목은 message 그대로, 설명은 고정 문구', (tester) async {
    await pump(tester, EnvAlert.openLatestPerSlot([humidCaution, tempDanger]));
    final dangerRow =
        tester.getRect(find.byKey(EnvAlertCard.rowKey(tempDanger)));
    final cautionRow =
        tester.getRect(find.byKey(EnvAlertCard.rowKey(humidCaution)));
    expect(dangerRow.top, lessThan(cautionRow.top));

    expect(find.text('저온 경고'), findsOneWidget);
    expect(find.text(keepAllWords('온도가 너무 낮아 개체가 위험할 수 있어요')), findsOneWidget);
    expect(find.text(keepAllWords('즉시 온도를 올려주세요')), findsOneWidget);
    expect(find.text('건조 주의'), findsOneWidget);
    // %p를 %로 바꾸거나 숫자를 다시 계산하지 않는다(D4).
    expect(find.text(keepAllWords('적정 습도보다 -5%p')), findsOneWidget);
    expect(find.text(keepAllWords('사육장에 수분을 보충해 주세요')), findsOneWidget);
    // 줄 사이 구분선 하나.
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('칩 색 — 온도는 tempAccent, 습도는 humidAccent', (tester) async {
    await pump(tester, [tempDanger, humidCaution]);
    final glass = GlassPalette.light;
    expect(
        tester.widget<Text>(find.text('저온 경고')).style!.color, glass.tempAccent);
    expect(tester.widget<Text>(find.text('건조 주의')).style!.color,
        glass.humidAccent);
  });

  final tempHigh =
      _alert('th', 'env_temp_high', 'caution', '[고온 주의] 적정 온도보다 +5.2℃');
  final vent = _alert('v', 'env_vent_delay', 'caution', '[환기 지연] 분무 후 건기 미도달');
  final mistGap = _alert('g', 'env_mist_gap', 'caution', '[건조 주의] 분무 필요');

  testWidgets('A26 — 사이클 줄: 습도 칩, 고정 설명, 온도 줄 아래', (tester) async {
    await pump(tester, EnvAlert.openLatestPerSlot([vent, tempHigh]));
    final glass = GlassPalette.light;
    expect(tester.widget<Text>(find.text('환기 지연')).style!.color,
        glass.humidAccent);
    expect(find.text(keepAllWords('분무 후 건기 미도달')), findsOneWidget);
    expect(
        find.text(
            keepAllWords('분무 후 6시간이 지났지만 사육장이 충분히 마르지 않았습니다. 환기를 점검해 주세요')),
        findsOneWidget);
    expect(tester.getRect(find.byKey(EnvAlertCard.rowKey(tempHigh))).top,
        lessThan(tester.getRect(find.byKey(EnvAlertCard.rowKey(vent))).top));
    // 높이 158(Figma)은 실제 글꼴이 필요해 mini13 캡처로 대조한다 — 테스트
    // 글꼴은 글자마다 정사각형이라 설명이 더 많이 줄바꿈된다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('건조 + 분무 공백 + 온도 = 세 줄, 온도 → 습도 → 사이클', (tester) async {
    await pump(
        tester, EnvAlert.openLatestPerSlot([mistGap, humidCaution, tempHigh]));
    final tops = [
      for (final a in [tempHigh, humidCaution, mistGap])
        tester.getRect(find.byKey(EnvAlertCard.rowKey(a))).top
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
    expect(find.text('건조 주의'), findsNWidgets(2));
    expect(find.text(keepAllWords('마지막 분무 후 15시간이 지났지만 다음 분무가 감지되지 않았습니다')),
        findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('한 줄이면 구분선 없음, Figma 높이 69', (tester) async {
    await pump(tester, [humidCaution]);
    expect(find.byType(Divider), findsNothing);
    expect(tester.getSize(find.byKey(EnvAlertCard.cardKey)).height,
        moreOrLessEquals(69, epsilon: 1));
  });
}
