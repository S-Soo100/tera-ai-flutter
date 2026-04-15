class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String timezone;
  final String? experience;
  final List<String> preferredSpecies;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.timezone = 'Asia/Seoul',
    this.experience,
    this.preferredSpecies = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      timezone: (json['timezone'] as String?) ?? 'Asia/Seoul',
      experience: json['experience'] as String?,
      preferredSpecies: (json['preferred_species'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'timezone': timezone,
        'experience': experience,
        'preferred_species': preferredSpecies,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
