class MorphGene {
  final String id;
  final String name;
  final String nameEn;
  final String inheritance; // recessive, dominant, incomplete_dominant, codominant
  final String? alleleGroup;
  final String description;
  final bool homozygousLethal;
  final String? healthWarning;
  final String? discoveredBy;
  final int? discoveredYear;
  final List<String> lines;
  final bool linesCompatible;

  const MorphGene({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.inheritance,
    this.alleleGroup,
    required this.description,
    this.homozygousLethal = false,
    this.healthWarning,
    this.discoveredBy,
    this.discoveredYear,
    this.lines = const [],
    this.linesCompatible = true,
  });

  factory MorphGene.fromJson(Map<String, dynamic> json) {
    return MorphGene(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      inheritance: json['inheritance'] as String,
      alleleGroup: json['allele_group'] as String?,
      description: json['description'] as String,
      homozygousLethal: json['homozygous_lethal'] as bool? ?? false,
      healthWarning: json['health_warning'] as String?,
      discoveredBy: json['discovered_by'] as String?,
      discoveredYear: json['discovered_year'] as int?,
      lines: (json['lines'] as List?)?.map((e) => e as String).toList() ?? const [],
      linesCompatible: json['lines_compatible'] as bool? ?? true,
    );
  }

  String get inheritanceDisplay {
    switch (inheritance) {
      case 'recessive':
        return '열성';
      case 'dominant':
        return '우성';
      case 'incomplete_dominant':
        return '불완전 우성';
      case 'codominant':
        return '공우성';
      default:
        return inheritance;
    }
  }
}

class MorphEntry {
  final String id;
  final String name;
  final String? nameEn;
  final List<String> genes;
  final String description;
  final String? note;
  final String? zygosity;
  final String? zygosityNote;
  final String? healthWarning;
  final String geneticsType;

  const MorphEntry({
    required this.id,
    required this.name,
    this.nameEn,
    required this.genes,
    required this.description,
    this.note,
    this.zygosity,
    this.zygosityNote,
    this.healthWarning,
    this.geneticsType = 'baseline',
  });

  factory MorphEntry.fromJson(Map<String, dynamic> json) {
    return MorphEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      genes: (json['genes'] as List).map((e) => e as String).toList(),
      description: json['description'] as String,
      note: json['note'] as String?,
      zygosity: json['zygosity'] as String?,
      zygosityNote: json['zygosity_note'] as String?,
      healthWarning: json['health_warning'] as String?,
      geneticsType: json['genetics_type'] as String? ?? 'baseline',
    );
  }
}

class LineBredTrait {
  final String id;
  final String name;
  final String nameEn;
  final String type;
  final String description;
  final String? group;
  final List<String> variants;

  const LineBredTrait({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.type,
    required this.description,
    this.group,
    this.variants = const [],
  });

  factory LineBredTrait.fromJson(Map<String, dynamic> json) {
    return LineBredTrait(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      group: json['group'] as String?,
      variants: (json['variants'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }
}

class AlleleGroupCrossResult {
  final String key;
  final String name;
  final String nameEn;
  final String? note;

  const AlleleGroupCrossResult({
    required this.key,
    required this.name,
    required this.nameEn,
    this.note,
  });

  factory AlleleGroupCrossResult.fromJson(String key, Map<String, dynamic> json) {
    return AlleleGroupCrossResult(
      key: key,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      note: json['note'] as String?,
    );
  }
}

class AlleleGroup {
  final String id;
  final String name;
  final String nameEn;
  final String description;
  final List<String> members;
  final List<AlleleGroupCrossResult> crossResults;
  final Map<String, String> superHealth;

  const AlleleGroup({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.members,
    required this.crossResults,
    required this.superHealth,
  });

  factory AlleleGroup.fromJson(String id, Map<String, dynamic> json) {
    final crossMap = json['cross_results'] as Map<String, dynamic>? ?? {};
    return AlleleGroup(
      id: id,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      description: json['description'] as String,
      members: (json['members'] as List).map((e) => e as String).toList(),
      crossResults: crossMap.entries
          .map((e) => AlleleGroupCrossResult.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList(),
      superHealth: (json['super_health'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
    );
  }
}

class PatternGroup {
  final String id;
  final String name;
  final String type;
  final String description;

  const PatternGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
  });

  factory PatternGroup.fromJson(String id, Map<String, dynamic> json) {
    return PatternGroup(
      id: id,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
    );
  }
}

class MorphGeneticsData {
  final String speciesId;
  final String speciesNameKo;
  final String calculatorType; // full, mini
  final String? calculatorNote;
  final List<MorphGene> genes;
  final List<MorphEntry> morphs;
  final List<LineBredTrait> lineBredTraits;
  final Map<String, String> notes;
  final List<AlleleGroup> alleleGroups;
  final List<PatternGroup> patternGroups;
  final String? speciesNameEn;
  final String? scientificName;
  final List<String> sources;

  const MorphGeneticsData({
    required this.speciesId,
    required this.speciesNameKo,
    required this.calculatorType,
    this.calculatorNote,
    required this.genes,
    required this.morphs,
    this.lineBredTraits = const [],
    this.notes = const {},
    this.alleleGroups = const [],
    this.patternGroups = const [],
    this.speciesNameEn,
    this.scientificName,
    this.sources = const [],
  });

  factory MorphGeneticsData.fromJson(Map<String, dynamic> json) {
    final alleleGroupsMap = json['allele_groups'] as Map<String, dynamic>? ?? {};
    final patternGroupsMap = json['pattern_groups'] as Map<String, dynamic>? ?? {};

    return MorphGeneticsData(
      speciesId: json['species_id'] as String,
      speciesNameKo: json['species_name_ko'] as String,
      calculatorType: json['calculator_type'] as String? ?? 'full',
      calculatorNote: json['calculator_note'] as String?,
      genes: (json['genes'] as List)
          .map((e) => MorphGene.fromJson(e as Map<String, dynamic>))
          .toList(),
      morphs: (json['morphs'] as List)
          .map((e) => MorphEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      lineBredTraits: (json['line_bred_traits'] as List?)
              ?.map((e) => LineBredTrait.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      alleleGroups: alleleGroupsMap.entries
          .map((e) => AlleleGroup.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList(),
      patternGroups: patternGroupsMap.entries
          .map((e) => PatternGroup.fromJson(e.key, e.value as Map<String, dynamic>))
          .toList(),
      speciesNameEn: json['species_name_en'] as String?,
      scientificName: json['scientific_name'] as String?,
      sources: (json['sources'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  List<String> get selectableMorphNames => morphs.map((m) => m.name).toList();

  AlleleGroup? alleleGroupFor(String geneId) {
    for (final group in alleleGroups) {
      if (group.members.contains(geneId)) return group;
    }
    return null;
  }

  List<LineBredTrait> traitsInGroup(String groupId) {
    return lineBredTraits.where((t) => t.group == groupId).toList();
  }
}
