import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_bucket.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';

Map<String, dynamic> row(
  String action,
  DateTime localAt, {
  String status = 'acked',
}) {
  return {
    'id': '${action}_${localAt.millisecondsSinceEpoch}',
    'action': action,
    'status': status,
    'result': 'ok',
    // 실 DB처럼 UTC 문자열로 준다 — 파서가 .toLocal()을 하는지 검증.
    'issued_at': localAt.toUtc().toIso8601String(),
  };
}

TelemetryBucket bucket(DateTime at, {double? t, double? h}) {
  return TelemetryBucket(
    bucket: at,
    sampleCount: 600,
    tAvg: t,
    tMin: t,
    tMax: t,
    hAvg: h,
    hMin: h,
    hMax: h,
  );
}

void main() {
  test('이어 보낸 분무(3초×3, 5초 간격)는 한 줄 9초로 합친다', () {
    final at = DateTime(2026, 9, 25, 9);
    Map<String, dynamic> mist(int sec, int ms) =>
        row('mist', at.add(Duration(seconds: sec)))
          ..['payload'] = {'duration_ms': ms};
    final log = buildControlLog(commandRows: [
      mist(0, 3000),
      mist(5, 3000),
      mist(10, 3000),
      // 한참 뒤 다른 분무는 따로.
      mist(120, 3000),
    ], buckets: []);
    expect(log, hasLength(2));
    expect(log.first.at, at);
    expect(log.first.sprayMs, 9000);
    expect(log.last.sprayMs, 3000);
  });

  test('서버가 이은 10초(5초 + 약 7초 뒤 5초)도 한 줄로', () {
    final at = DateTime(2026, 9, 25, 9);
    final log = buildControlLog(commandRows: [
      row('mist', at)..['payload'] = {'duration_ms': 10000},
      row('mist', at.add(const Duration(milliseconds: 7200)))
        ..['payload'] = {'duration_ms': 5000}
        ..['source'] = 'timer',
    ], buckets: []);
    // 서버 이음 행(source=timer)은 원래 10초 요청의 나머지 — 더하지 않는다.
    expect(log, hasLength(1));
    expect(log.single.sprayMs, 10000);
  });

  test('acked failure is not rendered as successful operation', () {
    final at = DateTime(2026, 9, 3);
    final failed = row('fan_on', at)..['result'] = 'error';
    expect(buildControlLog(commandRows: [failed], buckets: []), isEmpty);
  });
  test('fan and cooling on-off pairs remain separate', () {
    final at = DateTime(2026, 9, 3);
    final log = buildControlLog(commandRows: [
      row('fan_on', at),
      row('fan2_off', at.add(const Duration(minutes: 1)))
    ], buckets: [
      bucket(at, t: 25, h: 60)
    ]);
    expect(log.last.kind, MarkerKind.cooling);
    expect(log.last.deltaTemperature, isNull);
  });
  test('prior-day on pairs before visible-day filtering', () {
    final start = DateTime(2026, 9, 3);
    final log = buildControlLog(
      commandRows: [
        row('fan_on', start.subtract(const Duration(minutes: 20))),
        row('fan_off', start.add(const Duration(minutes: 20)))
      ],
      buckets: [
        bucket(start.subtract(const Duration(minutes: 30)), t: 30, h: 60),
        bucket(start.add(const Duration(minutes: 30)), t: 25, h: 62)
      ],
      visibleFrom: start,
      visibleTo: start.add(const Duration(days: 1)),
    );
    expect(log, hasLength(1));
    expect(log.single.state, ControlLogState.off);
    expect(log.single.deltaTemperature, -5);
  });
  test('invalid or missing humidity does not discard valid temperature', () {
    final at = DateTime(2026, 9, 3, 1);
    final log = buildControlLog(
        commandRows: [row('fan_off', at)],
        buckets: [bucket(at, t: 25, h: double.infinity)]);
    expect(log.single.temperature, 25);
    expect(log.single.humidity, isNull);
  });
  test('ambiguous toggle breaks an earlier on-off pairing', () {
    final at = DateTime(2026, 9, 3, 1);
    final log = buildControlLog(commandRows: [
      row('fan_on', at),
      row('fan_toggle', at.add(const Duration(minutes: 1))),
      row('fan_off', at.add(const Duration(minutes: 2)))
    ], buckets: [
      bucket(at, t: 25, h: 60)
    ]);
    expect(log.last.deltaTemperature, isNull);
  });

  group('buildControlLog — 상태 매핑', () {
    test('on/off/mist/toggle을 상태로 읽는다', () {
      final at = DateTime(2026, 9, 2, 10);
      final log = buildControlLog(
        commandRows: [
          row('fan_on', at),
          row('heater_off', at.add(const Duration(minutes: 1))),
          row('mist', at.add(const Duration(minutes: 2))),
          row('led_toggle', at.add(const Duration(minutes: 3))),
        ],
        buckets: const [],
      );
      expect(log.length, 4);
      expect(log[0].kind, MarkerKind.fan);
      expect(log[0].state, ControlLogState.on);
      expect(log[1].kind, MarkerKind.heater);
      expect(log[1].state, ControlLogState.off);
      expect(log[2].kind, MarkerKind.mist);
      expect(log[2].state, ControlLogState.ran);
      expect(log[3].kind, MarkerKind.led);
      expect(log[3].state, ControlLogState.ran);
    });

    test('relay_on/off는 절대 명령이라 방향을 안다 (kind=mist)', () {
      final at = DateTime(2026, 9, 2, 10);
      final log = buildControlLog(
        commandRows: [
          row('relay_on', at),
          row('relay_off', at.add(const Duration(minutes: 5))),
        ],
        buckets: const [],
      );
      expect(log[0].state, ControlLogState.on);
      expect(log[1].state, ControlLogState.off);
    });

    test('acked가 아닌 행·모르는 action·lcd는 버린다', () {
      final at = DateTime(2026, 9, 2, 10);
      final log = buildControlLog(
        commandRows: [
          row('fan_on', at, status: 'pending'),
          row('fan_on', at, status: 'rejected'),
          row('lcd_bitmap', at),
          row('unknown_action', at),
        ],
        buckets: const [],
      );
      expect(log, isEmpty);
    });

    test('issued_at UTC 문자열은 로컬 시각으로 변환한다', () {
      final localAt = DateTime(2026, 9, 2, 23, 30);
      final log = buildControlLog(
        commandRows: [row('fan_on', localAt)],
        buckets: const [],
      );
      expect(log.single.at, localAt);
      expect(log.single.at.isUtc, isFalse);
    });

    test('시간 오름차순으로 정렬한다', () {
      final at = DateTime(2026, 9, 2, 10);
      final log = buildControlLog(
        commandRows: [
          row('fan_off', at.add(const Duration(hours: 2))),
          row('fan_on', at),
        ],
        buckets: const [],
      );
      expect(log[0].state, ControlLogState.on);
      expect(log[1].state, ControlLogState.off);
    });
  });

  group('buildControlLog — 온습도 매칭', () {
    test('가장 가까운 버킷의 tAvg/hAvg를 붙인다', () {
      final at = DateTime(2026, 9, 2, 10, 10);
      final log = buildControlLog(
        commandRows: [row('fan_on', at)],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 28.5, h: 62.0), // 10분 이격
          bucket(DateTime(2026, 9, 2, 11), t: 30.0, h: 55.0), // 50분 이격
        ],
      );
      expect(log.single.temperature, 28.5);
      expect(log.single.humidity, 62.0);
    });

    test('30분 초과 이격이면 null', () {
      final at = DateTime(2026, 9, 2, 10);
      final log = buildControlLog(
        commandRows: [row('fan_on', at)],
        buckets: [bucket(DateTime(2026, 9, 2, 10, 31), t: 28.5, h: 62.0)],
      );
      expect(log.single.temperature, isNull);
      expect(log.single.humidity, isNull);
    });

    test('0값 센티넬 버킷은 매칭 후보에서 뺀다', () {
      final at = DateTime(2026, 9, 2, 10, 10);
      final log = buildControlLog(
        commandRows: [row('fan_on', at)],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 0.0, h: 0.0), // 오프라인
          bucket(DateTime(2026, 9, 2, 10, 30), t: 29.0, h: 58.0),
        ],
      );
      expect(log.single.temperature, 29.0);
      expect(log.single.humidity, 58.0);
    });

    test('UTC 버킷 스탬프와 로컬 명령 시각을 같은 축에서 비교한다', () {
      final at = DateTime(2026, 9, 2, 10, 10);
      final log = buildControlLog(
        commandRows: [row('fan_on', at)],
        buckets: [bucket(DateTime(2026, 9, 2, 10).toUtc(), t: 27.0, h: 60.0)],
      );
      expect(log.single.temperature, 27.0);
    });
  });

  group('buildControlLog — 델타', () {
    test('off는 같은 kind의 직전 on과의 차이를 기록한다 (off쪽에만)', () {
      final on = DateTime(2026, 9, 2, 10);
      final off = DateTime(2026, 9, 2, 12);
      final log = buildControlLog(
        commandRows: [row('fan_on', on), row('fan_off', off)],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 30.0, h: 50.0),
          bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0),
        ],
      );
      expect(log[0].deltaTemperature, isNull); // on 로우엔 델타 없음
      expect(log[1].deltaTemperature, -5.0);
      expect(log[1].deltaHumidity, 2.0);
    });

    test('다른 kind의 on과는 짝짓지 않는다', () {
      final log = buildControlLog(
        commandRows: [
          row('heater_on', DateTime(2026, 9, 2, 10)),
          row('fan_off', DateTime(2026, 9, 2, 12)),
        ],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 30.0, h: 50.0),
          bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0),
        ],
      );
      expect(log[1].deltaTemperature, isNull);
    });

    test('짝 없는 off는 델타 없음', () {
      final log = buildControlLog(
        commandRows: [row('fan_off', DateTime(2026, 9, 2, 12))],
        buckets: [bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0)],
      );
      expect(log.single.deltaTemperature, isNull);
      expect(log.single.temperature, 25.0); // 시점 온습도는 있다
    });

    test('on 하나에 off 둘 — 두 번째 off는 짝이 소진돼 델타 없음', () {
      final log = buildControlLog(
        commandRows: [
          row('fan_on', DateTime(2026, 9, 2, 10)),
          row('fan_off', DateTime(2026, 9, 2, 11)),
          row('fan_off', DateTime(2026, 9, 2, 12)),
        ],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 30.0, h: 50.0),
          bucket(DateTime(2026, 9, 2, 11), t: 28.0, h: 51.0),
          bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0),
        ],
      );
      expect(log[1].deltaTemperature, -2.0);
      expect(log[2].deltaTemperature, isNull);
    });

    test('ran(토글·분무)은 델타가 없고 on 짝도 깨뜨리지 않는다', () {
      final log = buildControlLog(
        commandRows: [
          row('fan_on', DateTime(2026, 9, 2, 10)),
          row('mist', DateTime(2026, 9, 2, 11)),
          row('fan_off', DateTime(2026, 9, 2, 12)),
        ],
        buckets: [
          bucket(DateTime(2026, 9, 2, 10), t: 30.0, h: 50.0),
          bucket(DateTime(2026, 9, 2, 11), t: 28.0, h: 51.0),
          bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0),
        ],
      );
      expect(log[1].state, ControlLogState.ran);
      expect(log[1].deltaTemperature, isNull);
      expect(log[2].deltaTemperature, -5.0); // fan_on(10시)과 짝
    });

    test('시점 온습도가 한쪽이라도 null이면 그 지표 델타도 null', () {
      final log = buildControlLog(
        commandRows: [
          row('fan_on', DateTime(2026, 9, 2, 10)),
          row('fan_off', DateTime(2026, 9, 2, 12)),
        ],
        buckets: [
          // off 시각 근처에만 버킷 — on 시점 온습도가 null.
          bucket(DateTime(2026, 9, 2, 12), t: 25.0, h: 52.0),
        ],
      );
      expect(log[1].temperature, 25.0);
      expect(log[1].deltaTemperature, isNull);
      expect(log[1].deltaHumidity, isNull);
    });
  });
}
