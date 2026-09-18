class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String timezone;
  final String? experience;

  /// 커뮤니티에 사육 경험 비공개(Figma Commu_Profile 1142:9369 체크). 컬럼
  /// `user_profiles.experience_hidden` — 앱 팀 마이그레이션(`supabase/drafts/`)
  /// 전에는 응답에 키가 없어 false·[experienceHiddenSupported] false다. 지원
  /// 전에는 저장 시 이 값을 보내지 않는다(없는 컬럼 UPDATE는 400).
  final bool experienceHidden;
  final bool experienceHiddenSupported;
  final List<String> preferredSpecies;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.timezone = 'Asia/Seoul',
    this.experience,
    this.experienceHidden = false,
    this.experienceHiddenSupported = false,
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
      experienceHidden: json['experience_hidden'] == true,
      experienceHiddenSupported: json.containsKey('experience_hidden'),
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
        if (experienceHiddenSupported) 'experience_hidden': experienceHidden,
        'preferred_species': preferredSpecies,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
