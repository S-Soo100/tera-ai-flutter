import '../../my_cage/domain/telemetry_bucket.dart';
import '../../../shared/domain/chart_window.dart';

/// 30분 버킷을 **하루 단위**로 접는다 (기획안 §4.3.1 주간 = 포인트 1일).
///
/// 경계는 **07:00**이다(§3.1). 자정으로 끊으면 야행성 개체의 밤 하나가 두 날로
/// 쪼개져, 같은 밤을 일간 화면과 주간 화면이 서로 다른 날로 말하게 된다.
///
/// ⚠️ **0은 버린다.** `telemetry_30m`의 0은 센서 오프라인 센티넬이지 실측이
/// 아니다(DHT22는 0℃/0%를 낼 수 없다. 메모리 `project_telemetry_zero_sentinel`).
/// 평균에 넣으면 그 날 온도가 반토막 난다.
///
/// 값이 하나도 없는 날도 **자리를 지운 채로 남긴다** — 목록에서 빼면 7일 축이
/// 6칸으로 줄어 날짜가 밀린다.
List<TelemetryBucket> rollupByDay(
  List<TelemetryBucket> buckets, {
  required ChartWindow window,
}) {
  final days = [
    for (var i = 0; i < window.tickCount; i++)
      DateTime(window.start.year, window.start.month, window.start.day + i,
          window.start.hour),
  ];

  final acc = {for (final d in days) d: _DayAcc()};

  for (final b in buckets) {
    final day = _dayOf(b.bucket, days);
    if (day == null) continue;
    final a = acc[day]!;
    // 온도·습도를 따로 센다. 한쪽 센서만 죽은 구간에서 나머지까지 버리지 않는다.
    a.temp.add(avg: b.tAvg, min: b.tMin, max: b.tMax);
    a.humid.add(avg: b.hAvg, min: b.hMin, max: b.hMax);
  }

  return [
    for (final d in days)
      if (acc[d]! case final a)
        TelemetryBucket(
          bucket: d,
          sampleCount: a.temp.count + a.humid.count,
          tAvg: a.temp.mean,
          tMin: a.temp.min,
          tMax: a.temp.max,
          hAvg: a.humid.mean,
          hMin: a.humid.min,
          hMax: a.humid.max,
        ),
  ];
}

/// [at]이 속한 하루의 시작. 창 밖이면 null.
DateTime? _dayOf(DateTime at, List<DateTime> days) {
  for (var i = days.length - 1; i >= 0; i--) {
    if (!at.isBefore(days[i])) {
      // 마지막 날 다음 경계를 넘어선 값(= 창 밖 미래)은 버린다.
      final nextEnd = DateTime(
          days[i].year, days[i].month, days[i].day + 1, days[i].hour);
      return at.isBefore(nextEnd) ? days[i] : null;
    }
  }
  return null;
}

class _DayAcc {
  final temp = _MetricAcc();
  final humid = _MetricAcc();
}

class _MetricAcc {
  double _sum = 0;
  int count = 0;
  double? min;
  double? max;

  double? get mean => count == 0 ? null : _sum / count;

  /// 평균은 [avg]로, 극값은 그 버킷의 [min]·[max]로 센다 — 평균들의 극값을
  /// 쓰면 그 날의 진짜 최고·최저가 30분 평균에 눌려 좁아진다.
  void add({double? avg, double? min, double? max}) {
    if (avg != null && avg > 0) {
      _sum += avg;
      count++;
    }
    if (min != null && min > 0) {
      this.min = this.min == null || min < this.min! ? min : this.min;
    }
    if (max != null && max > 0) {
      this.max = this.max == null || max > this.max! ? max : this.max;
    }
  }
}
