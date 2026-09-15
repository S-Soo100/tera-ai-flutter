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

const _kInitials = [
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

/// Compatibility-jamo initial of a precomposed Hangul syllable, else null.
String? _initialOf(int rune) => rune >= 0xAC00 && rune <= 0xD7A3
    ? _kInitials[(rune - 0xAC00) ~/ 588]
    : null;

/// Korean initials group the registration list without changing source IDs.
Map<String, List<PetRegistrationChoice>> petRegistrationGroups(
    Iterable<PetRegistrationChoice> choices) {
  const initials = _kInitials;
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

/// Rune ranges `(start, end)` of [name] that match [query].
///
/// Each query character matches a name character either literally
/// (case-insensitive) or, when the query character is a compatibility jamo
/// initial (`ㄱ`~`ㅎ`), by the initial of that syllable. Every syllable is
/// checked, so `ㅂ` hits both `블` in `디아블로 블랑코`. Matches never overlap.
List<(int, int)> petRegistrationMatches(String name, String query) {
  final q = query.trim().runes.toList();
  if (q.isEmpty) return const [];
  final n = name.runes.toList();
  bool same(int a, int b) =>
      a == b ||
      String.fromCharCode(a).toLowerCase() ==
          String.fromCharCode(b).toLowerCase();
  final ranges = <(int, int)>[];
  var i = 0;
  while (i + q.length <= n.length) {
    var ok = true;
    for (var j = 0; j < q.length && ok; j++) {
      final qc = q[j];
      final nc = n[i + j];
      ok = same(qc, nc) ||
          (_kInitials.contains(String.fromCharCode(qc)) &&
              _initialOf(nc) == String.fromCharCode(qc));
    }
    if (ok) {
      ranges.add((i, i + q.length));
      i += q.length;
    } else {
      i++;
    }
  }
  return ranges;
}

/// A search hit: the choice plus the highlighted rune ranges of its Korean
/// name. English-name-only hits carry no ranges so nothing is coloured that
/// did not actually match.
typedef PetRegistrationHit = ({
  PetRegistrationChoice choice,
  List<(int, int)> ranges,
});

/// Flat search results without initial sections. Ordered by first match
/// position in the Korean name (English-only hits last), then name, then ID.
List<PetRegistrationHit> petRegistrationSearch(
    Iterable<PetRegistrationChoice> choices, String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final hits = <PetRegistrationHit>[];
  for (final choice in choices) {
    final ranges = petRegistrationMatches(choice.name, q);
    final english = choice.englishName;
    if (ranges.isNotEmpty ||
        (english != null && petRegistrationMatches(english, q).isNotEmpty)) {
      hits.add((choice: choice, ranges: ranges));
    }
  }
  int position(PetRegistrationHit h) =>
      h.ranges.isEmpty ? 1 << 30 : h.ranges.first.$1;
  hits.sort((a, b) {
    final byPosition = position(a).compareTo(position(b));
    if (byPosition != 0) return byPosition;
    final byName = a.choice.name.compareTo(b.choice.name);
    return byName != 0 ? byName : a.choice.id.compareTo(b.choice.id);
  });
  return hits;
}
