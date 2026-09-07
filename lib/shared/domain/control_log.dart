import '../../features/my_cage/domain/telemetry_bucket.dart';
import 'actuator_marker.dart';

/// 제어 기록 로우의 상태 (PRD §4.3.2, 계획서 §A.5).
///
/// [ran]은 방향이 없는 동작이다 — 분무(모멘터리, 펌웨어가 스스로 끔)와
/// `*_toggle`(과거 이력, 뒤집기라 방향 미상). 델타를 만들지 않는다.
enum ControlLogState { on, off, ran }

/// 사육장 제어 기록 한 줄 (PRD §4.3.2).
///
/// [temperature]/[humidity]는 그 시점의 온습도 — 명령 시각과 가장 가까운
/// 30분 버킷의 평균이고, 30분 넘게 떨어져 있으면 모른다고 말한다(null).
/// [deltaTemperature]/[deltaHumidity]는 **off 로우에만** 있다 — 같은 기기의
/// 직전 on 시점 온습도와의 차이(off − on).
class ControlLogEntry {
  final MarkerKind kind;
  final ControlLogState state;

  /// 명령 시각 (**로컬**). DB `issued_at`은 UTC라 파싱 시 변환한다.
  final DateTime at;

  final double? temperature;
  final double? humidity;
  final double? deltaTemperature;
  final double? deltaHumidity;

  const ControlLogEntry({
    required this.kind,
    required this.state,
    required this.at,
    this.temperature,
    this.humidity,
    this.deltaTemperature,
    this.deltaHumidity,
  });
}

/// action 문자열 → (kind, state).
///
/// [ActuatorMarker._kindByAction]과 같은 action 집합을 다룬다 — 새 명령을
/// 추가하면 **둘 다** 고칠 것(안 하면 그 동작만 화면에서 조용히 사라진다).
/// `lcd_bitmap`/`lcd_clear`는 의도적으로 없다(액추에이터 동작이 아님).
const _entryByAction = <String, ({MarkerKind kind, ControlLogState state})>{
  // 분무: `mist`(정량 모멘터리)·`relay_toggle`(구 이력)은 방향 없음.
  // `relay_on/off`는 절대 명령이라 방향을 안다.
  'mist': (kind: MarkerKind.mist, state: ControlLogState.ran),
  'relay_toggle': (kind: MarkerKind.mist, state: ControlLogState.ran),
  'relay_on': (kind: MarkerKind.mist, state: ControlLogState.on),
  'relay_off': (kind: MarkerKind.mist, state: ControlLogState.off),

  'fan_on': (kind: MarkerKind.fan, state: ControlLogState.on),
  'fan_off': (kind: MarkerKind.fan, state: ControlLogState.off),
  'fan_toggle': (kind: MarkerKind.fan, state: ControlLogState.ran),

  'heater_on': (kind: MarkerKind.heater, state: ControlLogState.on),
  'heater_off': (kind: MarkerKind.heater, state: ControlLogState.off),
  'heater_toggle': (kind: MarkerKind.heater, state: ControlLogState.ran),

  'led_on': (kind: MarkerKind.led, state: ControlLogState.on),
  'led_off': (kind: MarkerKind.led, state: ControlLogState.off),
  'led_toggle': (kind: MarkerKind.led, state: ControlLogState.ran),
};

/// `commands` 원시 행 + 그 날의 30분 버킷 → 제어 기록 (시간 오름차순).
///
/// - `status='acked'`만 쓴다 — 거부/대기 명령을 동작으로 그리면 오해한다.
/// - 온습도 매칭 후보는 **tAvg·hAvg가 모두 0 초과**인 버킷만 — 0은 센서
///   오프라인 센티넬이다(메모리 `project_telemetry_zero_sentinel`).
/// - 델타 짝: off는 같은 kind의 직전 on을 **소진**한다 — on 하나에 off가
///   둘이면 두 번째 off는 짝이 없다(기기는 이미 꺼져 있었다).
List<ControlLogEntry> buildControlLog({
  required List<Map<String, dynamic>> commandRows,
  required List<TelemetryBucket> buckets,
}) {
  // 매칭 후보 버킷 — 센티넬(0값) 제외, 시각은 로컬로 통일.
  final candidates = <({DateTime at, double t, double h})>[
    for (final b in buckets)
      if (b.tAvg != null && b.tAvg! > 0 && b.hAvg != null && b.hAvg! > 0)
        (at: b.bucket.toLocal(), t: b.tAvg!, h: b.hAvg!),
  ];

  ({double? t, double? h}) envAt(DateTime at) {
    ({DateTime at, double t, double h})? best;
    Duration? bestGap;
    for (final c in candidates) {
      final gap = (c.at.difference(at)).abs();
      if (bestGap == null || gap < bestGap) {
        best = c;
        bestGap = gap;
      }
    }
    if (best == null || bestGap! > const Duration(minutes: 30)) {
      return (t: null, h: null);
    }
    return (t: best.t, h: best.h);
  }

  // 파싱 + 시간 오름차순 정렬 (델타 짝짓기는 시간순이 전제다).
  final parsed = <({MarkerKind kind, ControlLogState state, DateTime at})>[];
  for (final r in commandRows) {
    if (r['status'] != 'acked') continue;
    final entry = _entryByAction[r['action'] as String?];
    if (entry == null) continue;
    final raw = r['issued_at'] == null
        ? null
        : DateTime.tryParse(r['issued_at'].toString());
    if (raw == null) continue;
    // ⚠️ issued_at은 UTC 문자열 — 로컬로 바꿔야 화면 시각·버킷 매칭이 맞는다.
    parsed.add((kind: entry.kind, state: entry.state, at: raw.toLocal()));
  }
  parsed.sort((a, b) => a.at.compareTo(b.at));

  // 마지막으로 본 on 로우 (kind별) — off가 나오면 소진한다.
  final lastOn = <MarkerKind, ControlLogEntry>{};
  final out = <ControlLogEntry>[];
  for (final p in parsed) {
    final env = envAt(p.at);
    double? dT;
    double? dH;
    if (p.state == ControlLogState.off) {
      final on = lastOn.remove(p.kind); // 소진 — 두 번째 off는 짝 없음.
      if (on != null) {
        if (env.t != null && on.temperature != null) {
          dT = env.t! - on.temperature!;
        }
        if (env.h != null && on.humidity != null) {
          dH = env.h! - on.humidity!;
        }
      }
    }
    final entry = ControlLogEntry(
      kind: p.kind,
      state: p.state,
      at: p.at,
      temperature: env.t,
      humidity: env.h,
      deltaTemperature: dT,
      deltaHumidity: dH,
    );
    if (p.state == ControlLogState.on) lastOn[p.kind] = entry;
    out.add(entry);
  }
  return out;
}
