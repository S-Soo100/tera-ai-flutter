import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/care_info_detail.dart';
import '../domain/morph_genetics.dart';

final careInfoRepositoryProvider = Provider<CareInfoRepository>((ref) {
  return CareInfoRepository();
});

class CareInfoRepository {
  final Map<String, CareInfoDetail> _cache = {};
  final Map<String, MorphGeneticsData> _morphCache = {};

  static const List<String> featuredSpeciesIds = [
    'leopard-gecko',
    'crested-gecko',
    'fat-tailed-gecko',
  ];

  static const Map<String, String> speciesNames = {
    'leopard-gecko': '레오파드 게코',
    'crested-gecko': '크레스티드 게코',
    'fat-tailed-gecko': '펫테일 게코',
  };

  Future<CareInfoDetail> getCareInfo(String speciesId) async {
    if (_cache.containsKey(speciesId)) return _cache[speciesId]!;

    final jsonStr = await rootBundle
        .loadString('assets/data/care_info/$speciesId.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final info = CareInfoDetail.fromJson(json);
    _cache[speciesId] = info;
    return info;
  }

  Future<MorphGeneticsData> getMorphData(String speciesId) async {
    if (_morphCache.containsKey(speciesId)) return _morphCache[speciesId]!;

    final jsonStr = await rootBundle
        .loadString('assets/data/morphs/$speciesId.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final data = MorphGeneticsData.fromJson(json);
    _morphCache[speciesId] = data;
    return data;
  }

  Future<List<CareInfoDetail>> getAllFeaturedCareInfo() async {
    final results = <CareInfoDetail>[];
    for (final id in featuredSpeciesIds) {
      results.add(await getCareInfo(id));
    }
    return results;
  }
}
