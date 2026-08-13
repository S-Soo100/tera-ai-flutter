/// 디자인 랩 공용 더미 데이터.
///
/// **3안이 전부 같은 값을 쓴다** — 스타일 말고는 아무것도 다르지 않아야
/// 비교가 공정하다. 시각은 고정해 두어 화면을 다시 열어도 같은 그림이 나온다.
/// 실 provider·Repository는 건드리지 않는다(랩 격리).
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

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
// 주간 온습도 7일 (통계 탭용 — 일평균 + 최고/최저)
// ─────────────────────────────────────────────────────────────────────────────

class LabDayEnv {
  const LabDayEnv({
    required this.day,
    required this.tempAvg,
    required this.tempMax,
    required this.tempMin,
    required this.humidAvg,
  });

  final DateTime day;
  final double tempAvg;
  final double tempMax;
  final double tempMin;
  final double humidAvg;

  /// 크레스티드 게코 기준 29℃ 이상은 위험 신호 — 상태 배지 판정용.
  bool get isWarning => tempMax >= 28.5;
}

/// [kLabNow] 기준 지난 7일 — 오래된 날이 먼저. 손으로 적은 결정적 값.
/// 8/10 하루만 히터 과열 기미(28.9℃)를 넣어 "주의" 상태를 볼 수 있게 했다.
final List<LabDayEnv> kLabWeekEnv = List.unmodifiable([
  LabDayEnv(
      day: DateTime(2026, 8, 7),
      tempAvg: 26.1, tempMax: 27.9, tempMin: 24.2, humidAvg: 63),
  LabDayEnv(
      day: DateTime(2026, 8, 8),
      tempAvg: 26.4, tempMax: 28.2, tempMin: 24.5, humidAvg: 61),
  LabDayEnv(
      day: DateTime(2026, 8, 9),
      tempAvg: 25.8, tempMax: 27.5, tempMin: 23.9, humidAvg: 66),
  LabDayEnv(
      day: DateTime(2026, 8, 10),
      tempAvg: 27.0, tempMax: 28.9, tempMin: 25.1, humidAvg: 58),
  LabDayEnv(
      day: DateTime(2026, 8, 11),
      tempAvg: 26.6, tempMax: 28.1, tempMin: 24.8, humidAvg: 60),
  LabDayEnv(
      day: DateTime(2026, 8, 12),
      tempAvg: 26.2, tempMax: 27.8, tempMin: 24.4, humidAvg: 64),
  LabDayEnv(
      day: DateTime(2026, 8, 13),
      tempAvg: 26.5, tempMax: 28.0, tempMin: 24.6, humidAvg: 62),
]);

double get kLabWeekTempAvg =>
    kLabWeekEnv.map((d) => d.tempAvg).reduce((a, b) => a + b) /
    kLabWeekEnv.length;
double get kLabWeekHumidAvg =>
    kLabWeekEnv.map((d) => d.humidAvg).reduce((a, b) => a + b) /
    kLabWeekEnv.length;

const List<String> kLabWeekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// '목 8/13' 식 요일+날짜 라벨.
String labDayLabel(DateTime d) =>
    '${kLabWeekdayKo[d.weekday - 1]} ${d.month}/${d.day}';

// ─────────────────────────────────────────────────────────────────────────────
// 개체 3마리 (마이크레 탭용)
// ─────────────────────────────────────────────────────────────────────────────

class LabPet {
  const LabPet({
    required this.name,
    required this.species,
    required this.morph,
    required this.hatchedAt,
    required this.weightG,
    required this.avatarColor,
  });

  final String name;
  final String species;
  final String morph;
  final DateTime hatchedAt;
  final double weightG;

  /// 썸네일 대체 컬러 — 사진 없이 아바타 원으로 쓴다.
  final Color avatarColor;

  /// 해칭 후 경과일. [kLabNow] 기준이라 결정적.
  int get ageDays => kLabNow.difference(hatchedAt).inDays;
}

/// B·C 공용 개체 3마리 — 값은 전부 손으로 적은 더미.
final List<LabPet> kLabPets = List.unmodifiable([
  LabPet(
    name: '모카',
    species: '크레스티드 게코',
    morph: '릴리 화이트',
    hatchedAt: DateTime(2024, 5, 2),
    weightG: 38.5,
    avatarColor: Color(0xFFC98A5B),
  ),
  LabPet(
    name: '라떼',
    species: '크레스티드 게코',
    morph: '할리퀸',
    hatchedAt: DateTime(2025, 1, 18),
    weightG: 21.2,
    avatarColor: Color(0xFFE8C170),
  ),
  LabPet(
    name: '탄이',
    species: '레오파드 게코',
    morph: '탠저린',
    hatchedAt: DateTime(2023, 9, 27),
    weightG: 62.0,
    avatarColor: Color(0xFFD97742),
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────
// 어젯밤 리포트 수치 (마이크레 탭용)
// ─────────────────────────────────────────────────────────────────────────────

class LabNightReport {
  const LabNightReport({
    required this.activeMinutes,
    required this.restMinutes,
    required this.mistCount,
    required this.peakAt,
  });

  final int activeMinutes;
  final int restMinutes;
  final int mistCount;
  final DateTime peakAt;

  int get totalMinutes => activeMinutes + restMinutes;

  /// 활동 비율(0~1) — 진행 바·링 재사용.
  double get activeRatio =>
      totalMinutes == 0 ? 0 : activeMinutes / totalMinutes;
}

/// 어젯밤(8/12 22:00 ~ 8/13 06:00) 리포트 — [kLabNightActivity]와 같은 밤.
final LabNightReport kLabNightReport = LabNightReport(
  activeMinutes: 142,
  restMinutes: 338,
  mistCount: 3,
  peakAt: DateTime(2026, 8, 13, 0, 40),
);

// ─────────────────────────────────────────────────────────────────────────────
// 게시글 6건 (커뮤니티 탭용)
// ─────────────────────────────────────────────────────────────────────────────

enum LabPostCategory { notice, qna, free, wiki }

class LabPost {
  const LabPost({
    required this.category,
    required this.title,
    required this.author,
    required this.commentCount,
    required this.at,
  });

  final LabPostCategory category;
  final String title;
  final String author;
  final int commentCount;
  final DateTime at;

  String get categoryLabel => switch (category) {
        LabPostCategory.notice => '공지',
        LabPostCategory.qna => '질문답변',
        LabPostCategory.free => '자유',
        LabPostCategory.wiki => '사육위키',
      };
}

/// 게시글 6건 — 최신이 먼저. 오늘(8/13) 2건 + 어제(8/12) 4건.
final List<LabPost> kLabPosts = List.unmodifiable([
  LabPost(
    category: LabPostCategory.qna,
    title: '크레 새벽에 벽만 타는데 정상인가요?',
    author: '게코초보',
    commentCount: 7,
    at: DateTime(2026, 8, 13, 0, 52),
  ),
  LabPost(
    category: LabPostCategory.free,
    title: '탈피 직후 발색 미쳤다… 릴리 화이트 자랑',
    author: '모카집사',
    commentCount: 12,
    at: DateTime(2026, 8, 13, 0, 5),
  ),
  LabPost(
    category: LabPostCategory.notice,
    title: '8월 정기 점검 안내 (8/20 02:00~04:00)',
    author: '비바나트',
    commentCount: 3,
    at: DateTime(2026, 8, 12, 21, 40),
  ),
  LabPost(
    category: LabPostCategory.wiki,
    title: '여름철 사육장 습도 관리 체크리스트',
    author: '파충류연구소',
    commentCount: 18,
    at: DateTime(2026, 8, 12, 18, 12),
  ),
  LabPost(
    category: LabPostCategory.qna,
    title: '레오파드 게코 먹이 거부 3일째, 온도 문제일까요?',
    author: '탄이아빠',
    commentCount: 9,
    at: DateTime(2026, 8, 12, 14, 33),
  ),
  LabPost(
    category: LabPostCategory.free,
    title: '자동 분무 루틴 이렇게 쓰니까 편하네요',
    author: '습도장인',
    commentCount: 5,
    at: DateTime(2026, 8, 12, 9, 21),
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────
// 공용 포맷 헬퍼 (intl 미사용 — 랩 전용 단순 포맷)
// ─────────────────────────────────────────────────────────────────────────────

String labHm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// '오늘'/'어제'/'M월 D일' — [kLabNow] 기준.
String labDaySection(DateTime t) {
  final today = DateTime(kLabNow.year, kLabNow.month, kLabNow.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return '오늘';
  if (day == today.subtract(const Duration(days: 1))) return '어제';
  return '${day.month}월 ${day.day}일';
}
