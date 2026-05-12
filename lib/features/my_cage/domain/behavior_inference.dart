import 'action_type.dart';

class BehaviorInference {
  final String? id;
  final String clipId;
  final ActionType action;
  final String source;
  final double? confidence;
  final String? reasoning;
  final String? vlmModel;
  final DateTime? createdAt;

  const BehaviorInference({
    this.id,
    required this.clipId,
    required this.action,
    required this.source,
    this.confidence,
    this.reasoning,
    this.vlmModel,
    this.createdAt,
  });

  factory BehaviorInference.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    final confidenceRaw = json['confidence'];
    return BehaviorInference(
      id: json['id'] as String?,
      clipId: json['clip_id'] as String,
      action: ActionType.fromWire(json['action'] as String),
      source: json['source'] as String,
      confidence:
          confidenceRaw != null ? (confidenceRaw as num).toDouble() : null,
      reasoning: json['reasoning'] as String?,
      vlmModel: json['vlm_model'] as String?,
      createdAt:
          createdAtRaw != null ? DateTime.parse(createdAtRaw) : null,
    );
  }
}
