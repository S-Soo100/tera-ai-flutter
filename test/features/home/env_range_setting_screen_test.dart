// v4 적정 온도·습도 설정 화면 + 스테퍼(계획 Task 5, Figma S08·S10·S11·S13·S27).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/home/presentation/env_range_setting_screen.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/presentation/device_settings_providers.dart';
import 'package:vivanaut/shared/widgets/viva_stepper.dart';

import '../notification/notification_test_host.dart';

/// PATCH 호출을 기록하고 서버처럼 보낸 값을 저장해 되돌려 준다.
class _FakeRepo implements DeviceSettingsRepository {
  _FakeRepo(this.current, {this.fail = false});

  DeviceSettings current;
  bool fail;
  int gets = 0;
  final List<Map<String, double?>> patches = [];

  @override
  Future<DeviceSettings> get(String deviceId) async {
    gets++;
    return current;
  }

  @override
  Future<DeviceSettings> patch(String deviceId,
      {double? targetTempC,
      double? targetHumidityPct,
      double? targetTempMin,
      double? targetTempMax,
      double? targetHumidMin,
      double? targetHumidMax,
      bool? autoVentEnabled,
      bool? autoMistEnabled}) async {
    patches.add({
      if (targetTempC != null) 'tempC': targetTempC,
      if (targetHumidityPct != null) 'humidPct': targetHumidityPct,
      if (targetTempMin != null) 'tempMin': targetTempMin,
      if (targetTempMax != null) 'tempMax': targetTempMax,
      if (targetHumidMin != null) 'humidMin': targetHumidMin,
      if (targetHumidMax != null) 'humidMax': targetHumidMax,
    });
    if (fail) throw Exception('boom');
    current = DeviceSettings(
      deviceId: deviceId,
      targetTempMin: targetTempMin ?? current.targetTempMin,
      targetTempMax: targetTempMax ?? current.targetTempMax,
      targetHumidMin: targetHumidMin ?? current.targetHumidMin,
      targetHumidMax: targetHumidMax ?? current.targetHumidMax,
    );
    return current;
  }
}

/// 부모 자리(온습도 설정 화면 대역) — 기기 설정을 구독해 저장 후 다시 읽히는지 본다.
class _Parent extends ConsumerWidget {
  const _Parent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceSettingsProvider('d1')).valueOrNull;
    return Scaffold(
        body: Text(
            s == null
                ? 'parent'
                : 'parent ${s.tempRange.min}~${s.tempRange.max}',
            key: const Key('parent')));
  }
}

Finder _stepperButton(Key stepper, Key button) =>
    find.descendant(of: find.byKey(stepper), matching: find.byKey(button));

String _stepperValue(WidgetTester tester, Key stepper) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(stepper), matching: find.byKey(VivaStepper.valueKey)))
    .data!;

bool _enabled(WidgetTester tester, Finder button) =>
    tester
        .widget<FilledButton>(
            find.descendant(of: button, matching: find.byType(FilledButton)))
        .onPressed !=
    null;

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<GoRouter> pump(WidgetTester tester, _FakeRepo repo,
      {EnvRangeKind kind = EnvRangeKind.temp}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/parent', routes: [
      GoRoute(path: '/parent', builder: (_, __) => const _Parent()),
      buildTempHumidSettingRoute(),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [deviceSettingsRepositoryProvider.overrideWithValue(repo)],
      child: localizedNotificationHost((context) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          )),
    ));
    await tester.pumpAndSettle();
    router.push(tempHumidRangePath('d1', kind));
    await tester.pumpAndSettle();
    return router;
  }

  test('경로 헬퍼', () {
    expect(tempHumidSettingPath('d1'), '/temp-humid-settings/d1');
    expect(tempHumidRangePath('d1', EnvRangeKind.temp),
        '/temp-humid-settings/d1/temp');
    expect(tempHumidRangePath('d1', EnvRangeKind.humid),
        '/temp-humid-settings/d1/humid');
  });

  testWidgets('설정 없음 → 저장값 18℃ ~ 27℃, 스테퍼 18·27, 취소 버튼 없음', (tester) async {
    await pump(tester, _FakeRepo(const DeviceSettings(deviceId: 'd1')));
    expect(find.text('적정 온도 설정'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(EnvRangeSettingScreen.savedValueKey))
            .data,
        '18℃ ~ 27℃');
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '18');
    expect(_stepperValue(tester, EnvRangeSettingScreen.maxStepperKey), '27');
    expect(find.byKey(EnvRangeSettingScreen.discardKey), findsNothing);
    expect(find.text('적정 온도 가이드'), findsOneWidget);
    // 하단 고정 저장 버튼 — Figma CTA (12,695) 369×56(안전영역 0이면 아래 101).
    expect(tester.getRect(find.byKey(EnvRangeSettingScreen.saveKey)),
        const Rect.fromLTWH(12, 695, 369, 56));
  });

  testWidgets('(1) 최대 29에서 + 비활성', (tester) async {
    await pump(
        tester,
        _FakeRepo(const DeviceSettings(
            deviceId: 'd1', targetTempMin: 18, targetTempMax: 28.5)));
    final plus = _stepperButton(
        EnvRangeSettingScreen.maxStepperKey, VivaStepper.increaseKey);
    expect(_enabled(tester, plus), isTrue);
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(_stepperValue(tester, EnvRangeSettingScreen.maxStepperKey), '29');
    expect(_enabled(tester, plus), isFalse);
  });

  testWidgets('최소 +는 최대 바로 아래에서 멈춘다(MIN < MAX)', (tester) async {
    await pump(
        tester,
        _FakeRepo(const DeviceSettings(
            deviceId: 'd1', targetTempMin: 25, targetTempMax: 26)));
    final minPlus = _stepperButton(
        EnvRangeSettingScreen.minStepperKey, VivaStepper.increaseKey);
    final maxMinus = _stepperButton(
        EnvRangeSettingScreen.maxStepperKey, VivaStepper.decreaseKey);
    await tester.tap(minPlus);
    await tester.pumpAndSettle();
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '25.5');
    expect(_enabled(tester, minPlus), isFalse);
    expect(_enabled(tester, maxMinus), isFalse);
  });

  testWidgets('(2) 최소 17.5 → 변경 사항 취소 등장, 누르면 18 복귀', (tester) async {
    await pump(tester, _FakeRepo(const DeviceSettings(deviceId: 'd1')));
    await tester.tap(_stepperButton(
        EnvRangeSettingScreen.minStepperKey, VivaStepper.decreaseKey));
    await tester.pumpAndSettle();
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '17.5');
    // 헤더는 저장값 그대로(S10).
    expect(
        tester
            .widget<Text>(find.byKey(EnvRangeSettingScreen.savedValueKey))
            .data,
        '18℃ ~ 27℃');
    expect(find.text('변경 사항 취소'), findsOneWidget);
    await tester.tap(find.byKey(EnvRangeSettingScreen.discardKey));
    await tester.pumpAndSettle();
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '18');
    expect(find.byKey(EnvRangeSettingScreen.discardKey), findsNothing);
  });

  testWidgets('(3) 저장 → patch(17.5, 27) 1회 + 설정 다시 읽기 + 뒤로', (tester) async {
    final repo = _FakeRepo(const DeviceSettings(deviceId: 'd1'));
    await pump(tester, repo);
    final getsBefore = repo.gets;
    await tester.tap(_stepperButton(
        EnvRangeSettingScreen.minStepperKey, VivaStepper.decreaseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EnvRangeSettingScreen.saveKey));
    await tester.pumpAndSettle();
    expect(repo.patches, [
      {'tempMin': 17.5, 'tempMax': 27.0}
    ]);
    expect(repo.gets, greaterThan(getsBefore), reason: 'invalidate로 다시 읽음');
    expect(find.byType(EnvRangeSettingScreen), findsNothing);
    expect(find.text('parent 17.5~27.0'), findsOneWidget);
  });

  testWidgets('저장 실패 → 값 유지 + 안내, 화면 그대로', (tester) async {
    final repo = _FakeRepo(const DeviceSettings(deviceId: 'd1'), fail: true);
    await pump(tester, repo);
    await tester.tap(_stepperButton(
        EnvRangeSettingScreen.minStepperKey, VivaStepper.decreaseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EnvRangeSettingScreen.saveKey));
    await tester.pumpAndSettle();
    expect(repo.patches, hasLength(1));
    expect(find.byType(EnvRangeSettingScreen), findsOneWidget);
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '17.5');
    expect(find.text('저장하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    // 다시 누를 수 있다.
    expect(_enabled(tester, find.byKey(EnvRangeSettingScreen.saveKey)), isTrue);
  });

  testWidgets('(4) 습도 최소 35에서 − 비활성', (tester) async {
    await pump(
        tester,
        _FakeRepo(const DeviceSettings(
            deviceId: 'd1', targetHumidMin: 40, targetHumidMax: 80)),
        kind: EnvRangeKind.humid);
    expect(find.text('적정 습도 설정'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(EnvRangeSettingScreen.savedValueKey))
            .data,
        '40% ~ 80%');
    final minus = _stepperButton(
        EnvRangeSettingScreen.minStepperKey, VivaStepper.decreaseKey);
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '35');
    expect(_enabled(tester, minus), isFalse);
  });

  testWidgets('(5) 저장값 18.3(콘솔 입력) → 18.5로 보이고 저장 가능', (tester) async {
    final repo = _FakeRepo(const DeviceSettings(
        deviceId: 'd1', targetTempMin: 18.3, targetTempMax: 26));
    await pump(tester, repo);
    expect(_stepperValue(tester, EnvRangeSettingScreen.minStepperKey), '18.5');
    expect(
        tester
            .widget<Text>(find.byKey(EnvRangeSettingScreen.savedValueKey))
            .data,
        '18.5℃ ~ 26℃');
    expect(_enabled(tester, find.byKey(EnvRangeSettingScreen.saveKey)), isTrue);
    await tester.tap(find.byKey(EnvRangeSettingScreen.saveKey));
    await tester.pumpAndSettle();
    expect(repo.patches, [
      {'tempMin': 18.5, 'tempMax': 26.0}
    ]);
  });

  testWidgets('습도 저장은 습도 MIN/MAX만 보낸다', (tester) async {
    final repo = _FakeRepo(const DeviceSettings(deviceId: 'd1'));
    await pump(tester, repo, kind: EnvRangeKind.humid);
    await tester.tap(_stepperButton(
        EnvRangeSettingScreen.maxStepperKey, VivaStepper.increaseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EnvRangeSettingScreen.saveKey));
    await tester.pumpAndSettle();
    expect(repo.patches, [
      {'humidMin': 40.0, 'humidMax': 85.0}
    ]);
  });
}
