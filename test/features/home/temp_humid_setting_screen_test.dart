// v4 온습도 설정 화면(계획 Task 3, Figma S04·S05·S06).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_alert_prefs_repository.dart';
import 'package:vivanaut/features/home/presentation/env_range_setting_screen.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/home/presentation/temp_humid_setting_screen.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';

import '../notification/notification_test_host.dart';

class _SettingsRepo implements DeviceSettingsRepository {
  _SettingsRepo(this.current);
  final DeviceSettings current;

  @override
  Future<DeviceSettings> get(String deviceId) async => current;

  @override
  Future<DeviceSettings> patch(String deviceId,
          {double? targetTempC,
          double? targetHumidityPct,
          double? targetTempMin,
          double? targetTempMax,
          double? targetHumidMin,
          double? targetHumidMax,
          bool? autoVentEnabled,
          bool? autoMistEnabled}) async =>
      current;
}

class _PrefsRepo implements EnvAlertPrefsRepository {
  _PrefsRepo({this.failWrites = false});
  final bool failWrites;
  final List<String> writes = [];

  @override
  String get userId => 'u1';

  @override
  Future<EnvAlertPrefs> load() async => EnvAlertPrefs.allOn;

  @override
  Future<void> setTemp(bool on) async {
    writes.add('temp:$on');
    if (failWrites) throw Exception('boom');
  }

  @override
  Future<void> setHumid(bool on) async {
    writes.add('humid:$on');
    if (failWrites) throw Exception('boom');
  }
}

User _user() => User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01');

Device _device({double? offset, String? name = '거실 사육장'}) => Device(
    id: 'd1',
    ownerId: 'u1',
    enclosureId: null,
    name: name,
    isOnline: true,
    lastSeenAt: null,
    tempOffsetC: offset);

bool _switchValue(WidgetTester tester, Key key) =>
    tester.widget<ScheduleSwitch>(find.byKey(key)).value;

void main() {
  setUpAll(initializeNotificationLocalization);

  Future<GoRouter> pump(
    WidgetTester tester, {
    List<Device>? devices,
    DeviceSettings settings = const DeviceSettings(deviceId: 'd1'),
    _PrefsRepo? prefs,
  }) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/root', routes: [
      GoRoute(path: '/root', builder: (_, __) => const Scaffold()),
      buildTempHumidSettingRoute(),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        deviceListProvider
            .overrideWith((ref) async => devices ?? [_device(offset: -1.5)]),
        deviceOffsetProvider('d1').overrideWith((ref) => Stream.value(
            (devices ?? [_device(offset: -1.5)])
                .where((d) => d.id == 'd1')
                .firstOrNull
                ?.tempOffsetC)),
        deviceSettingsRepositoryProvider
            .overrideWithValue(_SettingsRepo(settings)),
        moduleLinkProvider('d1').overrideWithValue(ModuleLink.online),
        currentUserProvider.overrideWith((ref) => _user()),
        envAlertPrefsRepositoryProvider
            .overrideWith((ref, id) => prefs ?? _PrefsRepo()),
      ],
      child: localizedNotificationHost((context) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          )),
    ));
    await tester.pumpAndSettle();
    router.push(tempHumidSettingPath('d1'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('(1) 설정 없음 → 18℃ ~ 27℃, 40% ~ 80%와 각주', (tester) async {
    await pump(tester);
    expect(find.text('온습도 설정'), findsOneWidget);
    expect(find.text('18℃ ~ 27℃'), findsOneWidget);
    expect(find.text('40% ~ 80%'), findsOneWidget);
    expect(find.text('18℃ 미만이거나 27℃ 초과인 경우 이탈 안내를 합니다'), findsOneWidget);
    expect(find.text('40% 미만이거나 80% 초과인 경우 이탈 안내를 합니다'), findsOneWidget);
    expect(_switchValue(tester, TempHumidSettingScreen.tempAlertToggleKey),
        isTrue);
    expect(_switchValue(tester, TempHumidSettingScreen.humidAlertToggleKey),
        isTrue);
  });

  testWidgets('저장된 적정 범위를 그대로 보인다', (tester) async {
    await pump(tester,
        settings: const DeviceSettings(
            deviceId: 'd1',
            targetTempMin: 17.5,
            targetTempMax: 29,
            targetHumidMin: 35,
            targetHumidMax: 85));
    expect(find.text('17.5℃ ~ 29℃'), findsOneWidget);
    expect(find.text('35% ~ 85%'), findsOneWidget);
  });

  String? offsetText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(TempHumidSettingScreen.offsetValueKey))
      .data;

  testWidgets('(2) 공장 보정 −1.5만 → 꺼짐, 보정 값 행 없음(S04)', (tester) async {
    await pump(tester, devices: [_device(offset: -1.5)]);
    expect(
        _switchValue(tester, TempHumidSettingScreen.offsetToggleKey), isFalse);
    expect(find.byKey(TempHumidSettingScreen.offsetValueKey), findsNothing);
    expect(find.text('보정 값'), findsNothing);
  });

  testWidgets('(2) 기기 −0.5 → 켜짐 + "측정값 +1℃"(S35)', (tester) async {
    await pump(tester, devices: [_device(offset: -0.5)]);
    expect(
        _switchValue(tester, TempHumidSettingScreen.offsetToggleKey), isTrue);
    expect(offsetText(tester), '측정값 +1℃');
    expect(
        find.byKey(TempHumidSettingScreen.offsetUnsupportedKey), findsNothing);
  });

  testWidgets('(2) 기기 −3.5 → 켜짐 + "측정값 -2℃"(S06)', (tester) async {
    await pump(tester, devices: [_device(offset: -3.5)]);
    expect(offsetText(tester), '측정값 -2℃');
  });

  testWidgets('기기 0(옛 "끔 = 0" 기기) → 켜짐 + "측정값 +1.5℃"', (tester) async {
    await pump(tester, devices: [_device(offset: 0)]);
    expect(offsetText(tester), '측정값 +1.5℃');
  });

  testWidgets('구 펌웨어(보정값 모름) → 꺼짐·비활성 + 펌웨어 안내', (tester) async {
    await pump(tester, devices: [_device(offset: null)]);
    expect(
        _switchValue(tester, TempHumidSettingScreen.offsetToggleKey), isFalse);
    expect(find.text('펌웨어 업데이트 후 사용할 수 있어요'), findsOneWidget);
    expect(find.byKey(TempHumidSettingScreen.offsetValueKey), findsNothing);
  });

  testWidgets('(3) 사육장 이름을 보인다', (tester) async {
    await pump(tester);
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(TempHumidSettingScreen.deviceNameKey),
                matching: find.byType(Text)))
            .data,
        '거실 사육장');
  });

  testWidgets('내 목록에 없는 기기면 이유를 보인다', (tester) async {
    await pump(tester, devices: [
      Device(
          id: 'other',
          ownerId: 'u1',
          enclosureId: null,
          name: '다른 사육장',
          isOnline: true,
          lastSeenAt: null)
    ]);
    expect(find.byKey(TempHumidSettingScreen.missingKey), findsOneWidget);
    expect(find.byKey(TempHumidSettingScreen.tempRangeRowKey), findsNothing);
  });

  testWidgets('(4) 적정 온도 행 → 적정 온도 설정 push', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.byKey(TempHumidSettingScreen.tempRangeRowKey));
    await tester.pumpAndSettle();
    expect(
        GoRouterState.of(tester.element(find.byType(EnvRangeSettingScreen)))
            .uri
            .path,
        tempHumidRangePath('d1', EnvRangeKind.temp));
    final screen = tester
        .widget<EnvRangeSettingScreen>(find.byType(EnvRangeSettingScreen));
    expect((screen.deviceId, screen.kind), ('d1', EnvRangeKind.temp));
    // 뒤로 가면 온습도 설정으로.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TempHumidSettingScreen), findsOneWidget);
  });

  testWidgets('적정 습도 행 → 적정 습도 설정 push', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(TempHumidSettingScreen.humidRangeRowKey));
    await tester.pumpAndSettle();
    expect(
        GoRouterState.of(tester.element(find.byType(EnvRangeSettingScreen)))
            .uri
            .path,
        tempHumidRangePath('d1', EnvRangeKind.humid));
  });

  testWidgets('이탈 알림 토글 → 바로 저장', (tester) async {
    final prefs = _PrefsRepo();
    await pump(tester, prefs: prefs);
    await tester.tap(find.byKey(TempHumidSettingScreen.tempAlertToggleKey));
    await tester.pumpAndSettle();
    expect(prefs.writes, ['temp:false']);
    expect(_switchValue(tester, TempHumidSettingScreen.tempAlertToggleKey),
        isFalse);
  });

  testWidgets('(5) toggle_failure_reverts — 습도 끔 실패 → 켜짐 복귀 + 안내',
      (tester) async {
    final prefs = _PrefsRepo(failWrites: true);
    await pump(tester, prefs: prefs);
    await tester.tap(find.byKey(TempHumidSettingScreen.humidAlertToggleKey));
    await tester.pumpAndSettle();
    expect(prefs.writes, ['humid:false']);
    expect(_switchValue(tester, TempHumidSettingScreen.humidAlertToggleKey),
        isTrue);
    expect(find.text('알림 설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    // 다른 토글은 그대로.
    expect(_switchValue(tester, TempHumidSettingScreen.tempAlertToggleKey),
        isTrue);
  });
}
