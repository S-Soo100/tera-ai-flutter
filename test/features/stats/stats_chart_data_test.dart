import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/features/stats/domain/stats_chart_data.dart';

final _from = DateTime(2026, 8, 4, 19);
final _to = DateTime(2026, 8, 5, 7); // 12시간

TelemetryBucket _b(DateTime at, {double? t, double? h}) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: t,
      tMin: t,
      tMax: t,
      hAvg: h,
      hMin: h,
      hMax: h,
    );

StatsChartData _data(List<TelemetryBucket> buckets) =>
    StatsChartData.from(buckets, from: _from, to: _to);

void main() {
  group('축 산출', () {
    test('온·습도 축이 각자 범위로 잡힌다', () {
      final d = _data([
        _b(_from, t: 23.5, h: 58),
        _b(_to, t: 26, h: 72),
      ]);
      // 축은 데이터를 담되 지나치게 넓히지 않는다. 개수(6)는 고정,
      // 칸 크기는 데이터 폭에 맞춰 정해진다 — `axis_bounds_test` 참조.
      expect(d.tempAxis!.min, lessThanOrEqualTo(23.5));
      expect(d.tempAxis!.max, greaterThanOrEqualTo(26));
      expect(d.tempAxis!.ticks, hasLength(6));
      expect(d.humidAxis!.min, lessThanOrEqualTo(58));
      expect(d.humidAxis!.max, greaterThanOrEqualTo(72));
      expect(d.humidAxis!.ticks, hasLength(6));
    });

    test('한쪽 지표만 있으면 다른 축은 null', () {
      final d = _data([_b(_from, t: 24), _b(_to, t: 26)]);
      expect(d.tempAxis, isNotNull);
      expect(d.humidAxis, isNull);
      expect(d.humidPoints, isEmpty);
    });
  });

  group('x 정규화 — 시간 위치', () {
    test('구간 시작은 0, 끝은 1', () {
      final d = _data([_b(_from, t: 24), _b(_to, t: 26)]);
      expect(d.tempPoints.first.x, 0);
      expect(d.tempPoints.last.x, 1);
    });

    test('중간 지점은 비율대로', () {
      // 19:00 + 3시간 = 22:00 → 3/12 = 0.25
      final d = _data([
        _b(_from, t: 24),
        _b(DateTime(2026, 8, 4, 22), t: 25),
        _b(_to, t: 26),
      ]);
      expect(d.tempPoints[1].x, closeTo(0.25, 1e-9));
    });

    test('구간 밖 버킷은 버린다 — 차트 밖으로 선이 삐져나가면 안 된다', () {
      final d = _data([
        _b(DateTime(2026, 8, 4, 12), t: 24), // from 이전
        _b(DateTime(2026, 8, 4, 20), t: 25),
        _b(DateTime(2026, 8, 5, 9), t: 26), // to 이후
      ]);
      expect(d.tempPoints, hasLength(1));
    });

    test('시간 순서가 뒤섞여 들어와도 정렬된다', () {
      final d = _data([
        _b(_to, t: 26),
        _b(_from, t: 24),
        _b(DateTime(2026, 8, 4, 22), t: 25),
      ]);
      expect(d.tempPoints.map((p) => p.x).toList(),
          [0, closeTo(0.25, 1e-9), 1]);
    });
  });

  group('y 정규화', () {
    test('축 min은 0, max는 1', () {
      final d = _data([_b(_from, t: 20), _b(_to, t: 30)]);
      expect(d.tempPoints.first.y, 0);
      expect(d.tempPoints.last.y, 1);
    });
  });

  group('0 센티넬 처리 — telemetry_30m의 0은 센서 오프라인이다', () {
    test('0인 점은 선에서 빠진다 — 바닥까지 내리꽂히면 안 된다', () {
      final d = _data([
        _b(_from, t: 24),
        _b(DateTime(2026, 8, 4, 22), t: 0),
        _b(_to, t: 26),
      ]);
      expect(d.tempPoints, hasLength(2));
      expect(d.tempPoints.every((p) => p.y >= 0 && p.y <= 1), isTrue);
    });

    test('0이 축 계산도 오염시키지 않는다', () {
      final d = _data([
        _b(_from, t: 0),
        _b(DateTime(2026, 8, 4, 22), t: 24),
        _b(_to, t: 26),
      ]);
      expect(d.tempAxis!.min, greaterThan(0)); // 0까지 늘어나지 않는다
    });
  });

  group('hasData', () {
    test('빈 버킷은 false', () {
      expect(_data(const []).hasData, isFalse);
    });

    test('점이 하나뿐이면 false — 선으로 보이지 않는다', () {
      expect(_data([_b(_from, t: 24)]).hasData, isFalse);
    });

    test('점 둘이면 true', () {
      expect(_data([_b(_from, t: 24), _b(_to, t: 26)]).hasData, isTrue);
    });

    test('전부 0이면 false', () {
      expect(_data([_b(_from, t: 0), _b(_to, t: 0)]).hasData, isFalse);
    });
  });

  group('스크러버 조회', () {
    // 19:00~07:00 12시간. 22:00 = 0.25, 01:00 = 0.5
    List<TelemetryBucket> sample() => [
          _b(_from, t: 24, h: 60),
          _b(DateTime(2026, 8, 4, 22), t: 26, h: 65),
          _b(DateTime(2026, 8, 5, 1), t: 28, h: 70),
          _b(_to, t: 25, h: 55),
        ];

    test('가장 가까운 데이터 지점으로 맞춘다 — 선과 점이 어긋나면 안 된다', () {
      final d = _data(sample());
      expect(d.snap(0.26), closeTo(0.25, 1e-9));
      expect(d.snap(0.49), closeTo(0.5, 1e-9));
    });

    test('맞춘 자리의 실제 온·습도를 돌려준다', () {
      final d = _data(sample());
      expect(d.tempAt(0.25), closeTo(26, 1e-9));
      expect(d.humidAt(0.25), closeTo(65, 1e-9));
    });

    test('정규화 값이 아니라 사람이 읽는 단위다', () {
      final d = _data(sample());
      expect(d.tempAt(0.5), closeTo(28, 1e-9));
      expect(d.humidAt(0.5), closeTo(70, 1e-9));
    });

    test('한쪽 지표만 있으면 다른 쪽은 null', () {
      final d = _data([_b(_from, t: 24), _b(_to, t: 26)]);
      expect(d.tempAt(0), isNotNull);
      expect(d.humidAt(0), isNull);
    });

    test('데이터가 없으면 snap도 null — 스크러버를 띄우지 않는다', () {
      expect(_data(const []).snap(0.5), isNull);
    });

    test('0 센티넬 자리는 건너뛰고 옆 실측을 집는다', () {
      final d = _data([
        _b(_from, t: 24),
        _b(DateTime(2026, 8, 4, 22), t: 0), // 센서 오프라인
        _b(_to, t: 26),
      ]);
      expect(d.snap(0.25), isNot(closeTo(0.25, 1e-9)));
      expect(d.tempAt(0.25), isNotNull);
    });

    test('시각은 구간을 비율로 나눈 값', () {
      final d = _data(sample());
      expect(d.timeAt(0), _from);
      expect(d.timeAt(1), _to);
      expect(d.timeAt(0.25), DateTime(2026, 8, 4, 22));
    });

    test('구간 밖 x를 넣어도 시각이 구간을 벗어나지 않는다', () {
      final d = _data(sample());
      expect(d.timeAt(-0.5), _from);
      expect(d.timeAt(1.5), _to);
    });
  });

  group('폭이 0인 구간', () {
    test('from == to면 점을 만들지 않는다 — 0으로 나누지 않는다', () {
      final d = StatsChartData.from(
        [_b(_from, t: 24)],
        from: _from,
        to: _from,
      );
      expect(d.tempPoints, isEmpty);
      expect(d.hasData, isFalse);
    });
  });
}
