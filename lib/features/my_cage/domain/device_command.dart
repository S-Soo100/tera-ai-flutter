// terra-server `commands` 테이블 매핑.

// ── CommandAction ─────────────────────────────────────────────────────────────

enum CommandAction {
  relayToggle,
  fanToggle,
  heaterToggle,
  heaterClear,
  ledOn,
  ledUp,
  ledDown,
  tokenRotate,
  unknown,
}

extension CommandActionWire on CommandAction {
  String toWire() {
    switch (this) {
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
      case CommandAction.ledUp:
        return 'led_up';
      case CommandAction.ledDown:
        return 'led_down';
      case CommandAction.tokenRotate:
        return 'token_rotate';
      case CommandAction.unknown:
        return 'unknown';
    }
  }

  static CommandAction fromWire(String? v) {
    switch (v) {
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
      case 'led_up':
        return CommandAction.ledUp;
      case 'led_down':
        return CommandAction.ledDown;
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

enum CommandResult {
  ok,
  rejectedLocked,
  rejectedTtlExpired,
  rejectedUnknownAction,
  rejectedDuplicateMsgId,
  unknown,
}

extension CommandResultWire on CommandResult {
  static CommandResult fromWire(String? v) {
    switch (v) {
      case 'ok':
        return CommandResult.ok;
      case 'rejected_locked':
        return CommandResult.rejectedLocked;
      case 'rejected_ttl_expired':
        return CommandResult.rejectedTtlExpired;
      case 'rejected_unknown_action':
        return CommandResult.rejectedUnknownAction;
      case 'rejected_duplicate_msg_id':
        return CommandResult.rejectedDuplicateMsgId;
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
