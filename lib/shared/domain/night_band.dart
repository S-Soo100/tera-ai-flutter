/// 시간축 차트 위에 깔리는 **밤 띠**.
///
/// 기획안 §3.1 ②: 활동 집계 창은 `22:00 ~ 06:00`이다. 이 앱이 다루는 개체가
/// 야행성이라 **밤이 곧 "우리 애가 사는 시간"**이고, 활동 수치는 이 창에서만 센다.
///
/// 그 규칙을 시각 언어로 끌어올린 것이 밤 띠다. 홈 차트·통계 차트 어디서든
/// 같은 구간이 어둡게 깔려, 사용자가 "지금 보는 그래프의 어디가 밤인지"를
/// 읽지 않고 알아본다. **장식이 아니라 집계 규칙의 표시**이므로, 집계 창이
/// 바뀌면 이 상수도 같이 바뀌어야 한다.
library;

/// 밤 시작 시각. 기획안 §3.1 ②.
const int kNightStartHour = 22;

/// 밤 종료 시각. 기획안 §3.1 ②.
const int kNightEndHour = 6;

/// 차트 구간 내 밤 한 토막. 좌표는 0(왼쪽 끝)~1(오른쪽 끝) 비율.
typedef NightBand = ({double start, double end});

/// [from]~[to]에 걸치는 밤 구간들을 차트 좌표로 돌려준다.
///
/// 구간 밖으로 삐져나온 부분은 잘라내고, 잘라낸 뒤 폭이 0이 된 토막은 버린다
/// — 보이지 않는 띠를 그려봐야 렌더 비용만 든다.
List<NightBand> nightBands({required DateTime from, required DateTime to}) {
  final span = to.difference(from).inMicroseconds;
  if (span <= 0) return const [];

  final out = <NightBand>[];

  // 밤은 자정을 넘으므로 "시작한 날" 기준으로 훑는다. from 하루 전부터 시작해야
  // from이 밤 한복판인 경우(예: 새벽 2시)의 밤도 잡힌다.
  var day = DateTime(from.year, from.month, from.day)
      .subtract(const Duration(days: 1));
  final lastDay = DateTime(to.year, to.month, to.day);

  while (!day.isAfter(lastDay)) {
    final nightStart = DateTime(day.year, day.month, day.day, kNightStartHour);
    final nightEnd = DateTime(day.year, day.month, day.day)
        .add(const Duration(days: 1))
        .copyWithHour(kNightEndHour);

    final s = nightStart.isBefore(from) ? from : nightStart;
    final e = nightEnd.isAfter(to) ? to : nightEnd;

    if (e.isAfter(s)) {
      out.add((
        start: s.difference(from).inMicroseconds / span,
        end: e.difference(from).inMicroseconds / span,
      ));
    }
    day = day.add(const Duration(days: 1));
  }
  return out;
}

extension on DateTime {
  DateTime copyWithHour(int hour) => DateTime(year, month, day, hour);
}
