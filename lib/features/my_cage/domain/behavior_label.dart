import 'action_type.dart';
import 'lick_target_type.dart';

class BehaviorLabel {
  final String id;
  final String clipId;
  final String labeledBy;
  final ActionType action;
  final LickTargetType? lickTarget;
  final String? note;
  final DateTime labeledAt;

  const BehaviorLabel({
    required this.id,
    required this.clipId,
    required this.labeledBy,
    required this.action,
    this.lickTarget,
    this.note,
    required this.labeledAt,
  });

  factory BehaviorLabel.fromJson(Map<String, dynamic> json) {
    final lickTargetRaw = json['lick_target'] as String?;
    return BehaviorLabel(
      id: json['id'] as String,
      clipId: json['clip_id'] as String,
      labeledBy: json['labeled_by'] as String,
      action: ActionType.fromWire(json['action'] as String),
      lickTarget: lickTargetRaw != null
          ? LickTargetType.fromWire(lickTargetRaw)
          : null,
      note: json['note'] as String?,
      labeledAt: DateTime.parse(json['labeled_at'] as String),
    );
  }
}
