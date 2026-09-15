import '../../wiki/domain/morph_genetics.dart';

/// Registration labels reuse the bundled catalog; genetic morphs and line-bred
/// traits keep distinct stable keys and are not merged by a similar name.
typedef PetRegistrationChoice = ({String id, String name, String? englishName});
List<PetRegistrationChoice> petRegistrationChoices(MorphGeneticsData data) => [
      for (final morph in data.morphs)
        (id: 'morph:${morph.id}', name: morph.name, englishName: morph.nameEn),
      for (final trait in data.lineBredTraits)
        (id: 'trait:${trait.id}', name: trait.name, englishName: trait.nameEn),
    ];

/// Korean initials group the registration list without changing source IDs.
Map<String, List<PetRegistrationChoice>> petRegistrationGroups(
    Iterable<PetRegistrationChoice> choices) {
  const initials = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ'
  ];
  final sorted = choices.toList()
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  final groups = <String, List<PetRegistrationChoice>>{};
  for (final choice in sorted) {
    final name = choice.name.trim();
    final first = name.isEmpty ? 0 : name.runes.first;
    final initial = first >= 0xAC00 && first <= 0xD7A3
        ? initials[(first - 0xAC00) ~/ 588]
        : first >= 65 && first <= 122 && RegExp(r'[a-zA-Z]').hasMatch(name[0])
            ? name[0].toUpperCase()
            : '#';
    (groups[initial] ??= []).add(choice);
  }
  return groups;
}
