import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/hourly_env_slot.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivnanaut/shared/domain/actuator_marker.dart';

final _now = DateTime(2026, 8, 12, 15, 43);

TelemetryBucket _b(DateTime at, double? t) => TelemetryBucket(
      bucket: at,
      sampleCount: 1,
      tAvg: t,
      tMin: t,
      tMax: t,
      hAvg: null,
      hMin: null,
      hMax: null,
    );

void main() {
  group('칸 배열', () {
    test('지금 + 3시간 간격 8칸 = 9칸, 왼쪽이 지금이고 과거로 간다', () {
      final s =
          HourlyEnvSlots.build(now: _now, buckets: const [], markers: const []);
      expect(s, hasLength(9));
      expect(s.first.isNow, isTrue);
      expect(s.first.at, _now);
      expect(s[1].at, DateTime(2026, 8, 12, 12));
      expect(s[2].at, DateTime(2026, 8, 12, 9));
      expect(s.last.at, DateTime(2026, 8, 11, 15));
      expect(s.where((x) => x.isNow), hasLength(1));
    });

    test('과거 칸은 정각이다 — 자정을 넘어도 달력이 정규화한다', () {
      final s = HourlyEnvSlots.build(
          now: DateTime(2026, 8, 12, 1, 20),
          buckets: const [],
          markers: const []);
      expect(s[1].at, DateTime(2026, 8, 11, 22));
      expect(s[1].at.minute, 0);
    });
  });

  group('온도', () {
    test('그 정각 버킷의 평균을 쓴다', () {
      final s = HourlyEnvSlots.build(
        now: _now,
        buckets: [_b(DateTime(2026, 8, 12, 12), 24.4)],
        markers: const [],
      );
      expect(s[1].temp, 24.4);
      expect(s[1].tempRounded, 24);
    });

    test('30분 오차 안의 가장 가까운 버킷을 고른다, 그 밖이면 null', () {
      final s = HourlyEnvSlots.build(
        now: _now,
        buckets: [
          _b(DateTime(2026, 8, 12, 12, 30), 25),
          _b(DateTime(2026, 8, 12, 8), 30), // 9시 칸에서 1시간 — 밖
        ],
        markers: const [],
      );
      expect(s[1].temp, 25);
      expect(s[2].temp, isNull);
    });

    test('지금 칸은 실시간 값이 우선이고, 없으면 마지막 버킷', () {
      final withLive = HourlyEnvSlots.build(
        now: _now,
        buckets: [_b(DateTime(2026, 8, 12, 15, 30), 26)],
        markers: const [],
        currentTemp: 27.2,
      );
      expect(withLive.first.temp, 27.2);

      final noLive = HourlyEnvSlots.build(
        now: _now,
        buckets: [_b(DateTime(2026, 8, 12, 15, 30), 26)],
        markers: const [],
      );
      expect(noLive.first.temp, 26);
    });

    test('0은 센서 오프라인 센티넬 — 값으로 안 쓴다', () {
      final s = HourlyEnvSlots.build(
        now: _now,
        buckets: [_b(DateTime(2026, 8, 12, 12), 0)],
        markers: const [],
      );
      expect(s[1].temp, isNull);
    });
  });

  group('기기 동작', () {
    test('마커는 인접 칸 중점으로 나눠 정확히 한 칸에만 속한다', () {
      // 12시 칸 구간: [10:30, 13:51:30) — 위 경계는 지금(15:43)과의 중점.
      // 13:51은 12시, 13:52는 지금 칸.
      final s = HourlyEnvSlots.build(
        now: _now,
        buckets: const [],
        markers: [
          ActuatorMarker(
              kind: MarkerKind.mist, at: DateTime(2026, 8, 12, 13, 51)),
          ActuatorMarker(
              kind: MarkerKind.heater, at: DateTime(2026, 8, 12, 13, 52)),
          ActuatorMarker(
              kind: MarkerKind.fan, at: DateTime(2026, 8, 12, 10, 29)),
        ],
      );
      expect(s[1].kinds, {MarkerKind.mist});
      expect(s.first.kinds, {MarkerKind.heater});
      expect(s[2].kinds, {MarkerKind.fan});
      final total = s.fold<int>(0, (n, x) => n + x.kinds.length);
      expect(total, 3);
    });

    test('동작이 없으면 빈 집합', () {
      final s =
          HourlyEnvSlots.build(now: _now, buckets: const [], markers: const []);
      expect(s.every((x) => x.kinds.isEmpty), isTrue);
    });
  });
}
