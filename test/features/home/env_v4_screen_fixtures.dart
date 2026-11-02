// v4 온습도 화면(온습도 설정·적정 범위·온습도 상세)을 통째로 그릴 때 쓰는
// provider 대역. 글자 배율 검사(test/design/text_scale_overflow_test.dart)와
// 수치 검수용 렌더가 같이 쓴다.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_alert_prefs_repository.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_alert_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_live_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/axis_bounds.dart';
import 'package:vivanaut/shared/domain/control_log.dart';
import 'package:vivanaut/shared/domain/env_chart_data.dart';
import 'package:vivanaut/shared/domain/env_extremes.dart';
import 'package:vivanaut/shared/domain/week_range.dart';

const kEnvV4DeviceId = 'd1';

class EnvV4SettingsRepo implements DeviceSettingsRepository {
  EnvV4SettingsRepo([DeviceSettings? current])
      : current = current ?? const DeviceSettings(deviceId: kEnvV4DeviceId);
  DeviceSettings current;

  @override
  Future<DeviceSettings> get(String deviceId) async => current;

  @override
  Future<DeviceSettings> patch(String deviceId,
          {double? targetTempC,
          double? targetHumidityPct,
          double? targetTempMin,
          double? targetTempMax,
          double? targetHumidMin,
          double? targetHumidMax}) async =>
      current;
}

class EnvV4PrefsRepo implements EnvAlertPrefsRepository {
  @override
  String get userId => 'u1';
  @override
  Future<EnvAlertPrefs> load() async => EnvAlertPrefs.allOn;
  @override
  Future<void> setTemp(bool on) async {}
  @override
  Future<void> setHumid(bool on) async {}
}

User envV4User() => User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01');

/// 펌웨어 기본 보정 −1.5℃가 걸린 온라인 기기(S05).
const envV4Device = Device(
    id: kEnvV4DeviceId,
    ownerId: 'u1',
    enclosureId: null,
    name: '거실 사육장',
    isOnline: true,
    lastSeenAt: null,
    tempOffsetC: -1.5);

/// 온습도 설정·적정 범위 화면용.
List<Override> envV4SettingOverrides() => [
      deviceListProvider.overrideWith((ref) async => const [envV4Device]),
      deviceSettingsRepositoryProvider.overrideWithValue(EnvV4SettingsRepo()),
      moduleLinkProvider(kEnvV4DeviceId).overrideWithValue(ModuleLink.online),
      currentUserProvider.overrideWith((ref) => envV4User()),
      envAlertPrefsRepositoryProvider
          .overrideWith((ref, id) => EnvV4PrefsRepo()),
    ];

EnvAlert _alert(String id, String kind, String level, String message) =>
    EnvAlert.fromRow({
      'id': id,
      'device_id': kEnvV4DeviceId,
      'kind': kind,
      'message': message,
      'context': {'rule': 'v4', 'level': level},
      'triggered_at': '2026-11-02T05:00:00Z',
      'resolved_at': null,
    })!;

/// A10 — 저온 경고 + 건조 주의(서버 문구 그대로, 습도 `%p`).
final envV4A10Alerts = [
  _alert('t', 'env_temp_low', 'danger', '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요'),
  _alert('h', 'env_humid_low', 'caution', '[건조 주의] 적정 습도보다 -6%p'),
];

/// 온습도 상세(A10 상태 — 현재 15.0℃ / 34.8%, 오늘 15~26 / 34~80).
List<Override> envV4DetailOverrides({List<EnvAlert>? alerts}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final week = WeekRange.containing(now);
  return [
    currentDeviceIdProvider.overrideWith((ref) async => kEnvV4DeviceId),
    openEnvAlertsProvider
        .overrideWith((ref) => Stream.value(alerts ?? envV4A10Alerts)),
    envLiveViewProvider(kEnvV4DeviceId).overrideWithValue(envLiveView(
        EnvLiveReading(
            deviceId: kEnvV4DeviceId,
            temperature: 15,
            humidity: 34.8,
            measuredAt: now),
        now: now,
        online: true)),
    deviceSettingsRepositoryProvider.overrideWithValue(EnvV4SettingsRepo()),
    envDailyAverageProvider.overrideWith((ref) async =>
        (temperature: 20.5, humidity: 55.0, countUnavailable: false)),
    envDayChartDataProvider.overrideWith((ref) async => EnvChartData(
          from: start,
          to: DateTime(start.year, start.month, start.day + 1),
          tempAxis: AxisBounds.forValues([15, 26]),
          humidAxis: AxisBounds.forValues([34, 80]),
          tempPoints: const [
            (x: 0.1, y: 0.3),
            (x: 0.2, y: 0.6),
            (x: 0.4, y: 0.1)
          ],
          humidPoints: const [(x: 0.1, y: 0.5), (x: 0.4, y: 0.05)],
        )),
    envDayExtremesProvider.overrideWith((ref) async => const EnvExtremes(
        tempMin: 15, tempMax: 26, humidMin: 34, humidMax: 80)),
    envDayControlLogProvider.overrideWith((ref) async => [
          ControlLogEntry(
            kind: MarkerKind.fan,
            state: ControlLogState.on,
            at: now.subtract(const Duration(hours: 2)),
            temperature: 29,
            humidity: 55,
          ),
        ]),
    envWeekRowsProvider.overrideWith((ref) async => (
          temp: [
            for (final d in week.days) DayMinMax(day: d, min: 18, max: 26)
          ],
          humid: [
            for (final d in week.days) DayMinMax(day: d, min: 40, max: 80)
          ],
        )),
  ];
}
