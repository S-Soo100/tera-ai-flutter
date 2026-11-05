// 홈 제어 시트 테스트 공용 fixture — 명령 송신·알림·Supabase 클라이언트를
// 가짜로 바꿔 실기기·서버 없이 시트 동작을 검증한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/config/feature_flags.dart';
import 'package:vivanaut/core/supabase/supabase_provider.dart';
import 'package:vivanaut/features/home/domain/auto_env.dart';
import 'package:vivanaut/features/home/presentation/auto_env_providers.dart';
import 'package:vivanaut/features/home/presentation/control_pending.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/home/presentation/widgets/schedule_editor_sheet.dart'
    show ScheduleChoiceChip;
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/shared/services/fan_timer_notification_service.dart';
import 'schedule_fixtures.dart';

const kTestDeviceId = 'd1';

TelemetryReading reading({
  ActuatorState fan = ActuatorState.off,
  ActuatorState fan2 = ActuatorState.unavailable,
  ActuatorState led = ActuatorState.unavailable,
  ActuatorState heaterState = ActuatorState.off,
  ActuatorState relay = ActuatorState.off,
  int? ledBrightness,
}) =>
    TelemetryReading(
      deviceId: kTestDeviceId,
      tA: 28,
      hA: 60,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: relay,
      fan: fan,
      fan2: fan2,
      heaterState: heaterState,
      heaterLocked: false,
      ts: DateTime(2026, 9, 2, 12),
      led: led,
      ledBrightness: ledBrightness,
    );

class FakeSender extends ModuleCommandSender {
  FakeSender(this.log);
  final List<(CommandAction, Map<String, dynamic>?)> log;
  @override
  Future<DeviceCommand> send(String deviceId, CommandAction action,
      {Map<String, dynamic>? payload, int? ttlSec}) async {
    log.add((action, payload));
    // 실제 왕복처럼 한 틱 기다린다 — 연타 잠금 테스트가 이 사이를 본다.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return DeviceCommand(
        id: 'c${log.length}',
        deviceId: deviceId,
        issuedBy: 'u',
        action: action,
        payload: payload,
        status: CommandStatus.pending,
        result: null,
        issuedAt: DateTime.now(),
        ackedAt: null);
  }
}

class NoopTimerNotifs extends FanTimerNotificationService {
  @override
  Future<void> onFanCommandSent(
      String deviceId, String action, int? durationMs) async {}
}

/// 시트가 읽는 provider 일체. [sent]에 송신 명령이 쌓인다.
List<Override> controlOverrides({
  TelemetryReading? telemetry,
  bool online = true,
  bool dimmable = false,
  List<Schedule> schedules = const [],
  List<RunningTimer> timers = const [],
  required List<(CommandAction, Map<String, dynamic>?)> sent,
  Stream<TelemetryReading?>? telemetryStream,
  CommandStatusFetcher? statusFetcher,
  // 기존 테스트는 냉각팬이 살아 있던 동작을 검증한다 — 꺼 둔 상태는 false로.
  bool coolFanEnabled = true,
  // 자동 환기·분무 토글(출시 스위치 기본 꺼짐 — 기존 테스트 화면 변화 없음).
  bool autoEnvReleased = false,
  AutoEnvState autoEnv = AutoEnvState.none,
  // 시트가 열린 뒤 자동 상태가 바뀌는 경우 — 주면 [autoEnv] 대신 쓴다.
  Override? autoEnvOverride,
  DeviceSettingsRepository? settingsRepo,
}) =>
    [
      autoEnvReleasedProvider.overrideWithValue(autoEnvReleased),
      autoEnvOverride ?? autoEnvStateProvider.overrideWith((ref, id) => autoEnv),
      deviceSettingsRepositoryProvider
          .overrideWithValue(settingsRepo ?? FakeDeviceSettingsRepo()),
      coolFanEnabledProvider.overrideWithValue(coolFanEnabled),
      currentDeviceIdProvider.overrideWith((ref) async => kTestDeviceId),
      telemetryStreamProvider.overrideWith(
          (ref, id) => telemetryStream ?? Stream.value(telemetry ?? reading())),
      moduleOnlineProvider(kTestDeviceId).overrideWithValue(online),
      deviceListProvider.overrideWith((ref) async => [
            Device(
              id: kTestDeviceId,
              ownerId: null,
              enclosureId: null,
              name: 'test',
              isOnline: online,
              lastSeenAt: null,
              capabilities: {'led_dimmable': dimmable},
            )
          ]),
      runningTimersProvider.overrideWith((ref) async => timers),
      scheduleRepositoryProvider
          .overrideWithValue(FakeScheduleRepo([...schedules])),
      moduleCommandSenderProvider.overrideWith(() => FakeSender(sent)),
      // 토큰 자동 갱신 타이머를 끈 더미 클라이언트 — ACK 감시 조회는 400으로
      // 끝나 catch된다(테스트 HttpClient).
      supabaseClientProvider.overrideWithValue(SupabaseClient(
          'http://localhost:54321', 'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false))),
      fanTimerNotificationServiceProvider.overrideWithValue(NoopTimerNotifs()),
      // 기본은 기기가 곧바로 받아들인 명령(acked/ok).
      commandStatusFetcherProvider.overrideWithValue(statusFetcher ?? ackedOk),
    ];

Future<({String? status, String? result})?> ackedOk(String _) async =>
    (status: 'acked', result: 'ok');

Widget controlApp(Widget home, List<Override> overrides) => ProviderScope(
    overrides: overrides, child: MaterialApp(home: Scaffold(body: home)));

/// 기기 설정 REST 가짜 — 받은 PATCH 본문을 [patches]에 쌓는다.
///
/// - [patchDelay]: 저장 왕복 지연(연타·저장 중 닫기 테스트).
/// - [ignoresAutoFields]: 마이그레이션 전 서버처럼 `auto_*_enabled`를 무시하고
///   200을 준다(Review Focus 1).
/// - [getError]: 설정 조회 실패. [getGate]: 조회가 끝나지 않게 붙잡는다(로딩).
class FakeDeviceSettingsRepo implements DeviceSettingsRepository {
  FakeDeviceSettingsRepo({
    DeviceSettings? settings,
    this.patchDelay = Duration.zero,
    this.ignoresAutoFields = false,
    this.getError = false,
    this.getGate,
  }) : current = settings ?? const DeviceSettings(deviceId: kTestDeviceId);

  DeviceSettings current;
  final Duration patchDelay;
  final bool ignoresAutoFields;
  /// 테스트 중 바꿀 수 있다 — 실패 뒤 다시 불러오기(리뷰 5).
  bool getError;
  final Completer<void>? getGate;
  final List<Map<String, dynamic>> patches = [];

  @override
  Future<DeviceSettings> get(String deviceId) async {
    if (getGate case final gate?) await gate.future;
    if (getError) throw StateError('settings load failed');
    return current;
  }

  @override
  Future<DeviceSettings> patch(
    String deviceId, {
    double? targetTempC,
    double? targetHumidityPct,
    double? targetTempMin,
    double? targetTempMax,
    double? targetHumidMin,
    double? targetHumidMax,
    bool? autoVentEnabled,
    bool? autoMistEnabled,
  }) async {
    patches.add(DeviceSettings.patchBody(
      targetTempC: targetTempC,
      targetHumidityPct: targetHumidityPct,
      targetTempMin: targetTempMin,
      targetTempMax: targetTempMax,
      targetHumidMin: targetHumidMin,
      targetHumidMax: targetHumidMax,
      autoVentEnabled: autoVentEnabled,
      autoMistEnabled: autoMistEnabled,
    ));
    if (patchDelay > Duration.zero) await Future<void>.delayed(patchDelay);
    if (ignoresAutoFields) return current;
    final c = current;
    current = DeviceSettings(
      deviceId: c.deviceId,
      targetTempC: c.targetTempC,
      targetHumidityPct: c.targetHumidityPct,
      targetTempMin: c.targetTempMin,
      targetTempMax: c.targetTempMax,
      targetHumidMin: c.targetHumidMin,
      targetHumidMax: c.targetHumidMax,
      autoVentEnabled: autoVentEnabled ?? c.autoVentEnabled,
      autoMistEnabled: autoMistEnabled ?? c.autoMistEnabled,
      updatedAt: c.updatedAt,
    );
    return current;
  }
}

/// [key] 아래 스위치의 지금 값.
bool switchValue(WidgetTester tester, Key key) => tester
    .widget<ScheduleSwitch>(find.descendant(
        of: find.byKey(key), matching: find.byType(ScheduleSwitch)))
    .value;

/// 칩이 선택돼 보이는가.
bool chipSelected(WidgetTester tester, Key key) =>
    tester.widget<ScheduleChoiceChip>(find.byKey(key)).selected;

/// 루트 내비게이터에 띄운 제어 시트를 닫는다(바깥 탭과 같은 pop).
Future<void> closeSheet(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump();
}
