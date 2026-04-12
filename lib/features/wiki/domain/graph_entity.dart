enum EntityKind {
  species,
  envCond,
  disease,
  food,
  equipment,
  unknown;

  static EntityKind fromString(String? raw) {
    switch (raw) {
      case 'species':
        return EntityKind.species;
      case 'env_cond':
        return EntityKind.envCond;
      case 'disease':
        return EntityKind.disease;
      case 'food':
        return EntityKind.food;
      case 'equipment':
        return EntityKind.equipment;
      default:
        return EntityKind.unknown;
    }
  }

  String get wire {
    switch (this) {
      case EntityKind.species:
        return 'species';
      case EntityKind.envCond:
        return 'env_cond';
      case EntityKind.disease:
        return 'disease';
      case EntityKind.food:
        return 'food';
      case EntityKind.equipment:
        return 'equipment';
      case EntityKind.unknown:
        return 'unknown';
    }
  }
}

enum RelationType {
  requiresTemp,
  requiresHumidity,
  requiresUvb,
  housedIn,
  suitableFood,
  susceptibleTo,
  causedBy,
  preventedBy,
  incompatibleWith,
  unknown;

  static RelationType fromString(String? raw) {
    switch (raw) {
      case 'REQUIRES_TEMP':
        return RelationType.requiresTemp;
      case 'REQUIRES_HUMIDITY':
        return RelationType.requiresHumidity;
      case 'REQUIRES_UVB':
        return RelationType.requiresUvb;
      case 'HOUSED_IN':
        return RelationType.housedIn;
      case 'SUITABLE_FOOD':
        return RelationType.suitableFood;
      case 'SUSCEPTIBLE_TO':
        return RelationType.susceptibleTo;
      case 'CAUSED_BY':
        return RelationType.causedBy;
      case 'PREVENTED_BY':
        return RelationType.preventedBy;
      case 'INCOMPATIBLE_WITH':
        return RelationType.incompatibleWith;
      default:
        return RelationType.unknown;
    }
  }

  String get label {
    switch (this) {
      case RelationType.requiresTemp:
        return '적정 온도';
      case RelationType.requiresHumidity:
        return '적정 습도';
      case RelationType.requiresUvb:
        return 'UVB 권장';
      case RelationType.housedIn:
        return '권장 사육장';
      case RelationType.suitableFood:
        return '권장 먹이';
      case RelationType.susceptibleTo:
        return '취약 질병';
      case RelationType.causedBy:
        return '원인';
      case RelationType.preventedBy:
        return '예방';
      case RelationType.incompatibleWith:
        return '사용 금지';
      case RelationType.unknown:
        return '관련';
    }
  }
}

class GraphEntity {
  final String id;
  final EntityKind kind;
  final String? refId;
  final String label;
  final Map<String, dynamic> payload;

  const GraphEntity({
    required this.id,
    required this.kind,
    this.refId,
    required this.label,
    required this.payload,
  });

  factory GraphEntity.fromJson(Map<String, dynamic> json) {
    return GraphEntity(
      id: json['id'] as String,
      kind: EntityKind.fromString(json['kind'] as String?),
      refId: json['ref_id'] as String?,
      label: json['label'] as String? ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class GraphRelation {
  final String id;
  final String from;
  final RelationType type;
  final String to;
  final List<String> citationIds;

  const GraphRelation({
    required this.id,
    required this.from,
    required this.type,
    required this.to,
    required this.citationIds,
  });

  factory GraphRelation.fromJson(Map<String, dynamic> json) {
    return GraphRelation(
      id: json['id'] as String,
      from: json['from'] as String,
      type: RelationType.fromString(json['type'] as String?),
      to: json['to'] as String,
      citationIds: (json['citations'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }
}
