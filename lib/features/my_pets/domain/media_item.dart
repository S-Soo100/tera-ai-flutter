class MediaItem {
  final String id;
  final String petId;
  final String? eventId;
  final String type;
  final String url;
  final String? thumbnailUrl;
  final String? caption;
  final int? fileSize;
  final DateTime createdAt;

  MediaItem({
    required this.id,
    required this.petId,
    this.eventId,
    this.type = 'image',
    required this.url,
    this.thumbnailUrl,
    this.caption,
    this.fileSize,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      eventId: json['event_id'] as String?,
      type: (json['type'] as String?) ?? 'image',
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      fileSize: json['file_size'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
