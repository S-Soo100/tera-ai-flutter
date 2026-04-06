class CareInfo {
  final String speciesId;
  final String hotZone;
  final String coolZone;
  final String night;
  final int humidity;
  final bool isAquatic;
  final String enclosure;
  final List<String> substrate;
  final List<String> essentials;
  final List<String> mainDiet;
  final List<String> supplement;
  final String feedingFrequency;
  final List<String> commonMistakes;

  const CareInfo({
    required this.speciesId,
    required this.hotZone,
    required this.coolZone,
    required this.night,
    required this.humidity,
    this.isAquatic = false,
    required this.enclosure,
    required this.substrate,
    required this.essentials,
    required this.mainDiet,
    required this.supplement,
    required this.feedingFrequency,
    required this.commonMistakes,
  });
}
