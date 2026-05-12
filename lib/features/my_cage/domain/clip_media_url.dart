class ClipMediaUrl {
  final String url;
  final int ttlSec;
  final String type;

  const ClipMediaUrl({
    required this.url,
    required this.ttlSec,
    required this.type,
  });

  factory ClipMediaUrl.fromJson(Map<String, dynamic> json) {
    return ClipMediaUrl(
      url: json['url'] as String,
      ttlSec: json['ttl_sec'] as int,
      type: json['type'] as String,
    );
  }
}
