import '../../features/home/domain/auto_env.dart';
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

  /// Matched successful ON command, not an inferred firmware transition.
  final DateTime? startedAt;

  /// 분무 한 번의 총 분사 시간(ms). 이어 보낸 3초 명령·서버가 이은 5초
  /// 명령은 한 줄로 묶어 합친다(2026-09-25) — 9초가 세 줄로 찍히면 세 번
  /// 뿌린 것으로 읽힌다.
  final int? sprayMs;

  /// 서버 자동 환경 제어가 낸 명령(`commands.source='auto'`, 2026-11-05).
  /// 화면은 "자동 환기 켜짐"·"자동 분무 3초 작동"처럼 구분해 그린다.
  final bool auto;

  /// 자동 명령의 원인(`commands.reason`). 컬럼이 생기기 전 서버의 행·모르는
  /// 값·사용자 명령은 null — 화면은 원인 없이 시각만 보인다.
  final AutoEnvReason? reason;

  Duration? get duration => state != ControlLogState.off ||
          startedAt == null ||
          !at.isAfter(startedAt!)
      ? null
      : at.difference(startedAt!);

  const ControlLogEntry({
    required this.kind,
    required this.state,
    required this.at,
    this.temperature,
    this.humidity,
    this.deltaTemperature,
    this.deltaHumidity,
    this.startedAt,
    this.sprayMs,
    this.auto = false,
    this.reason,
  });
}

/// 이어진 분무로 볼 최대 간격 — 앱의 회차 간격 5초·서버 이어 붙이기 약 7초.
const kMistChainGap = Duration(seconds: 8);

/// 자동 환기 재켜짐을 이어진 것으로 볼 여유 — 직전 자동 `fan_on`의 타이머가
/// 끝난 뒤 이 안에 온 자동 `fan_on`은 같은 줄로 합친다(계획 D4). 서버의
/// "꺼진 팬 재명령 최소 5분 간격"을 덮는 값이다(Q4 회신으로 상한 확인 예정).
const kAutoVentChainSlack = Duration(minutes: 10);

/// 파싱한 명령 한 건 — 묶기·델타 짝짓기 사이에서 쓰는 중간 모양.
typedef _Cmd = ({
  MarkerKind kind,
  ControlLogState state,
  DateTime at,
  String id,
  int? timerMs,
  bool continuation,
  bool auto,
  AutoEnvReason? reason,
});

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
  'fan2_on': (kind: MarkerKind.cooling, state: ControlLogState.on),
  'fan2_off': (kind: MarkerKind.cooling, state: ControlLogState.off),
  'fan2_toggle': (kind: MarkerKind.cooling, state: ControlLogState.ran),

  'heater_on': (kind: MarkerKind.heater, state: ControlLogState.on),
  'heater_off': (kind: MarkerKind.heater, state: ControlLogState.off),
  'heater_toggle': (kind: MarkerKind.heater, state: ControlLogState.ran),

  'led_on': (kind: MarkerKind.led, state: ControlLogState.on),
  'led_off': (kind: MarkerKind.led, state: ControlLogState.off),
  'led_toggle': (kind: MarkerKind.led, state: ControlLogState.ran),
};

/// The query and parser share the exact supported action contract.
List<String> controlLogActions([MarkerKind? kind]) => [
      for (final entry in _entryByAction.entries)
        if (kind == null || entry.value.kind == kind) entry.key,
    ];

bool isControlLogStart(Object? action) =>
    action is String && _entryByAction[action]?.state == ControlLogState.on;

/// `commands` 원시 행 + 그 날의 30분 버킷 → 제어 기록 (시간 오름차순).
///
/// - `status='acked'`와 `result='ok'`만 쓴다 — 거부/대기 명령을 동작으로 그리면 오해한다.
/// - 지표별 유한한 0 초과 평균값만 매칭한다 — 0은 센서
///   오프라인 센티넬이다(메모리 `project_telemetry_zero_sentinel`).
/// - 델타 짝: off는 같은 kind의 직전 on을 **소진**한다 — on 하나에 off가
///   둘이면 두 번째 off는 짝이 없다(기기는 이미 꺼져 있었다).
/// - 묶기는 델타 짝짓기 **전**에 한다 — 이어진 분무(자동·손 분무는 따로)와
///   매시간 다시 켠 자동 환기(계획 D4)는 한 줄이다. 온습도 상세의 차트
///   마커도 이 결과를 그대로 쓰므로 함께 줄어든다(의도).
List<ControlLogEntry> buildControlLog({
  required List<Map<String, Object?>> commandRows,
  required List<TelemetryBucket> buckets,
  DateTime? visibleFrom,
  DateTime? visibleTo,
}) {
  // Each metric is independently valid; missing humidity must not erase a
  // measured temperature. Non-finite values never reach display/deltas.
  double? nearest(DateTime at, double? Function(TelemetryBucket) pick) {
    double? best;
    Duration? bestGap;
    for (final bucket in buckets) {
      final value = pick(bucket);
      if (value == null || !value.isFinite || value <= 0) continue;
      final gap = bucket.bucket.difference(at).abs();
      if (gap > const Duration(minutes: 30)) continue;
      if (bestGap == null || gap < bestGap) {
        best = value;
        bestGap = gap;
      }
    }
    return best;
  }

  // 파싱 + 시간 오름차순 정렬 (델타 짝짓기는 시간순이 전제다).
  final parsed = <_Cmd>[];
  for (final r in commandRows) {
    if (r['status'] != 'acked' || r['result'] != 'ok') continue;
    final action = r['action'];
    final entry = action is String ? _entryByAction[action] : null;
    if (entry == null) continue;
    final raw = r['issued_at'] == null
        ? null
        : DateTime.tryParse(r['issued_at'].toString());
    if (raw == null) continue;
    // ⚠️ issued_at은 UTC 문자열 — 로컬로 바꿔야 화면 시각·버킷 매칭이 맞는다.
    final payload = r['payload'];
    final duration = payload is Map ? payload['duration_ms'] : null;
    parsed.add((
      kind: entry.kind,
      state: entry.state,
      at: raw.toLocal(),
      id: r['id'] is String ? r['id']! as String : '',
      timerMs: duration is int && duration > 0 ? duration : null,
      // 서버가 펌웨어 5초 상한 때문에 이어 보낸 분무(원래 요청의 나머지).
      continuation: r['source'] == 'timer',
      auto: r['source'] == 'auto',
      // `reason` 컬럼은 서버 마이그레이션 뒤에만 있다 — 키가 있을 때만 읽는다.
      reason:
          r.containsKey('reason') ? AutoEnvReason.fromWire(r['reason']) : null,
    ));
  }
  parsed.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time != 0 ? time : a.id.compareTo(b.id);
  });

  // 이어진 분무(앱 3초×N·서버 5초+5초)는 첫 명령 한 줄로 묶고 분사 시간을
  // 합친다. 간격은 직전 **회차**부터 잰다. 자동 분무와 손 분무는 묶지 않는다
  // — 자동 3초 직후 손으로 뿌린 것이 "자동 분무 6초"로 읽히면 안 된다. 서버
  // 이음 행(`source='timer'`)은 원래 요청의 나머지라 머리의 자동 여부를 따른다.
  final mistMerged = <_Cmd>[];
  int? head; // 묶는 중인 분무의 mistMerged 인덱스
  DateTime? chainLast; // 그 묶음의 마지막 회차 시각
  for (final p in parsed) {
    final isMist = p.kind == MarkerKind.mist && p.state == ControlLogState.ran;
    if (isMist &&
        head != null &&
        chainLast != null &&
        p.at.difference(chainLast) <= kMistChainGap &&
        (p.continuation || p.auto == mistMerged[head].auto)) {
      final h = mistMerged[head];
      mistMerged[head] = (
        kind: h.kind,
        state: h.state,
        at: h.at,
        id: h.id,
        // 서버 이음 행은 원래 요청(예: 10초)에 이미 들어 있다 — 더하지 않는다.
        // 길이를 모르는 옛 행(relay_toggle)끼리면 null로 둔다 — 0초로 쓰면 안 된다.
        timerMs: p.continuation || p.timerMs == null
            ? h.timerMs
            : (h.timerMs ?? 0) + p.timerMs!,
        continuation: h.continuation,
        auto: h.auto,
        reason: h.reason,
      );
      chainLast = p.at;
      continue;
    }
    mistMerged.add(p);
    if (isMist) {
      head = mistMerged.length - 1;
      chainLast = p.at;
    }
  }

  // 매시간 다시 켠 자동 환기(계획 D4)를 한 줄로 합친다. 원인이 남아 있으면
  // 서버는 1시간 타이머가 끝날 때마다 `fan_on`을 다시 보낸다(하루 최대 12줄).
  // - 직전 회차의 `at + timerMs + [kAutoVentChainSlack]` 안에 온 자동 `fan_on`만.
  // - 사이에 환기팬의 다른 명령(사용자 on/off/toggle, 자동 off)이 끼면 끊는다.
  // - 합칠 때 첫 줄의 timerMs를 "마지막 회차가 끝나는 시각 − 첫 줄 시각"으로
  //   늘린다. 그래야 아래 타이머 만료 판정이 꺼짐 줄의 시작·델타를 지우지 않는다.
  // - 머리가 보이는 창([visibleFrom]) 밖이면 창 안 첫 재켜짐부터 새로 묶는다
  //   — 창 밖 머리에 흡수되면 그날 "켜짐" 줄·차트 마커가 통째로 사라진다
  //   (리뷰 2026-11-05). 그날 지속 시간은 창 안 첫 재켜짐부터 센다.
  // ⚠️ 받아들인 한계: 자정 전부터 이어진 자동 환기는 직전 조회(readPreceding)가
  // 기기마다 1건만 읽어 첫 시작을 모를 수 있다(사용자 명령도 같은 한계).
  final merged = <_Cmd>[];
  int? ventHead; // 묶는 중인 자동 환기의 merged 인덱스
  DateTime? ventLastAt; // 그 묶음의 마지막 회차 시각
  int? ventLastMs; // 그 회차의 타이머
  for (final p in mistMerged) {
    if (p.kind != MarkerKind.fan) {
      merged.add(p);
      continue;
    }
    final isAutoOn = p.auto && p.state == ControlLogState.on;
    final crossesWindow = visibleFrom != null &&
        ventHead != null &&
        merged[ventHead].at.isBefore(visibleFrom) &&
        !p.at.isBefore(visibleFrom);
    if (isAutoOn &&
        !crossesWindow &&
        ventHead != null &&
        ventLastAt != null &&
        ventLastMs != null &&
        !p.at.isAfter(ventLastAt
            .add(Duration(milliseconds: ventLastMs))
            .add(kAutoVentChainSlack))) {
      final h = merged[ventHead];
      merged[ventHead] = (
        kind: h.kind,
        state: h.state,
        at: h.at,
        id: h.id,
        // 타이머 없는 재켜짐이면 끝을 모른다 — 만료로 보지 않게 null.
        timerMs: p.timerMs == null
            ? null
            : p.at
                .add(Duration(milliseconds: p.timerMs!))
                .difference(h.at)
                .inMilliseconds,
        continuation: h.continuation,
        auto: h.auto,
        reason: h.reason,
      );
      ventLastAt = p.at;
      ventLastMs = p.timerMs;
      continue;
    }
    merged.add(p);
    if (isAutoOn) {
      ventHead = merged.length - 1;
      ventLastAt = p.at;
      ventLastMs = p.timerMs;
    } else {
      // 환기팬의 다른 명령 — 이어진 자동 환기가 아니다.
      ventHead = null;
      ventLastAt = null;
      ventLastMs = null;
    }
  }

  // 마지막으로 본 on 로우 (kind별) — off가 나오면 소진한다.
  final lastOn = <MarkerKind, ({ControlLogEntry entry, int? timerMs})>{};
  final out = <ControlLogEntry>[];
  for (final p in merged) {
    final env =
        (t: nearest(p.at, (b) => b.tAvg), h: nearest(p.at, (b) => b.hAvg));
    double? dT;
    double? dH;
    DateTime? startedAt;
    if (p.state == ControlLogState.off) {
      final previous =
          lastOn.remove(p.kind); // Consume each explicit start once.
      final on = previous?.entry;
      final elapsed = on == null ? null : p.at.difference(on.at);
      // Timer expiry is firmware-owned, not a synthetic off command. A later
      // explicit off cannot prove that a timed fan ran continuously until then.
      final expired = previous?.timerMs != null &&
          elapsed != null &&
          elapsed.inMilliseconds > previous!.timerMs!;
      if (on != null &&
          elapsed != null &&
          elapsed > Duration.zero &&
          !expired) {
        startedAt = on.at;
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
      startedAt: startedAt,
      sprayMs: p.kind == MarkerKind.mist && p.state == ControlLogState.ran
          ? p.timerMs
          : null,
      auto: p.auto,
      reason: p.reason,
    );
    if (p.state == ControlLogState.on) {
      lastOn[p.kind] = (entry: entry, timerMs: p.timerMs);
    }
    if (p.state == ControlLogState.ran) lastOn.remove(p.kind);
    // Pair using lookback context first, then show only the selected day.
    if ((visibleFrom == null || !p.at.isBefore(visibleFrom)) &&
        (visibleTo == null || p.at.isBefore(visibleTo))) {
      out.add(entry);
    }
  }
  return out;
}
