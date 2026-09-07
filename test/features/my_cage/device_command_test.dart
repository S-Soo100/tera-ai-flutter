import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/device_command.dart';

/// 실DB(`commands` 576행, 2026-06-08~08-11)에서 실제로 관측된 값들.
///
/// 앱은 오랫동안 `rejected_locked` / `rejected_unknown_action` 처럼 **접두사가
/// 붙은 값만** 알고 있었는데, 제어 디바이스(terra-iot-nano) 펌웨어는 접두사
/// 없이 보낸다. 그 결과 36건이 전부 `unknown`으로 유실됐고 히터 잠금 안내
/// 분기는 한 번도 실행된 적이 없었다.
const _observedInDb = {
  'ok': CommandResult.ok,
  'unknown_action': CommandResult.unknownAction,
  'error': CommandResult.error,
  'locked': CommandResult.locked,
};

/// 펌웨어(`command_dispatch.c`) 어휘 8종 중 아직 DB에 안 나타난 것들.
/// 백엔드 회신(2026-08-12)이 밝힌 전체 목록 기준.
const _documentedOnly = {
  'busy': CommandResult.busy,
  'bad_request': CommandResult.badRequest,
  // ⚠️ nano는 `expired`/`duplicate`로 보낸다. 카메라 펌웨어의
  // `rejected_ttl_expired`/`rejected_duplicate_msg_id`와 어휘가 다르다 —
  // 접두사만 떼는 것으로는 안 모인다.
  'expired': CommandResult.ttlExpired,
  'duplicate': CommandResult.duplicateMsgId,
};

void main() {
  group('CommandResult 파싱', () {
    test('실DB에서 관측된 값은 전부 해석된다', () {
      _observedInDb.forEach((wire, expected) {
        expect(CommandResultWire.fromWire(wire), expected, reason: wire);
      });
    });

    test('문서에만 있는 값도 해석된다 — 나오는 날 조용히 유실되면 안 된다', () {
      _documentedOnly.forEach((wire, expected) {
        expect(CommandResultWire.fromWire(wire), expected, reason: wire);
      });
    });

    test('카메라 펌웨어의 rejected_ 접두사형도 같은 뜻으로 본다', () {
      expect(CommandResultWire.fromWire('rejected_locked'),
          CommandResult.locked);
      expect(CommandResultWire.fromWire('rejected_unknown_action'),
          CommandResult.unknownAction);
      expect(CommandResultWire.fromWire('rejected_ttl_expired'),
          CommandResult.ttlExpired);
      expect(CommandResultWire.fromWire('rejected_duplicate_msg_id'),
          CommandResult.duplicateMsgId);
    });

    test('접두사 유무가 같은 결과를 준다 — 두 펌웨어가 갈라지면 안 된다', () {
      for (final k in ['locked', 'unknown_action', 'ttl_expired']) {
        expect(
          CommandResultWire.fromWire(k),
          CommandResultWire.fromWire('rejected_$k'),
          reason: k,
        );
      }
    });

    test('짧은 어휘와 긴 어휘가 같은 뜻이다 — nano는 expired, 카메라는 rejected_ttl_expired', () {
      expect(CommandResultWire.fromWire('expired'),
          CommandResultWire.fromWire('rejected_ttl_expired'));
      expect(CommandResultWire.fromWire('duplicate'),
          CommandResultWire.fromWire('rejected_duplicate_msg_id'));
    });

    test('결과 없음(null)은 unknown이 아니라 null이다', () {
      // sent/pending 은 아직 결과가 없는 것(실DB 21건)이지, 해석에 실패한 게
      // 아니다. 둘을 같은 값으로 두면 작동 이력에서 구분할 수 없다.
      expect(CommandResultWire.fromWire(null), isNull);
    });

    test('처음 보는 값만 unknown이다', () {
      expect(CommandResultWire.fromWire('teapot'), CommandResult.unknown);
    });
  });

  group('CommandAction 파싱', () {
    test('mist는 알려진 액션이다 — unknown이면 이력에서 사라진다', () {
      expect(CommandActionWire.fromWire('mist'), CommandAction.mist);
      expect(CommandAction.mist.toWire(), 'mist');
    });

    test('절대 상태 명령을 안다 — 예약·구간 제어의 재료다', () {
      const pairs = {
        'fan_on': CommandAction.fanOn,
        'fan_off': CommandAction.fanOff,
        'heater_on': CommandAction.heaterOn,
        'heater_off': CommandAction.heaterOff,
        'relay_on': CommandAction.relayOn,
        'relay_off': CommandAction.relayOff,
      };
      pairs.forEach((wire, action) {
        expect(CommandActionWire.fromWire(wire), action, reason: wire);
        expect(action.toWire(), wire);
      });
    });

    test('기존 액션은 그대로다', () {
      expect(CommandActionWire.fromWire('relay_toggle'),
          CommandAction.relayToggle);
      expect(CommandActionWire.fromWire('led_on'), CommandAction.ledOn);
    });
  });

  group('DeviceCommand 역직렬화', () {
    test('mist 명령의 duration_ms를 payload로 읽는다', () {
      final c = DeviceCommand.fromJson({
        'id': 'c1',
        'device_id': 'd1',
        'issued_by': 'u1',
        'action': 'mist',
        'payload': {'duration_ms': 2000},
        'status': 'acked',
        'result': 'ok',
        'issued_at': '2026-08-11T07:41:16.990874+00:00',
      });
      expect(c.action, CommandAction.mist);
      expect(c.payload?['duration_ms'], 2000);
      expect(c.result, CommandResult.ok);
    });

    test('아직 결과가 없는 명령은 result가 null이다', () {
      final c = DeviceCommand.fromJson({
        'id': 'c2',
        'device_id': 'd1',
        'issued_by': 'u1',
        'action': 'fan_toggle',
        'status': 'sent',
      });
      expect(c.status, CommandStatus.sent);
      expect(c.result, isNull);
    });
  });
}
