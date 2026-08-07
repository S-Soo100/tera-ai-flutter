/// 최근 24시간 차트의 X축 시간 눈금.
///
/// 배경: Figma 피드백 "24시간 온습도 추이에 시간이 언제인지 표기 필요"
/// (`docs/figma-final-design-transcript.md` §2.1 사육장).
///
/// **눈금은 [ActuatorMarker]와 같은 구간(실제 데이터 구간)을 기준으로 놓아야 한다.**
/// Sparkline이 가진 데이터를 폭 100%로 늘려 그리기 때문에, 차트 *요청* 구간
/// (전날 19:00~현재)으로 계산하면 선과 눈금이 어긋난다.
///
/// Figma는 6시간 간격 4개(`오후 10시`/`오전4시`/`오전10시`/`오후 4시`)로 그렸다.
/// 여기서는 간격(6시간)만 따르고 위치는 **시계 경계(00·06·12·18시)에 고정**한다 —
/// 차트 구간의 끝이 "현재 시각"이라 매 순간 움직이는데, 구간 시작에 눈금을 앵커하면
/// 라벨이 1분마다 바뀌어 읽을 수 없게 된다.
library;

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

/// 눈금 간격(시간). Figma 기준 6시간.
const int chartTickStepHours = 6;

/// [from]~[to] 구간에 걸치는 6시간 경계 눈금을 순서대로 돌려준다.
///
/// 양 끝은 포함이다(경계에 정확히 걸리면 position 0 또는 1).
/// 구간이 비었거나 뒤집혀 있으면 빈 목록 — 0으로 나누지 않기 위함.
List<ChartTimeTick> chartTimeTicks({
  required DateTime from,
  required DateTime to,
  int stepHours = chartTickStepHours,
}) {
  final span = to.difference(from).inMicroseconds;
  if (span <= 0) return const [];

  // from 이상인 첫 경계로 올림. Duration 덧셈이 아니라 DateTime 생성자로
  // 올리는 이유는 시(hour) 오버플로를 달력이 알아서 정규화해주기 때문이다.
  final flooredHour = (from.hour ~/ stepHours) * stepHours;
  var cursor = DateTime(from.year, from.month, from.day, flooredHour);
  if (cursor.isBefore(from)) {
    cursor = DateTime(from.year, from.month, from.day, flooredHour + stepHours);
  }

  final ticks = <ChartTimeTick>[];
  while (!cursor.isAfter(to)) {
    ticks.add(ChartTimeTick(
      at: cursor,
      position: cursor.difference(from).inMicroseconds / span,
    ));
    cursor = DateTime(
      cursor.year,
      cursor.month,
      cursor.day,
      cursor.hour + stepHours,
    );
  }
  return ticks;
}
