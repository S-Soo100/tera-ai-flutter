import '../../my_cage/domain/telemetry_reading.dart';

/// 현재 온습도 표시 규칙(2026-09-28, terra-server `APP_TELEMETRY_DISPLAY_2026-09-28`
/// §3 — 웹 콘솔 `telRemember`/`telValueHtml`과 같은 규칙).
///
/// 전엔 한 행씩 판정해 값을 **지웠다** — 센서 단발 실패(`a_ok=false`), 12초 무소식,
/// 폰 시계가 서버보다 조금 늦어 경과가 음수인 샘플마다 `--`가 되어 "표시됐다 안
/// 됐다"가 났다(데이터는 3~4초마다 빠짐없이 왔다). 이제:
/// - 값은 **정상 행에서만 덮어쓰고 어떤 경로로도 지우지 않는다**([EnvLiveReading.next]).
/// - 신선도는 지움이 아니라 3단계 표시([EnvFreshness]).
/// - 센서 실패는 10번(약 30초) 이어질 때만 "센서 오류" — 단발 실패를 배지로 띄우면
///   그 자체가 깜빡임이다(사용자 결정, 백엔드 권장은 단발 배지).

/// 이 안쪽은 어떤 UI 변화도 주지 않는다 — 도착 간격 3~4초, 지연 최대 2초의 3배.
const kEnvFreshFor = Duration(seconds: 15);

/// 이만큼 연속 실패하면 "센서 오류"로 알린다(3초 주기 → 약 30초).
const kSensorErrorAfter = 10;

/// 기기 한 대의 마지막 정상값과 실패 연속 횟수.
class EnvLiveReading {
  const EnvLiveReading(
      {required this.deviceId,
      this.temperature,
      this.humidity,
      this.measuredAt,
      this.consecutiveFaults = 0});

  final String deviceId;
  final double? temperature;
  final double? humidity;

  /// 마지막 **정상** 행의 측정 시각(기기 `ts`).
  final DateTime? measuredAt;
  final int consecutiveFaults;

  bool get hasValue => temperature != null || humidity != null;

  /// 새 행을 반영한다. 정상 행(`a_ok` + 값 있음)만 값을 덮어쓰고, 실패 행은 값을
  /// 두고 연속 횟수만 센다. 다른 기기 행·더 오래된 정상 행은 무시한다.
  EnvLiveReading next(TelemetryReading row) {
    if (row.deviceId != deviceId) return this;
    double? valid(double? v) => v != null && v.isFinite && v > 0 ? v : null;
    final t = valid(row.tA);
    final h = valid(row.hA);
    final good = row.aOk && (t != null || h != null);
    if (!good) {
      return EnvLiveReading(
          deviceId: deviceId,
          temperature: temperature,
          humidity: humidity,
          measuredAt: measuredAt,
          consecutiveFaults: consecutiveFaults + 1);
    }
    final at = row.ts;
    if (at != null && measuredAt != null && at.isBefore(measuredAt!)) {
      // 늦게 도착한 옛 정상 행(최신값 재조회와 겹침) — 값은 두고 실패만 끊는다.
      return EnvLiveReading(
          deviceId: deviceId,
          temperature: temperature,
          humidity: humidity,
          measuredAt: measuredAt);
    }
    return EnvLiveReading(
        deviceId: deviceId, temperature: t, humidity: h, measuredAt: at);
  }
}

/// 값의 신선도 — 값을 지우지 않고 보이는 방식만 바꾼다.
/// [fresh]: 15초 안, 그대로. [aging]: 15초 넘게 새 정상값이 없다 — 흐리게 + "N초 전".
/// [offline]: 서버가 `devices.is_online=false`로 판정(180초 무응답) — 더 흐리게 +
/// "오프라인 · HH:MM 기준". 앱이 자체 타이머로 오프라인을 판정하지 않는다.
enum EnvFreshness { fresh, aging, offline }

typedef EnvLiveView = ({
  double? temperature,
  double? humidity,
  EnvFreshness freshness,
  Duration age,
  DateTime? measuredAt,
  bool sensorError,
});

/// 화면에 그릴 값. 경과는 기기 측정 시각 기준이고 **음수면 0**(폰 시계가 서버보다
/// 늦은 경우 — 전엔 이때 값을 버려 깜빡였다).
EnvLiveView envLiveView(EnvLiveReading? reading,
    {required DateTime now, bool? online}) {
  final at = reading?.measuredAt;
  var age = at == null ? Duration.zero : now.difference(at);
  if (age.isNegative) age = Duration.zero;
  final freshness = online == false
      ? EnvFreshness.offline
      : at != null && age >= kEnvFreshFor
          ? EnvFreshness.aging
          : EnvFreshness.fresh;
  return (
    temperature: reading?.temperature,
    humidity: reading?.humidity,
    freshness: freshness,
    age: age,
    measuredAt: at,
    sensorError: (reading?.consecutiveFaults ?? 0) >= kSensorErrorAfter,
  );
}
