// terra-server `commands` 테이블 매핑.

// ── CommandAction ─────────────────────────────────────────────────────────────

enum CommandAction {
  /// 물분무. `payload.duration_ms`(1000/2000/3000)만큼 켜고 **펌웨어가 자동으로
  /// 끈다** — OFF 명령을 따로 보내면 안 된다(`APP_TIMER_MIST.md` §1).
  mist,
  relayToggle,
  fanToggle,
  heaterToggle,
  heaterClear,
  ledOn,
  ledOff,
  tokenRotate,
  unknown,
}

extension CommandActionWire on CommandAction {
  String toWire() {
    switch (this) {
      case CommandAction.mist:
        return 'mist';
      case CommandAction.relayToggle:
        return 'relay_toggle';
      case CommandAction.fanToggle:
        return 'fan_toggle';
      case CommandAction.heaterToggle:
        return 'heater_toggle';
      case CommandAction.heaterClear:
        return 'heater_clear';
      case CommandAction.ledOn:
        return 'led_on';
      case CommandAction.ledOff:
        return 'led_off';
      case CommandAction.tokenRotate:
        return 'token_rotate';
      case CommandAction.unknown:
        return 'unknown';
    }
  }

  static CommandAction fromWire(String? v) {
    switch (v) {
      case 'mist':
        return CommandAction.mist;
      case 'relay_toggle':
        return CommandAction.relayToggle;
      case 'fan_toggle':
        return CommandAction.fanToggle;
      case 'heater_toggle':
        return CommandAction.heaterToggle;
      case 'heater_clear':
        return CommandAction.heaterClear;
      case 'led_on':
        return CommandAction.ledOn;
      case 'led_off':
        return CommandAction.ledOff;
      case 'token_rotate':
        return CommandAction.tokenRotate;
      default:
        return CommandAction.unknown;
    }
  }
}

// ── CommandStatus ─────────────────────────────────────────────────────────────

enum CommandStatus {
  pending,
  sent,
  acked,
  rejected,
  expired,
  unknown,
}

extension CommandStatusWire on CommandStatus {
  static CommandStatus fromWire(String? v) {
    switch (v) {
      case 'pending':
        return CommandStatus.pending;
      case 'sent':
        return CommandStatus.sent;
      case 'acked':
        return CommandStatus.acked;
      case 'rejected':
        return CommandStatus.rejected;
      case 'expired':
        return CommandStatus.expired;
      default:
        return CommandStatus.unknown;
    }
  }
}

// ── CommandResult ─────────────────────────────────────────────────────────────

/// 명령 실행 결과.
///
/// **두 펌웨어가 같은 뜻을 다른 문자열로 보낸다.** 제어 디바이스
/// (terra-iot-nano)는 `locked`, 카메라는 `rejected_locked` 식이다
/// (`APP_TIMER_MIST.md` §1.3 주의). 그래서 이름에서 `rejected` 를 뺐다 —
/// 접두사형만 알고 있던 탓에 실DB 36건(`unknown_action` 17 · `error` 15 ·
/// `locked` 4)이 전부 [unknown]으로 유실됐고, 히터 잠금 안내 분기는 한 번도
/// 실행된 적이 없었다.
enum CommandResult {
  ok,

  /// 이미 같은 동작이 진행 중 — 무시됨. 분무 연타가 대표적.
  busy,

  /// 인자가 빠졌거나 잘못됨(예: `duration_ms` 누락). **앱 버그 신호다.**
  badRequest,

  /// 펌웨어가 모르는 액션. 기기 펌웨어 업데이트가 필요하다.
  unknownAction,

  /// 안전잠금 상태라 거부됨(히터 과열·통신오류).
  locked,

  ttlExpired,
  duplicateMsgId,

  /// 기기가 실행하다 실패. 원인이 더 안 온다.
  error,

  /// 처음 보는 값. **결과가 아직 없는 것(null)과는 다르다.**
  unknown,
}

extension CommandResultWire on CommandResult {
  /// 결과 문자열 해석. 아직 결과가 없으면(`null`) **null을 돌려준다** —
  /// `sent`/`pending`(실DB 21건)을 [CommandResult.unknown]으로 뭉개면 작동
  /// 이력에서 "대기 중"과 "해석 실패"를 구분할 수 없다.
  static CommandResult? fromWire(String? v) {
    if (v == null) return null;
    // 접두사만 떼면 두 펌웨어가 같은 값으로 모인다.
    const prefix = 'rejected_';
    final key = v.startsWith(prefix) ? v.substring(prefix.length) : v;
    switch (key) {
      case 'ok':
        return CommandResult.ok;
      case 'busy':
        return CommandResult.busy;
      case 'bad_request':
        return CommandResult.badRequest;
      case 'unknown_action':
        return CommandResult.unknownAction;
      case 'locked':
        return CommandResult.locked;
      // 접두사만 떼서는 안 모인다 — 두 펌웨어가 **어휘 자체를 다르게** 쓴다.
      // nano: `expired`/`duplicate`, 카메라: `rejected_ttl_expired`/
      // `rejected_duplicate_msg_id` (백엔드 회신 2026-08-12).
      case 'ttl_expired':
      case 'expired':
        return CommandResult.ttlExpired;
      case 'duplicate_msg_id':
      case 'duplicate':
        return CommandResult.duplicateMsgId;
      case 'error':
        return CommandResult.error;
      default:
        return CommandResult.unknown;
    }
  }
}

// ── DeviceCommand ─────────────────────────────────────────────────────────────

class DeviceCommand {
  final String id;
  final String deviceId;
  final String issuedBy;
  final CommandAction action;
  final Map<String, dynamic>? payload;
  final CommandStatus status;
  final CommandResult? result;
  final DateTime? issuedAt;
  final DateTime? ackedAt;

  const DeviceCommand({
    required this.id,
    required this.deviceId,
    required this.issuedBy,
    required this.action,
    required this.payload,
    required this.status,
    required this.result,
    required this.issuedAt,
    required this.ackedAt,
  });

  factory DeviceCommand.fromJson(Map<String, dynamic> j) {
    final rawPayload = j['payload'];
    return DeviceCommand(
      id: j['id'] as String? ?? '',
      deviceId: j['device_id'] as String? ?? '',
      issuedBy: j['issued_by'] as String? ?? '',
      action: CommandActionWire.fromWire(j['action'] as String?),
      payload: rawPayload is Map
          ? rawPayload.cast<String, dynamic>()
          : null,
      status: CommandStatusWire.fromWire(j['status'] as String?),
      result: CommandResultWire.fromWire(j['result'] as String?),
      issuedAt: j['issued_at'] != null
          ? DateTime.tryParse(j['issued_at'].toString())
          : null,
      ackedAt: j['acked_at'] != null
          ? DateTime.tryParse(j['acked_at'].toString())
          : null,
    );
  }
}
