class Camera {
  final String id;
  final String userId;
  final String? petId;
  final String displayName;
  final String host;
  final int port;
  final String path;
  final String username;
  final bool isActive;
  final DateTime? lastConnectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Camera({
    required this.id,
    required this.userId,
    this.petId,
    required this.displayName,
    required this.host,
    required this.port,
    required this.path,
    required this.username,
    required this.isActive,
    this.lastConnectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      petId: json['pet_id'] as String?,
      displayName: json['display_name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      path: json['path'] as String,
      username: json['username'] as String,
      isActive: json['is_active'] as bool,
      lastConnectedAt: json['last_connected_at'] != null
          ? DateTime.parse(json['last_connected_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Camera copyWith({
    String? id,
    String? userId,
    String? petId,
    bool clearPetId = false,
    String? displayName,
    String? host,
    int? port,
    String? path,
    String? username,
    bool? isActive,
    DateTime? lastConnectedAt,
    bool clearLastConnectedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Camera(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: clearPetId ? null : (petId ?? this.petId),
      displayName: displayName ?? this.displayName,
      host: host ?? this.host,
      port: port ?? this.port,
      path: path ?? this.path,
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      lastConnectedAt: clearLastConnectedAt
          ? null
          : (lastConnectedAt ?? this.lastConnectedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
