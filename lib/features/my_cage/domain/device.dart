/// Supabase `devices` row 매핑.
class Device {
  final String id;
  final String? ownerId;
  final String? enclosureId;
  final String? name;
  final bool isOnline;
  final DateTime? lastSeenAt;

  /// 보드 능력 (`devices.capabilities` JSONB, 2026-08-18 백엔드 회신 §2).
  /// 예: `{"board":"mosfet","led_dimmable":true}`. 구 행은 서버가
  /// `{"board":"relay","led_dimmable":false}`로 백필했고, null이면 아직 아무도
  /// 안 채운 것 — 모르는 능력은 **없는 것으로** 본다.
  final Map<String, dynamic>? capabilities;

  const Device({
    required this.id,
    required this.ownerId,
    required this.enclosureId,
    required this.name,
    required this.isOnline,
    required this.lastSeenAt,
    this.capabilities,
  });

  /// LED 밝기(PWM) 조절이 되는 보드인가. 릴레이 보드는 `brightness`를 무시하고
  /// 켜기만 하므로 이 값이 true일 때만 밝기 UI를 보여준다.
  ///
  /// ⚠️ 펌웨어가 아직 capabilities를 보고하지 않아(회신 §2) 실제 MOSFET 보드도
  /// 당분간 false로 온다 — 운영자가 DB에서 갱신하거나 펌웨어 보고가 붙으면
  /// 자동으로 맞는다. 앱은 이 분기만 갖고 기다린다.
  bool get ledDimmable => capabilities?['led_dimmable'] == true;

  /// `relay` / `mosfet` / null(미보고).
  String? get boardType => capabilities?['board'] as String?;

  factory Device.fromJson(Map<String, dynamic> j) {
    final caps = j['capabilities'];
    return Device(
      id: j['id'] as String? ?? '',
      ownerId: j['owner_id'] as String?,
      enclosureId: j['enclosure_id'] as String?,
      name: j['name'] as String?,
      isOnline: j['is_online'] as bool? ?? false,
      lastSeenAt: j['last_seen_at'] != null
          ? DateTime.tryParse(j['last_seen_at'].toString())
          : null,
      capabilities: caps is Map ? caps.cast<String, dynamic>() : null,
    );
  }
}
