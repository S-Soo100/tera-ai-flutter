import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/schedule.dart';

/// 서버가 실제로 내려주는 모양(`APP_TIMER_MIST.md` §2.1 응답 예시).
Map<String, dynamic> _daily() => {
      'id': 's1',
      'device_id': 'd1',
      'action': 'mist',
      'payload': {'duration_ms': 2000},
      'kind': 'daily',
      'time_of_day': '08:00:00',
      'days_of_week': null,
      'enabled': true,
      'next_run_at': '2026-08-11T23:00:00+00:00',
      'last_run_at': null,
    };

Map<String, dynamic> _weekly() => {
      'id': 's2',
      'device_id': 'd1',
      'action': 'fan_toggle',
      'kind': 'weekly',
      'time_of_day': '20:00:00',
      'days_of_week': [1, 3, 5],
      'enabled': false,
      'next_run_at': '2026-08-12T11:00:00+00:00',
    };

void main() {
  group('Schedule 역직렬화', () {
    test('매일 예약을 읽는다', () {
      final s = Schedule.fromJson(_daily());
      expect(s.id, 's1');
      expect(s.action, ScheduleAction.mist);
      expect(s.kind, ScheduleKind.daily);
      expect(s.hour, 8);
      expect(s.minute, 0);
      expect(s.daysOfWeek, isEmpty);
      expect(s.enabled, isTrue);
      expect(s.payload?['duration_ms'], 2000);
    });

    test('요일 예약을 읽는다 — 1=월 … 7=일', () {
      final s = Schedule.fromJson(_weekly());
      expect(s.kind, ScheduleKind.weekly);
      expect(s.daysOfWeek, [1, 3, 5]);
      expect(s.enabled, isFalse);
    });

    test('서버는 초까지 붙여 보내지만 초는 안 쓴다', () {
      // `time_of_day` 가 "08:00:00" 으로 온다. "08:00" 입력과 같은 값이어야
      // 목록·수정 화면이 어긋나지 않는다.
      expect(Schedule.fromJson(_daily()).hhmm, '08:00');
    });

    test('next_run_at은 UTC로 온다 — 로컬로 바꿔 보관한다', () {
      // 문서 예제는 `.toUtc().add(Duration(hours: 9))` 인데, 결과가 isUtc인 채
      // +9가 되어 이후 toLocal()을 또 부르면 이중 변환된다. toLocal() 하나면
      // 끝이고, 그래야 기기 타임존이 KST가 아닐 때도 맞다.
      final s = Schedule.fromJson(_daily());
      expect(s.nextRunAt!.isUtc, isFalse);
      expect(
        s.nextRunAt!.toUtc(),
        DateTime.utc(2026, 8, 11, 23),
      );
    });

    test('알 수 없는 action은 unknown — 목록에서 통째로 터지지 않는다', () {
      final s = Schedule.fromJson({..._daily(), 'action': 'teleport'});
      expect(s.action, ScheduleAction.unknown);
    });
  });

  group('Schedule 직렬화', () {
    test('매일 예약 본문에는 days_of_week를 넣지 않는다', () {
      final body = Schedule.createBody(
        action: ScheduleAction.mist,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
        payload: const {'duration_ms': 2000},
      );
      expect(body['kind'], 'daily');
      expect(body['time_of_day'], '08:00');
      expect(body.containsKey('days_of_week'), isFalse);
      expect(body['payload'], {'duration_ms': 2000});
    });

    test('요일 예약은 days_of_week를 정렬해 넣는다', () {
      final body = Schedule.createBody(
        action: ScheduleAction.fanToggle,
        kind: ScheduleKind.weekly,
        hour: 20,
        minute: 5,
        daysOfWeek: const [5, 1, 3],
      );
      expect(body['time_of_day'], '20:05');
      expect(body['days_of_week'], [1, 3, 5]);
    });

    test('payload가 없으면 키 자체를 빼다 — null을 보내면 서버가 거부할 수 있다', () {
      final body = Schedule.createBody(
        action: ScheduleAction.fanToggle,
        kind: ScheduleKind.daily,
        hour: 7,
        minute: 30,
        daysOfWeek: const [],
      );
      expect(body.containsKey('payload'), isFalse);
    });
  });

  group('요일 검증', () {
    test('weekly인데 요일이 비면 만들 수 없다 — 서버가 400을 준다', () {
      expect(
        Schedule.validate(kind: ScheduleKind.weekly, daysOfWeek: const []),
        isFalse,
      );
      expect(
        Schedule.validate(kind: ScheduleKind.weekly, daysOfWeek: const [7]),
        isTrue,
      );
    });

    test('daily는 요일이 없어도 된다', () {
      expect(
        Schedule.validate(kind: ScheduleKind.daily, daysOfWeek: const []),
        isTrue,
      );
    });
  });

  group('ScheduleAction', () {
    test('고를 수 있는 것 — mist + 절대 상태 명령 (2026-08-14 화이트리스트 확장)', () {
      expect(
        ScheduleAction.selectable.map((a) => a.wire).toList(),
        ['mist', 'fan_on', 'fan_off', 'heater_on', 'heater_off', 'led_on', 'led_off'],
      );
    });

    test('unknown은 고를 수 없다 — 서버가 받지 않는 값이다', () {
      expect(ScheduleAction.selectable, isNot(contains(ScheduleAction.unknown)));
    });

    test('toggle 계열은 못 고른다 — 무인 실행에서 상태가 어긋나면 반대로 동작한다', () {
      for (final a in [
        ScheduleAction.fanToggle,
        ScheduleAction.heaterToggle,
        ScheduleAction.relayToggle,
      ]) {
        expect(ScheduleAction.selectable, isNot(contains(a)), reason: a.wire);
      }
    });

    test('toggle 예약이 섞여 와도 unknown으로 뭉개지 않는다 — 기존 데이터·웹 콘솔', () {
      expect(ScheduleAction.fromWire('fan_toggle'), ScheduleAction.fanToggle);
      expect(ScheduleAction.fromWire('heater_off'), ScheduleAction.heaterOff);
    });

    test('mist만 payload가 필수다', () {
      expect(ScheduleAction.mist.requiresDuration, isTrue);
      expect(ScheduleAction.fanOn.requiresDuration, isFalse);
    });

    test('끄기 계열 판별 + 켜기 짝', () {
      expect(ScheduleAction.heaterOff.isOffAction, isTrue);
      expect(ScheduleAction.heaterOff.onCounterpart, ScheduleAction.heaterOn);
      expect(ScheduleAction.heaterOn.isOffAction, isFalse);
      expect(ScheduleAction.heaterOn.onCounterpart, isNull);
      expect(ScheduleAction.mist.isOffAction, isFalse);
    });
  });

  group('pair_id (2026-08-18 회신 §3)', () {
    Schedule s(String id, ScheduleAction a, {String? pair}) => Schedule(
          id: id,
          deviceId: 'd',
          action: a,
          payload: null,
          kind: ScheduleKind.daily,
          hour: 8,
          minute: 0,
          daysOfWeek: const [],
          enabled: true,
          pairId: pair,
          nextRunAt: null,
          lastRunAt: null,
        );

    test('createBody: pairId가 있으면 pair_id, 없으면 키 생략', () {
      final with_ = Schedule.createBody(
        action: ScheduleAction.fanOn,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
        pairId: 'p1',
      );
      expect(with_['pair_id'], 'p1');
      final without = Schedule.createBody(
        action: ScheduleAction.mist,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
      );
      expect(without.containsKey('pair_id'), isFalse);
    });

    test('fromJson: pair_id 읽음, 없으면 null', () {
      expect(
        Schedule.fromJson({'id': 'a', 'action': 'fan_on', 'pair_id': 'p1'})
            .pairId,
        'p1',
      );
      expect(Schedule.fromJson({'id': 'a', 'action': 'mist'}).pairId, isNull);
    });

    test('group: 같은 pair_id의 on/off → SchedulePair 1개, 나머지는 낱개', () {
      final rows = Schedule.group([
        s('x', ScheduleAction.mist),
        s('on', ScheduleAction.heaterOn, pair: 'p1'),
        s('y', ScheduleAction.ledOn),
        s('off', ScheduleAction.heaterOff, pair: 'p1'),
      ]);
      expect(rows, hasLength(3));
      expect(rows[0], isA<Schedule>());
      expect(rows[1], isA<SchedulePair>());
      final p = rows[1] as SchedulePair;
      expect(p.on.id, 'on');
      expect(p.off.id, 'off');
      expect(p.pairId, 'p1');
      expect(rows[2], isA<Schedule>());
    });

    test('group: 짝이 한쪽만 남았거나 둘 다 켜기면 묶지 않는다', () {
      final lone = Schedule.group([s('on', ScheduleAction.fanOn, pair: 'p1')]);
      expect(lone.single, isA<Schedule>());
      final twoOn = Schedule.group([
        s('a', ScheduleAction.fanOn, pair: 'p2'),
        s('b', ScheduleAction.fanOn, pair: 'p2'),
      ]);
      expect(twoOn, hasLength(2));
      expect(twoOn.every((r) => r is Schedule), isTrue);
    });

    test('SchedulePair.enabled는 둘 다 켜져 있을 때만', () {
      final p = SchedulePair(
        on: s('on', ScheduleAction.fanOn, pair: 'p'),
        off: s('off', ScheduleAction.fanOff, pair: 'p').copyWith(enabled: false),
      );
      expect(p.enabled, isFalse);
    });
  });

  group('구간 예약 자정 넘김', () {
    test('종료가 시작보다 이르거나 같으면 자정 넘김', () {
      expect(
          Schedule.spanCrossesMidnight(
              startHour: 22, startMinute: 0, endHour: 6, endMinute: 0),
          isTrue);
      expect(
          Schedule.spanCrossesMidnight(
              startHour: 8, startMinute: 0, endHour: 22, endMinute: 0),
          isFalse);
      // 같은 시각 = 24시간 구간으로 해석(다음날 종료).
      expect(
          Schedule.spanCrossesMidnight(
              startHour: 8, startMinute: 0, endHour: 8, endMinute: 0),
          isTrue);
    });

    test('weekly + 자정 넘김이면 off 요일을 하루 민다 — 일요일은 월요일로', () {
      expect(
        Schedule.offLegDays(
            kind: ScheduleKind.weekly,
            daysOfWeek: const [1, 3, 7],
            crossesMidnight: true),
        [1, 2, 4], // 월→화, 수→목, 일→월(정렬됨)
      );
    });

    test('daily거나 자정을 안 넘으면 그대로', () {
      expect(
        Schedule.offLegDays(
            kind: ScheduleKind.daily,
            daysOfWeek: const [],
            crossesMidnight: true),
        isEmpty,
      );
      expect(
        Schedule.offLegDays(
            kind: ScheduleKind.weekly,
            daysOfWeek: const [1, 3],
            crossesMidnight: false),
        [1, 3],
      );
    });
  });

  group('ScheduleGuard', () {
    test('fromJson/toJson 왕복', () {
      final g = ScheduleGuard.fromJson(
          {'type': 'skip_when_humidity_above', 'value': 70, 'enabled': true});
      expect(g, isNotNull);
      expect(g!.type, GuardType.humidityAbove);
      expect(g.value, 70.0);
      expect(g.toJson(),
          {'type': 'skip_when_humidity_above', 'value': 70.0, 'enabled': true});
    });

    test('모르는 type은 null — 한 예약의 가드 때문에 목록이 통째로 비지 않게', () {
      expect(
          ScheduleGuard.fromJson({'type': 'stop_when_temp_above', 'value': 30}),
          isNull);
      expect(ScheduleGuard.fromJson('garbage'), isNull);
      expect(ScheduleGuard.fromJson(null), isNull);
    });

    test('enabled 기본값은 true', () {
      final g = ScheduleGuard.fromJson(
          {'type': 'skip_when_temp_below', 'value': 20});
      expect(g!.enabled, isTrue);
    });

    test('습도/온도 구분 — 편집기 단위 표기가 갈린다', () {
      expect(GuardType.humidityAbove.isHumidity, isTrue);
      expect(GuardType.humidityBelow.isHumidity, isTrue);
      expect(GuardType.tempAbove.isHumidity, isFalse);
      expect(GuardType.tempBelow.isHumidity, isFalse);
    });

    test('Schedule.fromJson이 guard를 읽는다', () {
      final s = Schedule.fromJson({
        ..._daily(),
        'guard': {'type': 'skip_when_humidity_above', 'value': 70, 'enabled': true},
      });
      expect(s.guard, isNotNull);
      expect(s.guard!.type, GuardType.humidityAbove);
    });

    test('guard가 없으면 null — 기존 예약이 그대로 읽힌다', () {
      expect(Schedule.fromJson(_daily()).guard, isNull);
    });

    test('createBody는 guard가 있을 때만 키를 싣는다', () {
      final without = Schedule.createBody(
        action: ScheduleAction.mist,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
      );
      expect(without.containsKey('guard'), isFalse);

      final withGuard = Schedule.createBody(
        action: ScheduleAction.mist,
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
        guard: const ScheduleGuard(
            type: GuardType.humidityAbove, value: 70, enabled: true),
      );
      expect(withGuard['guard'],
          {'type': 'skip_when_humidity_above', 'value': 70.0, 'enabled': true});
    });
  });
}
