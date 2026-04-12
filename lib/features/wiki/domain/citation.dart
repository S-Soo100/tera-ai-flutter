enum CitationType {
  careSheet,
  book,
  paper,
  community,
  unknown;

  static CitationType fromString(String? raw) {
    switch (raw) {
      case 'care_sheet':
        return CitationType.careSheet;
      case 'book':
        return CitationType.book;
      case 'paper':
        return CitationType.paper;
      case 'community':
        return CitationType.community;
      default:
        return CitationType.unknown;
    }
  }
}

enum CitationConfidence {
  unverified,
  medium,
  high;

  static CitationConfidence fromString(String? raw) {
    switch (raw) {
      case 'high':
        return CitationConfidence.high;
      case 'medium':
        return CitationConfidence.medium;
      case 'unverified':
      default:
        return CitationConfidence.unverified;
    }
  }
}

class Citation {
  final String id;
  final CitationType type;
  final String title;
  final List<String> authors;
  final String? publisher;
  final int? year;
  final String? url;
  final String? doi;
  final String? accessedAt;
  final String? reviewedBy;
  final String? reviewedAt;
  final CitationConfidence confidence;

  const Citation({
    required this.id,
    required this.type,
    required this.title,
    required this.authors,
    this.publisher,
    this.year,
    this.url,
    this.doi,
    this.accessedAt,
    this.reviewedBy,
    this.reviewedAt,
    required this.confidence,
  });

  bool get hasLink => (url != null && url!.isNotEmpty) || (doi != null && doi!.isNotEmpty);

  String? get resolvedUrl {
    if (url != null && url!.isNotEmpty) return url;
    if (doi != null && doi!.isNotEmpty) return 'https://doi.org/$doi';
    return null;
  }

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      id: json['id'] as String,
      type: CitationType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      authors: (json['authors'] as List?)?.map((e) => e as String).toList() ?? const [],
      publisher: json['publisher'] as String?,
      year: json['year'] as int?,
      url: json['url'] as String?,
      doi: json['doi'] as String?,
      accessedAt: json['accessed_at'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      confidence: CitationConfidence.fromString(json['confidence'] as String?),
    );
  }
}
