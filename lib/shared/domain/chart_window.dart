/// 통계 탭 24시 차트의 **표시 창**.
///
/// 조회 구간과 다르다 — 데이터는 "지금까지"만 있지만, 화면은 **다음 6시간
/// 눈금까지** 자리를 미리 잡는다. 그 남는 꼬리가 Figma의 회색 밴드
/// (`docs/figma-final-design-transcript.md` §3.1 "구간 밴드")이고, 뜻은
/// **아직 안 지난 시간**이다.
///
/// 창은 6시간마다 통째로 6시간 전진한다. 하루 단위로 고정하면 경계를 넘긴
/// 직후에 화면 대부분이 회색이 되어(선 5분 + 회색 23시간 55분) 차트가 무너진다.
/// 전진 방식은 **항상 24시간치 데이터가 차 있고 리셋이 없다.**
///
/// [DayWindow]와 혼용하지 말 것 — 저 쪽은 하루 경계(07:00)와 어젯밤 리포트를
/// 위한 개념이고, 이 클래스는 오직 차트 프레임을 위한 것이다.
/// X축 눈금을 무엇으로 읽는가.
///
/// 24시간 창은 시각(`오후 10시`), 주간 창은 날짜(`8/6`)다. 주간에 오전/오후를
/// 붙이면 눈금이 전부 `오전 7시`가 되어 아무것도 구분하지 못한다.
enum ChartTickFormat { hour, date }

/// X축 눈금 하나.
class ChartTimeTick {
  /// 눈금이 가리키는 시각 (항상 [stepHours]의 배수 정각).
  final DateTime at;

  /// 차트 구간 내 위치. 0 = 왼쪽 끝, 1 = 오른쪽 끝.
  final double position;

  const ChartTimeTick({required this.at, required this.position});

  /// 오전이면 true. 12시간 표기의 오전/오후 판정.
  bool get isAm => at.hour < 12;

  /// 12시간 표기 시각. 0시·12시는 모두 **12**로 읽는다
  /// (자정 = 오전 12시, 정오 = 오후 12시).
  int get hour12 => at.hour % 12 == 0 ? 12 : at.hour % 12;
}

class ChartWindow {
  /// 창 시작 = [end] - 24시간. x = 0.
  final DateTime start;

  /// 창 끝 = 지금 이후 첫 눈금. x = 1. **미래다.**
  final DateTime end;

  /// 창을 계산한 시각. 회색 밴드가 여기서 시작한다.
  final DateTime now;

  /// 눈금을 시각으로 읽을지 날짜로 읽을지.
  final ChartTickFormat format;

  /// 눈금 개수. 오른쪽 끝은 세지 않는다.
  final int tickCount;

  const ChartWindow._({
    required this.start,
    required this.end,
    required this.now,
    required this.format,
    required this.tickCount,
  });

  /// 눈금 간격(시간). Figma 기준 6시간 4개.
  static const int stepHours = 6;

  /// 눈금 위상. Figma가 `22 / 04 / 10 / 16`시를 그렸다 —
  /// 시계 경계(`00/06/12/18`)가 아니라 **6으로 나눈 나머지가 4**인 시각이다.
  static const int tickPhaseHour = 4;

  /// 24시간 창 길이.
  static const Duration span = Duration(hours: 24);

  /// 하루 경계. 기획안 §3.1 — 야행성이라 자정이 아니라 07:00이다.
  static const int dayBoundaryHour = 7;

  /// 주간 창 길이(일).
  static const int weeklyDays = 7;

  factory ChartWindow.of(DateTime now) {
    final end = nextTickAfter(now);
    return ChartWindow._(
      start: end.subtract(span),
      end: end,
      now: now,
      format: ChartTickFormat.hour,
      tickCount: span.inHours ~/ stepHours,
    );
  }

  /// 최근 **완결된** 7일 창 (기획안 §4.3.1 주간).
  ///
  /// **눈금이 하루 경계(07:00)에 선다.** 자정으로 끊으면 밤 활동이 두 칸으로
  /// 쪼개져, 같은 밤을 일간 화면과 주간 화면이 서로 다른 날로 말하게 된다.
  ///
  /// 오른쪽 끝은 **직전 07:00 경계**다 — 진행 중인 오늘을 넣으면 샘플 한둘의
  /// 부분일 평균이 진짜 일 평균처럼 그려져 끝에서 절벽이 생긴다(2026-08-14).
  /// 일간 집계라 "몇 시간 늦은 값"이어도 잘못된 값보다 낫다.
  /// 창이 전부 과거이므로 미도래 회색 밴드는 없다(elapsed = 1).
  factory ChartWindow.weekly(DateTime now) {
    final end = lastDayBoundaryOnOrBefore(now);
    return ChartWindow._(
      // 달력으로 빼야 서머타임에도 "07시 정각"이 유지된다.
      start: DateTime(end.year, end.month, end.day - weeklyDays, end.hour),
      end: end,
      now: now,
      format: ChartTickFormat.date,
      tickCount: weeklyDays,
    );
  }

  /// 홈 "이번 주" 행 목록용 창 — **오늘(진행 중) + 지난 6완결일** = 7일.
  ///
  /// [ChartWindow.weekly]와 다르다. 저쪽은 절벽을 피하려고 오늘을 뺀 완결
  /// 7일이고, 여기는 애플 날씨 "오늘" 행처럼 **지금까지의 오늘**이 맨 위에
  /// 있어야 한다. 부분일이어도 그날 min/max는 "지금까지 겪은 값"이라 뜻이 선다.
  ///
  /// 끝은 **오늘의 다음 07:00 경계(미래)**다 — 그래야 [rollupByDay]가 오늘
  /// 자리를 만들고, [queryEnd]가 `now`로 잘린다.
  factory ChartWindow.homeWeekly(DateTime now) {
    final todayStart = lastDayBoundaryOnOrBefore(now);
    return ChartWindow._(
      start: DateTime(todayStart.year, todayStart.month,
          todayStart.day - (weeklyDays - 1), todayStart.hour),
      end: DateTime(todayStart.year, todayStart.month, todayStart.day + 1,
          todayStart.hour),
      now: now,
      format: ChartTickFormat.date,
      tickCount: weeklyDays,
    );
  }

  /// [now] **이전**(정각이면 그 시각)의 마지막 하루 경계(07:00).
  static DateTime lastDayBoundaryOnOrBefore(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, dayBoundaryHour);
    if (today.isAfter(now)) {
      return DateTime(now.year, now.month, now.day - 1, dayBoundaryHour);
    }
    return today;
  }

  /// [now] **이후**의 첫 눈금 시각.
  ///
  /// 정각에 딱 걸리면 다음 눈금으로 넘긴다 — 같은 시각을 창 끝으로 삼으면
  /// 밴드 폭이 0이 되었다가 다음 순간 25%로 튀는 대신, 넘긴 즉시 25%에서
  /// 줄기 시작한다(= 프레임이 전진했다는 뜻).
  static DateTime nextTickAfter(DateTime now) {
    // 정수 나눗셈이 0 쪽으로 잘리므로 새벽(시 < 4)에도 h = 4가 나온다.
    var h =
        ((now.hour - tickPhaseHour) ~/ stepHours) * stepHours + tickPhaseHour;
    // 시(hour) 오버플로는 DateTime 생성자가 달력으로 정규화해준다 —
    // Duration 덧셈과 달리 서머타임에도 "몇 시 정각"이 유지된다.
    var t = DateTime(now.year, now.month, now.day, h);
    while (!t.isAfter(now)) {
      h += stepHours;
      t = DateTime(now.year, now.month, now.day, h);
    }
    return t;
  }

  /// 데이터 **조회**의 끝. 표시 창의 끝([end])과 다르다:
  /// - 진행 중인 창(일간): [end]가 미래라 없는 시간을 물어볼 이유가 없다 → [now]
  /// - 완결된 창(주간): [now]까지 당기면 진행 중인 오늘 몫이 딸려와
  ///   rollup이 도로 버린다 → [end]
  ///
  /// 조회부([fetchChartBuckets])가 이 값을 쓰므로 호출자가 창마다 끝을
  /// 고를 필요가 없다 — 고르게 두면 한쪽만 고쳐진 채 남는다.
  DateTime get queryEnd => end.isBefore(now) ? end : now;

  /// 흘러간 비율(0~1). 회색 밴드는 여기서 오른쪽 끝까지다.
  double get elapsed {
    final total = end.difference(start).inMicroseconds;
    if (total <= 0) return 1;
    return (now.difference(start).inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// X축 눈금. 창 시작부터 고른 간격이며 **오른쪽 끝(= [end])은 뺀다** —
  /// Figma도 왼쪽 끝부터만 그렸고, 끝에 라벨을 붙이면 밴드 위에 겹친다.
  ///
  /// 간격을 Duration 덧셈이 아니라 **달력 필드**로 넘긴다. 서머타임이 끼면
  /// `+6시간`은 5시나 7시로 밀리지만, `hour + 6`은 언제나 정각을 지킨다.
  List<ChartTimeTick> get ticks {
    final total = end.difference(start).inMicroseconds;
    if (total <= 0) return const [];
    return [
      for (var i = 0; i < tickCount; i++)
        if (_tickAt(i) case final at)
          ChartTimeTick(
            at: at,
            position: at.difference(start).inMicroseconds / total,
          ),
    ];
  }

  DateTime _tickAt(int i) => switch (format) {
        ChartTickFormat.hour => DateTime(
            start.year, start.month, start.day, start.hour + i * stepHours),
        ChartTickFormat.date =>
          DateTime(start.year, start.month, start.day + i, start.hour),
      };
}
