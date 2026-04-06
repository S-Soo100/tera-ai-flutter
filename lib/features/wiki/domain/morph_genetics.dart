class MorphGene {
  final String id;
  final String name;
  final String nameEn;
  final String inheritance; // recessive, dominant, incomplete_dominant, codominant
  final String? alleleGroup;
  final String description;
  final bool homozygousLethal;
  final String? healthWarning;

  const MorphGene({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.inheritance,
    this.alleleGroup,
    required this.description,
    this.homozygousLethal = false,
    this.healthWarning,
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

  const MorphEntry({
    required this.id,
    required this.name,
    this.nameEn,
    required this.genes,
    required this.description,
    this.note,
  });

  factory MorphEntry.fromJson(Map<String, dynamic> json) {
    return MorphEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      genes: (json['genes'] as List).map((e) => e as String).toList(),
      description: json['description'] as String,
      note: json['note'] as String?,
    );
  }
}

class LineBredTrait {
  final String id;
  final String name;
  final String nameEn;
  final String type;
  final String description;

  const LineBredTrait({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.type,
    required this.description,
  });

  factory LineBredTrait.fromJson(Map<String, dynamic> json) {
    return LineBredTrait(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
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

  const MorphGeneticsData({
    required this.speciesId,
    required this.speciesNameKo,
    required this.calculatorType,
    this.calculatorNote,
    required this.genes,
    required this.morphs,
    this.lineBredTraits = const [],
    this.notes = const {},
  });

  factory MorphGeneticsData.fromJson(Map<String, dynamic> json) {
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
    );
  }

  List<String> get selectableMorphNames =>
      morphs.map((m) => m.name).toList();
}
