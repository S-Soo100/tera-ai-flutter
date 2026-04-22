import '../domain/species.dart';

class SpeciesRepository {
  // 메인 3종 (상세 사육 위키 지원)
  static const List<Species> _featuredSpecies = [
    Species(
      id: 'crested-gecko',
      koreanName: '크레스티드 게코',
      scientificName: 'Correlophus ciliatus',
      commonName: 'Crested Gecko',
      category: '도마뱀',
      family: '돌도마뱀붙이과',
      registrationRequired: true,
      hasCareInfo: true,
      hasMorphData: true,
      tags: ['입문', '인기', '수목성'],
    ),
    Species(
      id: 'leopard-gecko',
      koreanName: '레오파드 게코',
      scientificName: 'Eublepharis macularius',
      commonName: 'Leopard Gecko',
      category: '도마뱀',
      family: '표범도마뱀붙이과',
      registrationRequired: true,
      hasCareInfo: true,
      hasMorphData: true,
      tags: ['입문', '인기', '야행성'],
    ),
    Species(
      id: 'fat-tailed-gecko',
      koreanName: '펫테일 게코',
      scientificName: 'Hemitheconyx caudicinctus',
      commonName: 'African Fat-tailed Gecko',
      category: '도마뱀',
      family: '표범도��뱀붙이과',
      registrationRequired: true,
      hasCareInfo: true,
      hasMorphData: true,
      tags: ['입문', '야행성'],
    ),
  ];

  // 기타 종 (검색용, 사육정보 없음)
  static const List<Species> _otherSpecies = [
    Species(id: 'bearded', koreanName: '비어디 드래곤', scientificName: 'Pogona vitticeps', commonName: 'Bearded Dragon', category: '도마뱀', family: '아가마과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문', '인기']),
    Species(id: 'chameleon-v', koreanName: '베일드 카멜레온', scientificName: 'Chamaeleo calyptratus', commonName: 'Veiled Chameleon', category: '도마뱀', family: '카멜레온과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['중급']),
    Species(id: 'blue-tongue', koreanName: '블루텅 스킨크', scientificName: 'Tiliqua scincoides', commonName: 'Blue-tongued Skink', category: '도마뱀', family: '도마뱀과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문']),
    Species(id: 'ball-python', koreanName: '볼파이썬', scientificName: 'Python regius', commonName: 'Ball Python', category: '뱀', family: '비단뱀과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['인기']),
    Species(id: 'corn-snake', koreanName: '콘스네이크', scientificName: 'Pantherophis guttatus', commonName: 'Corn Snake', category: '뱀', family: '뱀과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문', '��기']),
    Species(id: 'king-snake', koreanName: '킹스네이크', scientificName: 'Lampropeltis getula', commonName: 'Common Kingsnake', category: '뱀', family: '뱀과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문']),
    Species(id: 'boa-con', koreanName: '보아 컨스���릭터', scientificName: 'Boa constrictor', commonName: 'Boa Constrictor', category: '뱀', family: '보아과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['중급']),
    Species(id: 'hognose', koreanName: '호그노즈', scientificName: 'Heterodon nasicus', commonName: 'Western Hognose', category: '뱀', family: '��과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['인기']),
    Species(id: 'russian-tort', koreanName: '러시안 육지거북', scientificName: 'Testudo horsfieldii', commonName: 'Russian Tortoise', category: '거북', family: '육지거북과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문', '인기']),
    Species(id: 'sulcata', koreanName: '설카타 육지거북', scientificName: 'Centrochelys sulcata', commonName: 'Sulcata Tortoise', category: '거북', family: '육지거북과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['대형']),
    Species(id: 'red-ear', koreanName: '붉은귀거���', scientificName: 'Trachemys scripta elegans', commonName: 'Red-eared Slider', category: '거���', family: '늪거북과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문']),
    Species(id: 'axolotl', koreanName: '아홀로틀', scientificName: 'Ambystoma mexicanum', commonName: 'Axolotl', category: '양서류', family: '���롱뇽과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['인기', '수생']),
    Species(id: 'pac-frog', koreanName: '팩맨 프로그', scientificName: 'Ceratophrys ornata', commonName: 'Pacman Frog', category: '양서류', family: '뿔개구리과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['입문']),
    Species(id: 'tokay-gecko', koreanName: '토케이 게코', scientificName: 'Gekko gecko', commonName: 'Tokay Gecko', category: '도마뱀', family: '도마뱀붙이과', registrationRequired: true, hasCareInfo: false, hasMorphData: false, tags: ['중급']),
  ];

  List<Species> get allSpecies => [..._featuredSpecies, ..._otherSpecies];

  List<Species> get featuredSpecies => _featuredSpecies;

  List<Species> getAll() => allSpecies;

  List<Species> getByCategory(String category) {
    if (category == '전체') return allSpecies;
    return allSpecies.where((s) => s.category == category).toList();
  }

  List<Species> search(String query) {
    if (query.isEmpty) return allSpecies;
    final lower = query.toLowerCase();
    return allSpecies.where((s) {
      return s.koreanName.contains(query) ||
          s.scientificName.toLowerCase().contains(lower) ||
          s.commonName.toLowerCase().contains(lower) ||
          s.tags.any((t) => t.contains(query));
    }).toList();
  }

  Species? getById(String id) {
    try {
      return allSpecies.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  bool isFeatured(String id) =>
      _featuredSpecies.any((s) => s.id == id);
}
