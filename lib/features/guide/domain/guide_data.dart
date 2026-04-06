class GuideStep {
  final int order;
  final String title;
  final String description;
  final String? detail;

  const GuideStep({
    required this.order,
    required this.title,
    required this.description,
    this.detail,
  });

  factory GuideStep.fromJson(Map<String, dynamic> json) {
    return GuideStep(
      order: json['order'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      detail: json['detail'] as String?,
    );
  }
}

class RequiredDocument {
  final String name;
  final String description;
  final String? note;

  const RequiredDocument({
    required this.name,
    required this.description,
    this.note,
  });

  factory RequiredDocument.fromJson(Map<String, dynamic> json) {
    return RequiredDocument(
      name: json['name'] as String,
      description: json['description'] as String,
      note: json['note'] as String?,
    );
  }
}

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      question: json['q'] as String,
      answer: json['a'] as String,
    );
  }
}

class ReportType {
  final String type;
  final String when;
  final String who;

  const ReportType({
    required this.type,
    required this.when,
    required this.who,
  });

  factory ReportType.fromJson(Map<String, dynamic> json) {
    return ReportType(
      type: json['type'] as String,
      when: json['when'] as String,
      who: json['who'] as String,
    );
  }
}

class GuideData {
  final String deadline;
  final String gracePeriodEnd;
  final String legalBasis;
  final String systemName;
  final String systemUrl;
  final String systemNote;
  final List<GuideStep> steps;
  final List<RequiredDocument> requiredDocuments;
  final List<FaqItem> faq;
  final List<ReportType> reportTypes;

  const GuideData({
    required this.deadline,
    required this.gracePeriodEnd,
    required this.legalBasis,
    required this.systemName,
    required this.systemUrl,
    required this.systemNote,
    required this.steps,
    required this.requiredDocuments,
    required this.faq,
    required this.reportTypes,
  });

  factory GuideData.fromJson(Map<String, dynamic> json) {
    final system = json['report_system'] as Map<String, dynamic>;
    return GuideData(
      deadline: json['deadline'] as String,
      gracePeriodEnd: json['grace_period_end'] as String,
      legalBasis: json['legal_basis'] as String,
      systemName: system['name'] as String,
      systemUrl: system['url'] as String,
      systemNote: system['note'] as String? ?? '',
      steps: (json['steps'] as List)
          .map((e) => GuideStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiredDocuments: (json['required_documents'] as List)
          .map((e) => RequiredDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      faq: (json['faq'] as List)
          .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      reportTypes: (json['report_types_summary'] as List?)
              ?.map((e) => ReportType.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  int get daysRemaining {
    final deadlineDate = DateTime.parse(deadline);
    return deadlineDate.difference(DateTime.now()).inDays;
  }

  bool get isExpired => daysRemaining < 0;

  bool get isInGracePeriod {
    final now = DateTime.now();
    final deadlineDate = DateTime.parse(deadline);
    final graceDate = DateTime.parse(gracePeriodEnd);
    return now.isAfter(deadlineDate) && now.isBefore(graceDate);
  }
}
