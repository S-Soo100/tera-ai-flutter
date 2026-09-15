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
