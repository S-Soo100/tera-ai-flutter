// v4 온습도 상세 범위 바(계획 Task 6, Figma A04·A06).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_range_bar.dart';
import 'package:vivanaut/shared/domain/env_thresholds.dart';

import '../notification/notification_test_host.dart';

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<void> pump(WidgetTester tester, EnvRangeBar bar) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(localizedNotificationHost((context) => MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(child: bar),
            ),
          ),
        )));
    await tester.pumpAndSettle();
  }

  Rect track(WidgetTester tester) =>
      tester.getRect(find.byKey(EnvRangeBar.trackKey));
  Rect marker(WidgetTester tester) =>
      tester.getRect(find.byKey(EnvRangeBar.markerKey));

  testWidgets('out_of_range_value_clamps_marker — 온도 35 → 원은 바 오른쪽 끝, 숫자는 실제 값',
      (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 35,
            low: 20,
            high: 35,
            range: EnvRange.tempDefault));
    expect(marker(tester).right, moreOrLessEquals(track(tester).right));
    expect(find.text('35.0℃'), findsOneWidget);
  });

  testWidgets('온도 10 → 원은 바 왼쪽 끝', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 10,
            low: 10,
            high: 20,
            range: EnvRange.tempDefault));
    expect(marker(tester).left, moreOrLessEquals(track(tester).left));
    expect(find.text('10.0℃'), findsOneWidget);
  });

  testWidgets('습도 15% → 원은 바 왼쪽 끝(전체 바 20~100)', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.humid,
            value: 15,
            low: 15,
            high: 60,
            range: EnvRange.humidDefault));
    expect(marker(tester).left, moreOrLessEquals(track(tester).left));
    expect(find.text('15.0%'), findsOneWidget);
  });

  testWidgets('바 안의 값은 같은 비율 자리에 원', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 21, // (21-12)/18 = 0.5
            low: 15,
            high: 26,
            range: EnvRange.tempDefault));
    final t = track(tester);
    final m = marker(tester);
    expect(m.width, 12);
    expect(m.left - t.left, moreOrLessEquals((t.width - 12) * 0.5));
  });

  testWidgets('적정 MAX와 같은 값이면 원 중심이 그 눈금 위에 있다', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 27,
            low: 20,
            high: 28,
            range: EnvRange.tempDefault));
    final t = track(tester);
    final expected = t.left + EnvBarKind.temp.fractionOf(27) * t.width;
    expect(marker(tester).center.dx, moreOrLessEquals(expected));
    expect(tester.getCenter(find.text('27')).dx, moreOrLessEquals(expected));
  });

  testWidgets('최저 15.9 → "15" (버림), 최고 26.99 → "26"', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 22,
            low: 15.9,
            high: 26.99,
            range: EnvRange.tempDefault));
    expect(
        tester
            .widget<Text>(find.byKey(const Key('env_range_bar_low_temp')))
            .data,
        '15');
    expect(
        tester
            .widget<Text>(find.byKey(const Key('env_range_bar_high_temp')))
            .data,
        '26');
    // 현재값은 소수 0이어도 한 자리.
    expect(find.text('22.0℃'), findsOneWidget);
  });

  testWidgets('적정 구간은 전체 바에서 같은 비율 자리 — 18~24는 1/3~2/3, 눈금 formatCompact',
      (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.temp,
            value: 22,
            low: 15,
            high: 26,
            range: EnvRange(18.5, 24)));
    final t = track(tester);
    final band = tester.getRect(find.byKey(EnvRangeBar.bandKey));
    expect(band.left - t.left, moreOrLessEquals(t.width * 6.5 / 18));
    expect(band.right - t.left, moreOrLessEquals(t.width * 12 / 18));
    expect(find.text('18.5'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('값·범위가 없으면 원·구간 없이 "--"', (tester) async {
    await pump(
        tester,
        const EnvRangeBar(
            kind: EnvBarKind.humid,
            value: null,
            low: null,
            high: null,
            range: null));
    expect(find.byKey(EnvRangeBar.markerKey), findsNothing);
    expect(find.byKey(EnvRangeBar.bandKey), findsNothing);
    expect(find.text('--'), findsNWidgets(3));
  });
}
