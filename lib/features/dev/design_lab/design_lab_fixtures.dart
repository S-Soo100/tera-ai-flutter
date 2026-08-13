/// 디자인 랩 공용 더미 데이터.
///
/// **3안이 전부 같은 값을 쓴다** — 스타일 말고는 아무것도 다르지 않아야
/// 비교가 공정하다. 시각은 고정해 두어 화면을 다시 열어도 같은 그림이 나온다.
/// 실 provider·Repository는 건드리지 않는다(랩 격리).
library;

import 'dart:math' as math;

/// 랩의 "지금". 밤 활동 진행 바(22:00~06:00)가 중간쯤 차 있도록 새벽 1시로.
final DateTime kLabNow = DateTime(2026, 8, 13, 1, 20);

// ─────────────────────────────────────────────────────────────────────────────
// 온습도 24h 시계열
// ─────────────────────────────────────────────────────────────────────────────

class LabEnvPoint {
  const LabEnvPoint({required this.at, required this.temp, required this.humid});

  final DateTime at;
  final double temp;
  final double humid;
}

/// 24시간 30분 간격 시계열(49점). 새벽 4시 최저·오후 4시 최고,
/// 습도는 온도와 반대 위상(공기가 데워지면 상대습도가 떨어진다).
final List<LabEnvPoint> kLabEnvSeries = List.unmodifiable(() {
  final start = kLabNow.subtract(const Duration(hours: 24));
  final out = <LabEnvPoint>[];
  for (var i = 0; i <= 48; i++) {
    final at = start.add(Duration(minutes: 30 * i));
    final hour = at.hour + at.minute / 60;
    final phase = (hour - 4) / 24 * 2 * math.pi;
    final wave = -math.cos(phase);
    // 미세한 요철(결정적 — Random 미사용)을 얹어 "실측 느낌"만 낸다.
    final jitter = math.sin(i * 1.7) * 0.15;
    out.add(LabEnvPoint(
      at: at,
      temp: 26.5 + 2.6 * wave + jitter,
      humid: 62 - 9 * wave - jitter * 4,
    ));
  }
  return out;
}());

/// 현재값(시계열 마지막 점).
final LabEnvPoint kLabCurrent = kLabEnvSeries.last;

double get kLabTempMax =>
    kLabEnvSeries.map((p) => p.temp).reduce(math.max);
double get kLabTempMin =>
    kLabEnvSeries.map((p) => p.temp).reduce(math.min);
double get kLabHumidMax =>
    kLabEnvSeries.map((p) => p.humid).reduce(math.max);
double get kLabHumidMin =>
    kLabEnvSeries.map((p) => p.humid).reduce(math.min);

/// 전일 대비 증감(더미). 히어로 배지용.
const double kLabTempDelta = 0.8;

// ─────────────────────────────────────────────────────────────────────────────
// 기기 4종
// ─────────────────────────────────────────────────────────────────────────────

enum LabDeviceKind { heater, mist, led, fan }

class LabDevice {
  const LabDevice({
    required this.kind,
    required this.name,
    required this.isOn,
    required this.statusLabel,
    required this.todayRuntimeMinutes,
  });

  final LabDeviceKind kind;
  final String name;

  /// 초기 상태 — 각 변형이 로컬 토글로 복사해서 쓴다.
  final bool isOn;

  /// 카드에 붙는 한 줄 상태 텍스트.
  final String statusLabel;

  /// 오늘 가동 시간(분). C안 진행 링 등에 쓴다.
  final int todayRuntimeMinutes;
}

const List<LabDevice> kLabDevices = [
  LabDevice(
    kind: LabDeviceKind.heater,
    name: '히터',
    isOn: true,
    statusLabel: '켜짐 · 26.5℃ 유지',
    todayRuntimeMinutes: 312,
  ),
  LabDevice(
    kind: LabDeviceKind.mist,
    name: '분무',
    isOn: false,
    statusLabel: '오늘 3회',
    todayRuntimeMinutes: 1,
  ),
  LabDevice(
    kind: LabDeviceKind.led,
    name: 'LED',
    isOn: false,
    statusLabel: '19:30 소등',
    todayRuntimeMinutes: 618,
  ),
  LabDevice(
    kind: LabDeviceKind.fan,
    name: '팬',
    isOn: true,
    statusLabel: '켜짐 · 환기 중',
    todayRuntimeMinutes: 84,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// 타임라인 8건
// ─────────────────────────────────────────────────────────────────────────────

enum LabEventKind { heater, mist, led, fan, activity, report }

class LabTimelineEvent {
  const LabTimelineEvent({
    required this.at,
    required this.kind,
    required this.title,
    this.detail,
  });

  final DateTime at;
  final LabEventKind kind;
  final String title;
  final String? detail;
}

/// 최근 이벤트 8건 — 최신이 먼저.
final List<LabTimelineEvent> kLabTimeline = List.unmodifiable([
  LabTimelineEvent(
    at: DateTime(2026, 8, 13, 0, 41),
    kind: LabEventKind.activity,
    title: '활동 감지',
    detail: '유목 위 이동',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 23, 58),
    kind: LabEventKind.mist,
    title: '분무 완료',
    detail: '2초 · 습도 58% → 66%',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 22, 41),
    kind: LabEventKind.activity,
    title: '첫 활동 감지',
    detail: '은신처에서 나옴',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 21, 47),
    kind: LabEventKind.heater,
    title: '히터 켜짐',
    detail: '온도 25.1℃ 도달',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 19, 30),
    kind: LabEventKind.led,
    title: 'LED 소등',
    detail: '일몰 루틴',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 16, 45),
    kind: LabEventKind.fan,
    title: '팬 가동',
    detail: '10분 환기',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 14, 20),
    kind: LabEventKind.mist,
    title: '분무 완료',
    detail: '1초',
  ),
  LabTimelineEvent(
    at: DateTime(2026, 8, 12, 7, 0),
    kind: LabEventKind.report,
    title: '어젯밤 리포트 생성',
    detail: '활동 31회 · 안정',
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────
// 밤 활동량 (22:00 ~ 06:00)
// ─────────────────────────────────────────────────────────────────────────────

class LabNightActivity {
  const LabNightActivity({
    required this.start,
    required this.end,
    required this.activityCount,
    required this.mistCount,
    required this.maxTemp,
    required this.firstDetectedAt,
    required this.peakAt,
  });

  final DateTime start;
  final DateTime end;
  final int activityCount;
  final int mistCount;
  final double maxTemp;
  final DateTime firstDetectedAt;
  final DateTime peakAt;

  /// 밤 진행률(0~1). [kLabNow] 기준.
  double get progress {
    final total = end.difference(start).inMinutes;
    final done = kLabNow.difference(start).inMinutes;
    return (done / total).clamp(0.0, 1.0);
  }
}

final LabNightActivity kLabNightActivity = LabNightActivity(
  start: DateTime(2026, 8, 12, 22),
  end: DateTime(2026, 8, 13, 6),
  activityCount: 27,
  mistCount: 3,
  maxTemp: 27.8,
  firstDetectedAt: DateTime(2026, 8, 12, 22, 41),
  peakAt: DateTime(2026, 8, 13, 0, 40),
);

// ─────────────────────────────────────────────────────────────────────────────
// 공용 포맷 헬퍼 (intl 미사용 — 랩 전용 단순 포맷)
// ─────────────────────────────────────────────────────────────────────────────

String labHm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
