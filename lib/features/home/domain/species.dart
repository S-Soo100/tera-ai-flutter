class Species {
  final String id;
  final String koreanName;
  final String scientificName;
  final String commonName;
  final String category;
  final String family;
  final bool registrationRequired;
  final bool hasCareInfo;
  final bool hasMorphData;
  final List<String> tags;

  const Species({
    required this.id,
    required this.koreanName,
    required this.scientificName,
    required this.commonName,
    required this.category,
    required this.family,
    required this.registrationRequired,
    required this.hasCareInfo,
    required this.hasMorphData,
    required this.tags,
  });
}
