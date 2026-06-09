/// Supabase `devices` row 매핑.
class Device {
  final String id;
  final String? ownerId;
  final String? enclosureId;
  final String? name;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.ownerId,
    required this.enclosureId,
    required this.name,
    required this.isOnline,
    required this.lastSeenAt,
  });

  factory Device.fromJson(Map<String, dynamic> j) {
    return Device(
      id: j['id'] as String? ?? '',
      ownerId: j['owner_id'] as String?,
      enclosureId: j['enclosure_id'] as String?,
      name: j['name'] as String?,
      isOnline: j['is_online'] as bool? ?? false,
      lastSeenAt: j['last_seen_at'] != null
          ? DateTime.tryParse(j['last_seen_at'].toString())
          : null,
    );
  }
}
