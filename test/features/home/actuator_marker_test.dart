import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/actuator_marker.dart';

Map<String, dynamic> _cmd(String action, String issuedAt,
        {String status = 'acked'}) =>
    {
      'id': 'c-$action-$issuedAt',
      'action': action,
      'status': status,
      'issued_at': issuedAt,
    };

void main() {
  group('ActuatorMarker.fromCommands', () {
    test('acked 명령만 마커가 된다 — 실행 안 된 명령을 동작으로 그리면 안 됨', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('fan_toggle', '2026-08-05T10:00:00Z'),
        _cmd('heater_toggle', '2026-08-05T11:00:00Z', status: 'rejected'),
        _cmd('led_on', '2026-08-05T12:00:00Z', status: 'pending'),
      ]);
      expect(m, hasLength(1));
      expect(m.single.kind, MarkerKind.fan);
    });

    test('action → 마커 종류 매핑', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('relay_toggle', '2026-08-05T09:00:00Z'),
        _cmd('fan_toggle', '2026-08-05T10:00:00Z'),
        _cmd('heater_toggle', '2026-08-05T11:00:00Z'),
        _cmd('led_on', '2026-08-05T12:00:00Z'),
      ]);
      expect(m.map((e) => e.kind).toList(), [
        MarkerKind.mist,
        MarkerKind.fan,
        MarkerKind.heater,
        MarkerKind.led,
      ]);
    });

    test('알 수 없는 action은 버린다', () {
      final m = ActuatorMarker.fromCommands(
          [_cmd('token_rotate', '2026-08-05T10:00:00Z')]);
      expect(m, isEmpty);
    });

    test('issued_at이 없으면 버린다 — 시점 없는 마커는 못 찍는다', () {
      final m = ActuatorMarker.fromCommands([
        {'id': 'c1', 'action': 'fan_toggle', 'status': 'acked'},
      ]);
      expect(m, isEmpty);
    });

    test('시간순 정렬', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('fan_toggle', '2026-08-05T12:00:00Z'),
        _cmd('relay_toggle', '2026-08-05T09:00:00Z'),
      ]);
      expect(m.first.kind, MarkerKind.mist);
    });
  });

  group('ActuatorMarker.positionIn', () {
    test('구간 중앙이면 0.5', () {
      final m = ActuatorMarker(
          kind: MarkerKind.fan, at: DateTime.utc(2026, 8, 5, 12));
      final p = m.positionIn(
        start: DateTime.utc(2026, 8, 5, 6),
        end: DateTime.utc(2026, 8, 5, 18),
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('구간 밖이면 null — 차트 밖에 찍히지 않는다', () {
      final m = ActuatorMarker(
          kind: MarkerKind.fan, at: DateTime.utc(2026, 8, 5, 20));
      expect(
        m.positionIn(
          start: DateTime.utc(2026, 8, 5, 6),
          end: DateTime.utc(2026, 8, 5, 18),
        ),
        isNull,
      );
    });

    test('길이 0 구간이면 null — 0으로 나누지 않는다', () {
      final t = DateTime.utc(2026, 8, 5, 12);
      final m = ActuatorMarker(kind: MarkerKind.fan, at: t);
      expect(m.positionIn(start: t, end: t), isNull);
    });
  });
}
