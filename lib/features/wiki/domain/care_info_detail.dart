class TempRange {
  final int min;
  final int max;

  const TempRange({required this.min, required this.max});

  factory TempRange.fromJson(Map<String, dynamic> json) {
    return TempRange(min: json['min'] as int, max: json['max'] as int);
  }

  String get display => '$min~$max';
}

class CareInfoDetail {
  final String speciesId;
  final String speciesNameKo;
  final String scientificName;
  final String lastUpdated;
  final String difficulty;
  final String lifespan;
  final String adultSize;
  final String temperament;
  final String? comparisonToLeopardGecko;

  // Temperature
  final TempRange? baskingSurface;
  final TempRange hotZone;
  final TempRange coolZone;
  final TempRange night;
  final String tempUnit;
  final String? tempNotes;

  // Humidity
  final int humidityMin;
  final int humidityMax;
  final TempRange? humidHide;
  final String? humidHideText; // 펫테일처럼 문자열인 경우
  final String? humidityMisting;
  final String? humidityNotes;

  // Enclosure
  final String minSize;
  final String? enclosureType;
  final List<String> substrate;
  final List<String> substrateAvoid;
  final List<String> essentials;
  final String? lighting;

  // Diet
  final List<String> mainDiet;
  final List<String> treats;
  final List<String> supplements;
  final String feedingFrequency;
  final String? feedingSize;
  final String? water;
  final String? dietNotes;

  // Common mistakes
  final List<String> commonMistakes;
  final List<String> sources;

  // Knowledge graph linkage (P0.5)
  final List<String> citationIds;
  final String? graphEntityId;

  const CareInfoDetail({
    required this.speciesId,
    required this.speciesNameKo,
    required this.scientificName,
    required this.lastUpdated,
    required this.difficulty,
    required this.lifespan,
    required this.adultSize,
    required this.temperament,
    this.comparisonToLeopardGecko,
    this.baskingSurface,
    required this.hotZone,
    required this.coolZone,
    required this.night,
    required this.tempUnit,
    this.tempNotes,
    required this.humidityMin,
    required this.humidityMax,
    this.humidHide,
    this.humidHideText,
    this.humidityMisting,
    this.humidityNotes,
    required this.minSize,
    this.enclosureType,
    required this.substrate,
    this.substrateAvoid = const [],
    required this.essentials,
    this.lighting,
    required this.mainDiet,
    this.treats = const [],
    required this.supplements,
    required this.feedingFrequency,
    this.feedingSize,
    this.water,
    this.dietNotes,
    required this.commonMistakes,
    required this.sources,
    this.citationIds = const [],
    this.graphEntityId,
  });

  factory CareInfoDetail.fromJson(Map<String, dynamic> json) {
    final temp = json['temperature'] as Map<String, dynamic>;
    final humidity = json['humidity'] as Map<String, dynamic>;
    final enclosure = json['enclosure'] as Map<String, dynamic>;
    final diet = json['diet'] as Map<String, dynamic>;

    TempRange? humidHide;
    String? humidHideText;
    final rawHumidHide = humidity['humid_hide'];
    if (rawHumidHide is Map<String, dynamic>) {
      humidHide = TempRange.fromJson(rawHumidHide);
    } else if (rawHumidHide is String) {
      humidHideText = rawHumidHide;
    }

    return CareInfoDetail(
      speciesId: json['species_id'] as String,
      speciesNameKo: json['species_name_ko'] as String,
      scientificName: json['scientific_name'] as String,
      lastUpdated: json['last_updated'] as String,
      difficulty: json['difficulty'] as String,
      lifespan: json['lifespan'] as String,
      adultSize: json['adult_size'] as String,
      temperament: json['temperament'] as String,
      comparisonToLeopardGecko: json['comparison_to_leopard_gecko'] as String?,
      baskingSurface: temp['basking_surface'] != null
          ? TempRange.fromJson(temp['basking_surface'])
          : null,
      hotZone: TempRange.fromJson(temp['hot_zone']),
      coolZone: TempRange.fromJson(temp['cool_zone']),
      night: TempRange.fromJson(temp['night']),
      tempUnit: temp['unit'] as String? ?? '℃',
      tempNotes: temp['notes'] as String?,
      humidityMin: humidity['min'] as int,
      humidityMax: humidity['max'] as int,
      humidHide: humidHide,
      humidHideText: humidHideText,
      humidityMisting: humidity['misting'] as String?,
      humidityNotes: humidity['notes'] as String?,
      minSize: enclosure['min_size'] as String,
      enclosureType: enclosure['type'] as String?,
      substrate:
          (enclosure['substrate'] as List).map((e) => e as String).toList(),
      substrateAvoid: (enclosure['substrate_avoid'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      essentials:
          (enclosure['essentials'] as List).map((e) => e as String).toList(),
      lighting: enclosure['lighting'] as String?,
      mainDiet: (diet['main'] as List).map((e) => e as String).toList(),
      treats:
          (diet['treat'] as List?)?.map((e) => e as String).toList() ?? [],
      supplements:
          (diet['supplement'] as List).map((e) => e as String).toList(),
      feedingFrequency: diet['frequency'] as String,
      feedingSize: diet['feeding_size'] as String?,
      water: diet['water'] as String?,
      dietNotes: diet['notes'] as String?,
      commonMistakes: (json['common_mistakes'] as List)
          .map((e) => e as String)
          .toList(),
      sources:
          (json['sources'] as List).map((e) => e as String).toList(),
      citationIds: (json['citation_ids'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      graphEntityId: json['graph_entity_id'] as String?,
    );
  }
}
