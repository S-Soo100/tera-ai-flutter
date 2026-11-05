// v4 온습도 화면(온습도 설정·적정 범위·온습도 상세)을 통째로 그릴 때 쓰는
// provider 대역. 글자 배율 검사(test/design/text_scale_overflow_test.dart)와
// 수치 검수용 렌더가 같이 쓴다.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivanaut/features/home/data/env_report_repository.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_alert_prefs_repository.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_alert_providers.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/env_live_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_providers.dart';
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
          double? targetHumidMax,
          bool? autoVentEnabled,
          bool? autoMistEnabled}) async =>
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

/// 사용자 보정 −2℃(기기 값 = 공장 −1.5 + −2 = −3.5)가 걸린 온라인 기기(S06).
const envV4Device = Device(
    id: kEnvV4DeviceId,
    ownerId: 'u1',
    enclosureId: null,
    name: '거실 사육장',
    isOnline: true,
    lastSeenAt: null,
    tempOffsetC: -3.5);

/// 온습도 설정·적정 범위 화면용.
List<Override> envV4SettingOverrides() => [
      deviceListProvider.overrideWith((ref) async => const [envV4Device]),
      deviceSettingsRepositoryProvider.overrideWithValue(EnvV4SettingsRepo()),
      moduleLinkProvider(kEnvV4DeviceId).overrideWithValue(ModuleLink.online),
      currentUserProvider.overrideWith((ref) => envV4User()),
      envAlertPrefsRepositoryProvider
          .overrideWith((ref, id) => EnvV4PrefsRepo()),
      deviceOffsetProvider(kEnvV4DeviceId)
          .overrideWith((ref) => Stream.value(envV4Device.tempOffsetC)),
    ];

/// 보정값 설정 화면용 — 기기 보고 온도 24.2℃(사용자 보정 −2 반영 후 → 측정 26.2).
List<Override> envV4OffsetOverrides() => [
      ...envV4SettingOverrides(),
      envLiveViewProvider(kEnvV4DeviceId).overrideWith((ref) {
        final now = DateTime.now();
        return envLiveView(
            EnvLiveReading(
                deviceId: kEnvV4DeviceId, temperature: 24.2, measuredAt: now),
            now: now,
            online: true);
      }),
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
/// A26·A36 + 습도 범위 이탈 — 온도·습도·습기 사이클 세 줄.
final envV4CycleAlerts = [
  _alert('t', 'env_temp_high', 'caution', '[고온 주의] 적정 온도보다 +5.2℃'),
  _alert('h', 'env_humid_low', 'caution', '[건조 주의] 적정 습도보다 -6%p'),
  _alert('g', 'env_mist_gap', 'caution', '[건조 주의] 분무 필요'),
];

List<Override> envV4DetailOverrides(
    {List<EnvAlert>? alerts, FakeEnvReportRepository? reports}) {
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
    // 일일·주간 분석은 진짜 provider + 가짜 저장소(기본: 행 없음).
    envReportRepositoryProvider
        .overrideWithValue(reports ?? FakeEnvReportRepository()),
    currentUserProvider.overrideWith((ref) => envV4User()),
  ];
}

/// A15 — 지난 날 일일 분석(낮은 온도 2줄 + 건조 1줄), 구간 [date] 08:00 ~ 다음 날 08:00.
EnvDailyReport envV4DailyReport(DateTime date) => EnvDailyReport(
      deviceId: kEnvV4DeviceId,
      reportDate: DateTime(date.year, date.month, date.day),
      windowStart: DateTime(date.year, date.month, date.day, 8),
      windowEnd: DateTime(date.year, date.month, date.day + 1, 8),
      tempCard: const EnvReportCard(
          element: EnvReportElement.temp,
          code: 'TEMP_CAUTION_LOW',
          status: EnvReportStatus.caution,
          title: '낮은 온도가 기록됐어요',
          lines: [
            '14:21~16:20 적정 온도보다 최대 -3.1℃ 이탈',
            '16:30~17:00 적정 온도보다 최대 -2℃ 이탈'
          ]),
      humidCard: const EnvReportCard(
          element: EnvReportElement.humid,
          code: 'HUM_DRY',
          status: EnvReportStatus.caution,
          title: '건조를 주의해 주세요',
          lines: ['9:30~12:00 적정 습도보다 최대 -12.5% 이탈']),
    );

/// A19·A20 — 지난주 주간 분석(온도 경고 카드 + 습도 수집 끊김 안내와 카드).
EnvWeeklyReport envV4WeeklyReport(DateTime monday) => EnvWeeklyReport(
      deviceId: kEnvV4DeviceId,
      weekStart: monday,
      tempCard: const EnvReportCard(
          element: EnvReportElement.temp,
          code: 'TEMP_DANGER',
          status: EnvReportStatus.danger,
          title: '주간 중 위험 온도가 감지되었어요',
          lines: ['총 3회 위험 온도 발생. 적정 온도보다 최대 5.2℃ 이탈']),
      humidCard: const EnvReportCard(
          element: EnvReportElement.humid,
          code: 'HUM_DRY',
          status: EnvReportStatus.caution,
          title: '사육장이 건조한 날이 많았어요',
          lines: ['총 3회 건조 주의가 발생. 사육장에 수분을 보충해 주세요']),
      notices: const [
        EnvReportNotice(
            code: 'ERR_DISCONNECT',
            element: EnvReportElement.humid,
            title: '데이터 수집이 불안정했어요',
            body: '기기 연결 상태를 확인해 주세요'),
      ],
    );

/// 호출을 기록하고 값을 바로 돌려주는 가짜 저장소.
class FakeEnvReportRepository implements EnvReportRepository {
  FakeEnvReportRepository({this.daily, this.weekly, this.failDaily = 0});
  EnvDailyReport? daily;
  EnvWeeklyReport? weekly;

  /// 처음 [failDaily]번은 오류 스트림을 돌려준다(다시 시도 검증).
  int failDaily;
  final List<String> dailyCalls = [];
  final List<String> weeklyCalls = [];

  @override
  Stream<EnvDailyReport?> watchDaily(String deviceId, DateTime date,
      {required EnvReportSubscribe subscribe}) {
    dailyCalls.add('$deviceId@${envReportDateKey(date)}');
    if (failDaily > 0) {
      failDaily--;
      return Stream.error(Exception('boom'));
    }
    return Stream.value(daily);
  }

  @override
  Stream<EnvWeeklyReport?> watchWeekly(String deviceId, DateTime monday,
      {required EnvReportSubscribe subscribe}) {
    weeklyCalls.add('$deviceId@${envReportDateKey(monday)}');
    return Stream.value(weekly);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
