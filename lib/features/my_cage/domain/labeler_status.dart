class LabelerStatus {
  final bool isLabeler;

  const LabelerStatus({required this.isLabeler});

  factory LabelerStatus.fromJson(Map<String, dynamic> json) {
    return LabelerStatus(isLabeler: json['is_labeler'] as bool);
  }
}
