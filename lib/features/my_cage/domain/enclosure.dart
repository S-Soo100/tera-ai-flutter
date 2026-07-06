/// Supabase `enclosures` 테이블 매핑 (terra-server 스키마 기준).
///
/// 컬럼: id, owner_id, name, species, note, created_at, updated_at
/// owner_id는 RLS로 본인 것만 조회되므로 모델에 담지 않는다
/// (TerraCamera와 동일한 관례).
class Enclosure {
  final String id;
  final String name;
  final String? species;
  final String? note;
  final DateTime createdAt;

  const Enclosure({
    required this.id,
    required this.name,
    this.species,
    this.note,
    required this.createdAt,
  });

  factory Enclosure.fromJson(Map<String, dynamic> j) {
    return Enclosure(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      species: j['species'] as String?,
      note: j['note'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
