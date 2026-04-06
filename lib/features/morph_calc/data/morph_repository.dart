import '../domain/morph_result.dart';

class MorphRepository {
  static const List<MorphResult> _allResults = [
    MorphResult(
      speciesId: 'leo-gecko',
      father: '마크스노',
      mother: '트렘퍼 알비노',
      outcomes: [
        MorphOutcome(name: '노말 het 알비노', probability: 0.5),
        MorphOutcome(name: '마크스노 het 알비노', probability: 0.5),
      ],
    ),
    MorphResult(
      speciesId: 'leo-gecko',
      father: '마크스노 het 알비노',
      mother: '마크스노 het 알비노',
      outcomes: [
        MorphOutcome(name: '수퍼스노 알비노', probability: 0.0625),
        MorphOutcome(name: '수퍼스노 het 알비노', probability: 0.125),
        MorphOutcome(name: '수퍼스노', probability: 0.25),
        MorphOutcome(name: '마크스노 알비노', probability: 0.125),
        MorphOutcome(name: '마크스노 het 알비노', probability: 0.25),
        MorphOutcome(name: '노말 알비노', probability: 0.0625),
        MorphOutcome(name: '노말 het 알비노', probability: 0.125),
      ],
    ),
    MorphResult(
      speciesId: 'ball-python',
      father: '파스텔',
      mother: '파스텔',
      outcomes: [
        MorphOutcome(name: '수퍼 파스텔', probability: 0.25),
        MorphOutcome(name: '파스텔', probability: 0.5),
        MorphOutcome(name: '노말', probability: 0.25),
      ],
    ),
  ];

  static const Map<String, List<String>> _selectableMorphs = {
    'leo-gecko': ['노말', '마크스노', '트렘퍼 알비노', '마크스노 het 알비노'],
    'ball-python': ['노말', '파스텔'],
  };

  List<String> getMorphSpecies() => _selectableMorphs.keys.toList();

  List<String> getMorphsForSpecies(String speciesId) {
    return _selectableMorphs[speciesId] ?? [];
  }

  MorphResult? getResult({
    required String speciesId,
    required String father,
    required String mother,
  }) {
    try {
      return _allResults.firstWhere(
        (r) =>
            r.speciesId == speciesId &&
            r.father == father &&
            r.mother == mother,
      );
    } catch (_) {
      return null;
    }
  }
}
