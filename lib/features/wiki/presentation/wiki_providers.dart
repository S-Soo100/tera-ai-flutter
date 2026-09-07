import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/care_info_repository.dart';
import '../domain/care_info_detail.dart';
import '../domain/morph_genetics.dart';

final careInfoProvider =
    FutureProvider.family<CareInfoDetail, String>((ref, speciesId) async {
  final repo = ref.watch(careInfoRepositoryProvider);
  return repo.getCareInfo(speciesId);
});

final morphDataProvider =
    FutureProvider.family<MorphGeneticsData, String>((ref, speciesId) async {
  final repo = ref.watch(careInfoRepositoryProvider);
  return repo.getMorphData(speciesId);
});

/// 종별 citation_ids → Citation 객체 리스트.
// 위키 화면 전용 provider(selectedWikiSpecies·speciesCitations)와 출처
// 인프라(citation_*, punnett_engine, citation_card)는 2026-09-07 A6 정리로
// 삭제 — 위키 라우트 폐기(2026-09-02) 후 소비처 0. 남은 것은 개체 등록의
// 모프 드롭다운(morphDataProvider)과 종 케어 데이터(careInfoProvider) 인프라.
