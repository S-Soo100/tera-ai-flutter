class AppConstants {
  AppConstants._();

  static const List<String> categories = [
    '도마뱀',
    '뱀',
    '거북',
    '양서류',
  ];

  static const List<String> featuredSpeciesIds = [
    'leopard-gecko',
    'crested-gecko',
    'fat-tailed-gecko',
  ];

  static const Map<String, String> featuredSpeciesNames = {
    'leopard-gecko': '레오파드 게코',
    'crested-gecko': '크레스티드 게코',
    'fat-tailed-gecko': '펫테일 게코',
  };

  static final DateTime registrationDeadline = DateTime(2026, 6, 13);
  static final DateTime gracePeriodEnd = DateTime(2026, 12, 13);

  static int get daysUntilDeadline =>
      registrationDeadline.difference(DateTime.now()).inDays;
}
