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

  final humidCaution = _alert(
      'h', 'env_humid_low', 'caution', '[건조 주의] 적정 습도보다 -5%p');
  final tempDanger = _alert('t', 'env_temp_low', 'danger',
      '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요');

  testWidgets('열린 행 0개면 카드 없음', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(EnvAlertCard.cardKey), findsNothing);
  });

  testWidgets('경고가 주의보다 위 — 칩·제목은 message 그대로, 설명은 고정 문구',
      (tester) async {
    await pump(
        tester, EnvAlert.openLatestPerMetric([humidCaution, tempDanger]));
    final dangerRow = tester.getRect(find.byKey(EnvAlertCard.rowKey(tempDanger)));
    final cautionRow =
        tester.getRect(find.byKey(EnvAlertCard.rowKey(humidCaution)));
    expect(dangerRow.top, lessThan(cautionRow.top));

    expect(find.text('저온 경고'), findsOneWidget);
    expect(find.text(keepAllWords('온도가 너무 낮아 개체가 위험할 수 있어요')),
        findsOneWidget);
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
    expect(tester.widget<Text>(find.text('저온 경고')).style!.color,
        glass.tempAccent);
    expect(tester.widget<Text>(find.text('건조 주의')).style!.color,
        glass.humidAccent);
  });

  testWidgets('한 줄이면 구분선 없음, Figma 높이 69', (tester) async {
    await pump(tester, [humidCaution]);
    expect(find.byType(Divider), findsNothing);
    expect(tester.getSize(find.byKey(EnvAlertCard.cardKey)).height,
        moreOrLessEquals(69, epsilon: 1));
  });
}
