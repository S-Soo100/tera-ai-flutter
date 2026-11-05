// 자동 환기·자동 분무 토글(계획 2026-11-05 Task 4) — 위젯 단독 + 제어 시트 통합.
//
// 설명 문구에 내 MAX/MIN 값이 들어가는지 봐야 해서 ko.json을 실제로 읽는다
// (device_control_sheet_test.dart는 키를 그대로 비교하므로 따로 둔다 —
// 번역 싱글턴이 한 번 올라가면 같은 파일의 키 비교가 깨진다).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/glass_palette.dart';
import 'package:vivanaut/features/home/domain/auto_env.dart';
import 'package:vivanaut/features/home/presentation/auto_env_providers.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart'
    show kCommandAckGrace;
import 'package:vivanaut/features/home/domain/schedule_device.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/home/presentation/widgets/auto_env_toggle.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart'
    show runningTimersProvider;
import 'package:vivanaut/features/home/presentation/widgets/device_control_sheet.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart'
    show telemetryStreamProvider;

import 'control_sheet_fixtures.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

Widget _localized(List<Override> overrides, Widget home) => ProviderScope(
    // 한 테스트에서 다시 그릴 때 이전 트리(열린 모달)를 물려받지 않게.
    key: UniqueKey(),
    overrides: overrides,
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
                home: home))));

/// 제어 시트를 실제처럼 루트 모달로 띄운다 — [closeSheet]가 pop으로 닫는다.
///
/// [telemetry]를 명시적으로 null로 주면 "텔레메트리를 받지 못함"이다
/// (기본은 환기팬·분무 모두 꺼짐 보고).
Future<FakeDeviceSettingsRepo> pumpSheet(
  WidgetTester tester,
  ScheduleDevice device, {
  required bool released,
  DeviceSettings? settings,
  Duration patchDelay = Duration.zero,
  bool patchIgnoresField = false,
  bool settingsError = false,
  Completer<void>? settingsGate,
  Object? telemetry = const _DefaultTelemetry(),
  AutoEnvState autoEnv = AutoEnvState.none,
  Override? autoEnvOverride,
  bool online = true,
  List<(CommandAction, Map<String, dynamic>?)>? sent,
  bool settle = true,
}) async {
  final repo = FakeDeviceSettingsRepo(
      settings: settings,
      patchDelay: patchDelay,
      ignoresAutoFields: patchIgnoresField,
      getError: settingsError,
      getGate: settingsGate);
  final reading0 = switch (telemetry) {
    _DefaultTelemetry() => reading(),
    final TelemetryReading r => r,
    _ => null,
  };
  await tester.pumpWidget(_localized(
      controlOverrides(
          sent: sent ?? [],
          telemetryStream: Stream.value(reading0),
          autoEnvReleased: released,
          autoEnv: autoEnv,
          autoEnvOverride: autoEnvOverride,
          online: online,
          settingsRepo: repo),
      Scaffold(body: Consumer(builder: (context, ref, _) {
    // 실제 홈처럼 제어 타일이 텔레메트리·타이머를 먼저 구독해 둔다 — 시트는
    // 첫 프레임의 값으로 칩을 시드한다.
    ref.watch(telemetryStreamProvider(kTestDeviceId));
    ref.watch(runningTimersProvider);
    return Center(
        child: TextButton(
            onPressed: () =>
                openDeviceControlSheet(context, ref, kTestDeviceId, device),
            child: const Text('open')));
  }))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 끝나지 않는 반짝임(설정 불러오는 중) — 몇 프레임만 흘린다.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  return repo;
}

class _DefaultTelemetry {
  const _DefaultTelemetry();
}

/// 송신 뒤 ACK 감시·안내 타이머를 흘려보낸다.
Future<void> _flush(WidgetTester tester) =>
    tester.pump(kCommandAckGrace + const Duration(seconds: 5));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('AutoEnvToggle 단독', () {
    Future<List<bool>> pumpToggle(WidgetTester tester,
        {bool value = false,
        bool enabled = true,
        bool loading = false,
        bool saving = false}) async {
      final changes = <bool>[];
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutoEnvToggle(
                      key: const Key('t'),
                      label: '자동 환기',
                      description: '설명',
                      value: value,
                      enabled: enabled,
                      loading: loading,
                      saving: saving,
                      accent: Colors.green,
                      onChanged: changes.add)))));
      await tester.pump();
      return changes;
    }

    testWidgets('줄을 누르면 반대 값으로 onChanged', (tester) async {
      final changes = await pumpToggle(tester);
      await tester.tap(find.text('자동 환기'));
      expect(changes, [true]);
    });

    testWidgets('비활성 — 바탕 outline·라벨 textTertiary, 눌러도 무시', (tester) async {
      final changes = await pumpToggle(tester, enabled: false);
      await tester.tap(find.text('자동 환기'));
      expect(changes, isEmpty);
      final glass = AppTheme.light.extension<GlassPalette>()!;
      final row = tester.widget<Container>(find.byKey(AutoEnvToggle.rowKey));
      expect((row.decoration! as BoxDecoration).color, glass.outline);
      final label = tester.widget<Text>(find.text('자동 환기'));
      expect(label.style!.color, glass.textTertiary);
    });

    testWidgets('Figma 수치 — 줄 48·라벨 18/600·설명 14/500 textTertiary, 줄 아래 8',
        (tester) async {
      await pumpToggle(tester);
      final glass = AppTheme.light.extension<GlassPalette>()!;
      expect(tester.getSize(find.byKey(AutoEnvToggle.rowKey)).height, 48);
      final label = tester.widget<Text>(find.text('자동 환기')).style!;
      expect(label.fontSize, 18);
      expect(label.fontWeight, FontWeight.w600);
      expect(label.letterSpacing, closeTo(-0.36, 1e-9));
      expect(label.color, glass.textSecondary);
      final desc = tester.widget<Text>(find.text('설명')).style!;
      expect(desc.fontSize, 14);
      expect(desc.fontWeight, FontWeight.w500);
      expect(desc.letterSpacing, closeTo(-0.28, 1e-9));
      expect(desc.color, glass.textTertiary);
      final rowBottom = tester.getBottomLeft(find.byKey(AutoEnvToggle.rowKey));
      final descTop = tester.getTopLeft(find.text('설명'));
      expect(descTop.dy - rowBottom.dy, 8);
      expect(descTop.dx - rowBottom.dx, 12);
    });

    testWidgets('저장 중 — 줄 위 shimmer, 눌러도 무시', (tester) async {
      final changes = await pumpToggle(tester, saving: true);
      expect(find.byKey(AutoEnvToggle.savingKey), findsOneWidget);
      await tester.tap(find.text('자동 환기'), warnIfMissed: false);
      expect(changes, isEmpty);
    });

    testWidgets('불러오는 중 — 같은 높이의 스켈레톤, 스위치는 숨김', (tester) async {
      await pumpToggle(tester);
      final ready = tester.getSize(find.byKey(const Key('t')));
      await pumpToggle(tester, loading: true);
      expect(find.byKey(AutoEnvToggle.skeletonKey), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('t'))), ready);
      expect(find.byType(ScheduleSwitch).hitTestable(), findsNothing);
    });
  });

  group('제어 시트', () {
    testWidgets('스위치 꺼짐이면 자동 토글이 없다', (t) async {
      await pumpSheet(t, ScheduleDevice.fan, released: false);
      expect(find.byKey(DeviceControlSheet.autoVentKey), findsNothing);
      await pumpSheet(t, ScheduleDevice.mist, released: false);
      expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
    });

    testWidgets('환기 설명에 내 MAX 값', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          settings: const DeviceSettings(
              deviceId: 'd',
              targetHumidMin: 40,
              targetHumidMax: 75,
              targetTempMin: 18,
              targetTempMax: 27));
      expect(find.byKey(DeviceControlSheet.autoVentKey), findsOneWidget);
      expect(find.text('자동 환기'), findsOneWidget);
      expect(find.textContaining('75%'), findsOneWidget);
      expect(find.textContaining('27℃'), findsOneWidget);
    });

    testWidgets('분무 설명에 내 MIN 값', (t) async {
      await pumpSheet(t, ScheduleDevice.mist,
          released: true,
          settings: const DeviceSettings(
              deviceId: 'd', targetHumidMin: 45, targetHumidMax: 80));
      expect(find.text('자동 분무'), findsOneWidget);
      expect(find.text('습도가 45% 미만으로 내려가면 자동으로 1회 분무'), findsOneWidget);
    });

    testWidgets('환기 배치 — 칩 아래 24 → 1px 선 → 20 → 자동 환기 줄', (t) async {
      await pumpSheet(t, ScheduleDevice.fan, released: true);
      final chipBottom =
          t.getBottomLeft(find.byKey(const Key('fan_timer_10'))).dy;
      final divider = find.byKey(DeviceControlSheet.autoVentDividerKey);
      expect(t.getTopLeft(divider).dy - chipBottom, 24);
      expect(t.getSize(divider).height, 1);
      // 선은 내용 폭 전체(Figma Frame 319 = 345, 시트 안쪽 24 기준).
      expect(t.getSize(divider).width,
          t.getSize(find.byKey(DeviceControlSheet.powerRowKey)).width);
      final row = find.descendant(
          of: find.byKey(DeviceControlSheet.autoVentKey),
          matching: find.byKey(AutoEnvToggle.rowKey));
      expect(t.getTopLeft(row).dy - t.getBottomLeft(divider).dy, 20);
    });

    testWidgets('켜면 PATCH 한 번, 저장 중 재탭 무시', (t) async {
      final repo = await pumpSheet(t, ScheduleDevice.fan,
          released: true, patchDelay: const Duration(seconds: 1));
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
      await t.pump();
      expect(find.byKey(AutoEnvToggle.savingKey), findsOneWidget);
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey),
          warnIfMissed: false);
      await t.pump(const Duration(seconds: 2));
      expect(repo.patches, [
        {'auto_vent_enabled': true}
      ]);
      expect(find.byKey(AutoEnvToggle.savingKey), findsNothing);
      // 서버 응답 값(true)을 그린다.
      expect(switchValue(t, DeviceControlSheet.autoVentKey), isTrue);
    });

    testWidgets('자동 저장 중에도 수동 제어는 된다(_busy와 분리)', (t) async {
      final sent = <(CommandAction, Map<String, dynamic>?)>[];
      await pumpSheet(t, ScheduleDevice.fan,
          released: true, patchDelay: const Duration(seconds: 1), sent: sent);
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
      await t.pump();
      await t.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
      await t.pump();
      expect(sent.single.$1, CommandAction.fanOn);
      await _flush(t);
    });

    testWidgets('분무 켜기는 auto_mist_enabled만 보낸다', (t) async {
      final repo = await pumpSheet(t, ScheduleDevice.mist, released: true);
      await t.tap(find.byKey(DeviceControlSheet.autoMistKey));
      await t.pumpAndSettle();
      expect(repo.patches, [
        {'auto_mist_enabled': true}
      ]);
      expect(switchValue(t, DeviceControlSheet.autoMistKey), isTrue);
    });

    testWidgets('서버가 값을 무시하면 꺼짐 유지 + 안내', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true, patchIgnoresField: true);
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
      await t.pumpAndSettle();
      expect(find.text('자동 설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
      expect(switchValue(t, DeviceControlSheet.autoVentKey), isFalse);
      await _flush(t);
    });

    testWidgets('저장 중 시트를 닫아도 예외 없음', (t) async {
      final repo = await pumpSheet(t, ScheduleDevice.fan,
          released: true, patchDelay: const Duration(seconds: 1));
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
      await t.pump();
      await closeSheet(t);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(DeviceControlSheet.autoVentKey), findsNothing);
      expect(repo.patches, hasLength(1));
    });

    testWidgets('설정 로드 실패 — 비활성 + 실패 문구', (t) async {
      final repo = await pumpSheet(t, ScheduleDevice.mist,
          released: true, settingsError: true);
      expect(find.text('자동 설정을 불러오지 못했어요. 눌러서 다시 시도해 주세요'),
          findsOneWidget);
      expect(find.textContaining('미만으로 내려가면'), findsNothing);
      await t.tap(find.byKey(DeviceControlSheet.autoMistKey));
      await t.pumpAndSettle();
      expect(repo.patches, isEmpty);
    });

    testWidgets('설정 불러오는 중 — 스켈레톤', (t) async {
      final gate = Completer<void>();
      await pumpSheet(t, ScheduleDevice.fan,
          released: true, settingsGate: gate, settle: false);
      expect(
          find.descendant(
              of: find.byKey(DeviceControlSheet.autoVentKey),
              matching: find.byKey(AutoEnvToggle.skeletonKey)),
          findsOneWidget);
      gate.complete();
      await t.pumpAndSettle();
      expect(find.byKey(AutoEnvToggle.skeletonKey), findsNothing);
    });

    testWidgets('텔레메트리 없음 또는 relay 미보고 기기에는 자동 분무가 없다', (t) async {
      await pumpSheet(t, ScheduleDevice.mist, released: true, telemetry: null);
      expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
      await pumpSheet(t, ScheduleDevice.mist,
          released: true, telemetry: reading(relay: ActuatorState.unavailable));
      expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
    });

    testWidgets('fan 미보고 기기에는 자동 환기가 없다', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true, telemetry: reading(fan: ActuatorState.unavailable));
      expect(find.byKey(DeviceControlSheet.autoVentKey), findsNothing);
    });

    testWidgets('냉각팬·LED 시트에는 자동 토글이 없다', (t) async {
      for (final device in [ScheduleDevice.cool, ScheduleDevice.led]) {
        await pumpSheet(t, device,
            released: true,
            telemetry:
                reading(fan2: ActuatorState.off, led: ActuatorState.off));
        expect(find.byKey(DeviceControlSheet.autoVentKey), findsNothing);
        expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
      }
    });

    testWidgets('분무 시트 순서 — 탭 아래 24 → 자동 분무 → 24 → 칩', (t) async {
      await pumpSheet(t, ScheduleDevice.mist, released: true);
      final auto = t.getTopLeft(find.byKey(DeviceControlSheet.autoMistKey)).dy;
      final chip = t
          .getTopLeft(find
              .byKey(DeviceControlSheet.mistChipKey(MistDuration.values.first)))
          .dy;
      expect(auto, lessThan(chip));
      final segmentBottom =
          t.getBottomLeft(find.byKey(DeviceControlSheet.segmentKey)).dy;
      expect(auto - segmentBottom, 24);
      final autoBottom =
          t.getBottomLeft(find.byKey(DeviceControlSheet.autoMistKey)).dy;
      expect(t.getTopLeft(find.text('분사 시간')).dy - autoBottom, 24);
    });

    // ── 코드 리뷰 반영(2026-11-05) ──────────────────────────────────────

    testWidgets('리뷰1 — 저장 중에도 줄은 활성 모양(회색으로 바뀌지 않는다)', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true, patchDelay: const Duration(seconds: 1));
      await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
      await t.pump();
      expect(find.byKey(AutoEnvToggle.savingKey), findsOneWidget);
      final row = t.widget<Container>(find.descendant(
          of: find.byKey(DeviceControlSheet.autoVentKey),
          matching: find.byKey(AutoEnvToggle.rowKey)));
      expect((row.decoration! as BoxDecoration).color,
          GlassPalette.light.surfaceHeader);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('리뷰2 — 기기가 오프라인이어도 자동 설정은 저장된다(서버 설정)', (t) async {
      final repo =
          await pumpSheet(t, ScheduleDevice.mist, released: true, online: false);
      await t.tap(find.byKey(DeviceControlSheet.autoMistKey));
      await t.pumpAndSettle();
      expect(repo.patches, [
        {'auto_mist_enabled': true}
      ]);
      expect(switchValue(t, DeviceControlSheet.autoMistKey), isTrue);
    });

    testWidgets('리뷰3 — 시트를 연 뒤 자동 환기가 시작되면 칩 선택을 비운다', (t) async {
      final autoEnv = StateProvider<AutoEnvState>((_) => AutoEnvState.none);
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          telemetry: reading(fan: ActuatorState.on),
          autoEnvOverride: autoEnvStateProvider
              .overrideWith((ref, id) => ref.watch(autoEnv)));
      expect(chipSelected(t, const Key('fan_steady_on')), isTrue);
      ProviderScope.containerOf(t.element(find.text('open')))
          .read(autoEnv.notifier)
          .state = const AutoEnvState(ventActive: true);
      await t.pumpAndSettle();
      expect(chipSelected(t, const Key('fan_steady_on')), isFalse);
    });

    testWidgets('리뷰5 — 불러오기 실패 줄을 누르면 다시 불러온다', (t) async {
      final repo = await pumpSheet(t, ScheduleDevice.mist,
          released: true, settingsError: true);
      repo.getError = false;
      await t.tap(find.byKey(DeviceControlSheet.autoMistKey));
      await t.pumpAndSettle();
      expect(find.textContaining('미만으로 내려가면'), findsOneWidget);
      expect(repo.patches, isEmpty);
      await t.tap(find.byKey(DeviceControlSheet.autoMistKey));
      await t.pumpAndSettle();
      expect(repo.patches, [
        {'auto_mist_enabled': true}
      ]);
    });

    testWidgets('자동이 켠 팬은 작동 시간 칩이 선택되지 않는다(D5)', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          telemetry: reading(fan: ActuatorState.on),
          autoEnv: const AutoEnvState(ventActive: true));
      expect(chipSelected(t, const Key('fan_steady_on')), isFalse);
      for (final m in [10, 30, 60, 120]) {
        expect(chipSelected(t, Key('fan_timer_$m')), isFalse);
      }
    });

    testWidgets('D5 — 자동이 아닌 켜진 팬은 기존대로 "계속"', (t) async {
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          telemetry: reading(fan: ActuatorState.on),
          autoEnv: AutoEnvState.none);
      expect(chipSelected(t, const Key('fan_steady_on')), isTrue);
    });

    testWidgets('D5 — 선택 없음에서 "계속"을 누르면 계속으로 다시 켠다', (t) async {
      final sent = <(CommandAction, Map<String, dynamic>?)>[];
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          telemetry: reading(fan: ActuatorState.on),
          autoEnv: const AutoEnvState(ventActive: true),
          sent: sent);
      await t.tap(find.byKey(const Key('fan_steady_on')));
      await t.pump();
      expect(sent.single.$1, CommandAction.fanOn);
      expect(sent.single.$2, isNull);
      expect(chipSelected(t, const Key('fan_steady_on')), isTrue);
      await _flush(t);
    });

    testWidgets('D5 — 자동이 켠 팬이 꺼진 뒤 스위치로 켜면 저장값 칩으로 켠다', (t) async {
      final sent = <(CommandAction, Map<String, dynamic>?)>[];
      final telemetry = StreamController<TelemetryReading?>.broadcast();
      addTearDown(telemetry.close);
      await t.pumpWidget(_localized(
          controlOverrides(
              sent: sent,
              telemetryStream: telemetry.stream,
              autoEnvReleased: true,
              autoEnv: const AutoEnvState(ventActive: true)),
          Scaffold(body: Consumer(builder: (context, ref, _) {
        ref.watch(telemetryStreamProvider(kTestDeviceId));
        ref.watch(runningTimersProvider);
        return Center(
            child: TextButton(
                onPressed: () => openDeviceControlSheet(
                    context, ref, kTestDeviceId, ScheduleDevice.fan),
                child: const Text('open')));
      }))));
      telemetry.add(reading(fan: ActuatorState.on));
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(chipSelected(t, const Key('fan_steady_on')), isFalse);
      // 원인이 풀려 서버가 껐다.
      telemetry.add(reading(fan: ActuatorState.off));
      await t.pumpAndSettle();
      await t.tap(find.byKey(DeviceControlSheet.powerSwitchKey));
      await t.pump();
      expect(sent.single.$1, CommandAction.fanOn);
      // 보낸 값과 선택돼 보이는 칩이 같다 — 고르지 않은 "계속"으로 켜지 않는다.
      final ms = sent.single.$2?['duration_ms'];
      final selected = [
        for (final m in [10, 30, 60, 120])
          if (chipSelected(t, Key('fan_timer_$m'))) m * 60000,
        if (chipSelected(t, const Key('fan_steady_on'))) null,
      ];
      expect(selected, [ms]);
      await _flush(t);
    });

    testWidgets('D5 — 선택 없음에서 30분을 누르면 30분 타이머로 다시 켠다', (t) async {
      final sent = <(CommandAction, Map<String, dynamic>?)>[];
      await pumpSheet(t, ScheduleDevice.fan,
          released: true,
          telemetry: reading(fan: ActuatorState.on),
          autoEnv: const AutoEnvState(ventActive: true),
          sent: sent);
      await t.tap(find.byKey(const Key('fan_timer_30')));
      await t.pump();
      expect(sent.single.$1, CommandAction.fanOn);
      expect(sent.single.$2, {'duration_ms': 1800000});
      expect(chipSelected(t, const Key('fan_timer_30')), isTrue);
      await _flush(t);
    });
  });
}
