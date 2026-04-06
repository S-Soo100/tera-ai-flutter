class MorphOutcome {
  final String name;
  final double probability;

  const MorphOutcome({
    required this.name,
    required this.probability,
  });
}

class MorphResult {
  final String speciesId;
  final String father;
  final String mother;
  final List<MorphOutcome> outcomes;

  const MorphResult({
    required this.speciesId,
    required this.father,
    required this.mother,
    required this.outcomes,
  });
}
