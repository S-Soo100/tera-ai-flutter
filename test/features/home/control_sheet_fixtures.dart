// 홈 제어 시트 테스트 공용 fixture — 명령 송신·알림·Supabase 클라이언트를
// 가짜로 바꿔 실기기·서버 없이 시트 동작을 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/supabase/supabase_provider.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_command.dart';
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
}) =>
    [
      currentDeviceIdProvider.overrideWith((ref) async => kTestDeviceId),
      telemetryStreamProvider.overrideWith(
          (ref, id) => Stream.value(telemetry ?? reading())),
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
    ];

Widget controlApp(Widget home, List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: home)));
