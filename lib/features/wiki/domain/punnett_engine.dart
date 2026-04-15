import 'morph_genetics.dart';

// ──────────────────────────────────────────────
// 모델 클래스
// ──────────────────────────────────────────────

/// 단일 좌위(locus)에서 부모 한 쪽의 유전형
class LocusGenotype {
  /// 좌위 식별자.
  /// - 대립유전자 그룹에 속한 유전자면 alleleGroup.id
  /// - 독립 유전자면 gene.id
  final String locusId;

  /// 대립유전자 1 (gene.id 또는 "wild")
  final String allele1;

  /// 대립유전자 2 (gene.id 또는 "wild")
  final String allele2;

  /// 유전 방식: "recessive" | "incomplete_dominant"
  final String inheritance;

  const LocusGenotype({
    required this.locusId,
    required this.allele1,
    required this.allele2,
    required this.inheritance,
  });
}

/// 부모 한 쪽의 전체 유전형 (여러 좌위)
class ParentGenotype {
  final List<LocusGenotype> loci;

  const ParentGenotype({required this.loci});
}

/// 개별 자손 결과 하나
class OffspringOutcome {
  /// 표현형 이름 (한글)
  final String phenotypeName;

  /// 표현형 이름 (영문, 없을 수 있음)
  final String? phenotypeNameEn;

  /// 발생 확률 (0.0~1.0)
  final double probability;

  /// 개체별 건강 경고 (치사/건강 이슈)
  final String? healthWarning;

  /// 치사 개체 여부 (isLethal=true여도 확률에 포함, 마킹만)
  final bool isLethal;

  /// 유전형 상세 설명 목록 (예: ["Het 카푸치노", "슈퍼 릴리화이트"])
  final List<String> genotypeDetails;

  const OffspringOutcome({
    required this.phenotypeName,
    this.phenotypeNameEn,
    required this.probability,
    this.healthWarning,
    this.isLethal = false,
    this.genotypeDetails = const [],
  });
}

/// 전체 교배 계산 결과
class PunnettResult {
  final List<OffspringOutcome> outcomes;

  /// 전체 교배 수준 경고 (예: 치사 개체 발생 가능성)
  final List<String> warnings;

  const PunnettResult({
    required this.outcomes,
    this.warnings = const [],
  });
}

// ──────────────────────────────────────────────
// 내부 계산용 타입 별칭
// ──────────────────────────────────────────────

/// 단일 좌위 계산 결과 하나: (대립유전자1, 대립유전자2, 확률)
typedef _LocusResult = ({String allele1, String allele2, double probability});

/// 전체 좌위 결과 맵: locusId → LocusResult
typedef _FullGenotypeMap = Map<String, _LocusResult>;

// ──────────────────────────────────────────────
// 퍼넷 스퀘어 엔진
// ──────────────────────────────────────────────

class PunnettEngine {
  // 외부 인스턴스화 방지 — 순수 정적 유틸
  const PunnettEngine._();

  // ────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────

  /// 부모 유전형으로 교배 결과 계산
  static PunnettResult calculate({
    required ParentGenotype father,
    required ParentGenotype mother,
    required MorphGeneticsData morphData,
  }) {
    // 좌위 ID 집합 (부모 양쪽 합집합)
    final locusIds = <String>{
      for (final l in father.loci) l.locusId,
      for (final l in mother.loci) l.locusId,
    };

    // 각 좌위별 결과 리스트 수집
    final locusResultsList = <List<_LocusResult>>[];

    for (final locusId in locusIds) {
      // 해당 좌위가 없는 부모는 wild/wild로 처리
      final fLocus = _findLocus(father.loci, locusId);
      final mLocus = _findLocus(mother.loci, locusId);

      // inheritance는 어느 한 쪽에서든 가져옴 (동일 좌위는 동일 inheritance)
      final inheritance = fLocus?.inheritance ?? mLocus?.inheritance ?? 'recessive';

      final wildLocus = LocusGenotype(
        locusId: locusId,
        allele1: 'wild',
        allele2: 'wild',
        inheritance: inheritance,
      );

      final results = _calculateSingleLocus(
        fLocus ?? wildLocus,
        mLocus ?? wildLocus,
      );

      locusResultsList.add(results);
    }

    final locusIdList = locusIds.toList();

    // 직교곱으로 모든 좌위 조합 생성
    final combinations = _cartesianProduct(locusResultsList);

    // 조합별로 표현형 이름 + 확률 계산 후 합산
    final phenotypeMap = <String, _PhenotypeAccumulator>{};

    for (final combo in combinations) {
      // combo: 각 좌위별 LocusResult 목록 (locusIdList와 인덱스 대응)
      final genotypeMap = <String, _LocusResult>{};
      double prob = 1.0;
      for (int i = 0; i < locusIdList.length; i++) {
        genotypeMap[locusIdList[i]] = combo[i];
        prob *= combo[i].probability;
      }

      final phenotype = _mapPhenotype(genotypeMap, morphData, locusIds);
      final key = phenotype.key;

      if (phenotypeMap.containsKey(key)) {
        phenotypeMap[key]!.probability += prob;
      } else {
        phenotypeMap[key] = _PhenotypeAccumulator(
          phenotypeName: phenotype.name,
          phenotypeNameEn: phenotype.nameEn,
          probability: prob,
          healthWarning: phenotype.healthWarning,
          isLethal: phenotype.isLethal,
          genotypeDetails: phenotype.genotypeDetails,
          key: key,
        );
      }
    }

    // 확률 기준 내림차순 정렬
    final outcomes = phenotypeMap.values
        .map((a) => OffspringOutcome(
              phenotypeName: a.phenotypeName,
              phenotypeNameEn: a.phenotypeNameEn,
              probability: a.probability,
              healthWarning: a.healthWarning,
              isLethal: a.isLethal,
              genotypeDetails: a.genotypeDetails,
            ))
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    // 전체 교배 경고 생성
    final warnings = _buildGlobalWarnings(outcomes);

    return PunnettResult(outcomes: outcomes, warnings: warnings);
  }

  /// MorphEntry + het 정보로 부모 유전형 생성 헬퍼
  ///
  /// [morph]: 부모가 보유한 모프
  /// [hetGeneIds]: 추가로 het(보인자)인 유전자 ID 목록
  /// [morphData]: 전체 유전자 데이터
  static ParentGenotype genotypeFromMorph({
    required MorphEntry morph,
    required List<String> hetGeneIds,
    required MorphGeneticsData morphData,
  }) {
    // locusId → LocusGenotype 맵 (좌위 중복 방지)
    final locusMap = <String, LocusGenotype>{};

    // 모프에 포함된 유전자 처리
    for (final geneId in morph.genes) {
      final gene = _findGene(morphData.genes, geneId);
      if (gene == null) continue;

      final locusId = gene.alleleGroup ?? gene.id;
      final inheritance = _normalizeInheritance(gene.inheritance);

      String allele1;
      String allele2;

      if (inheritance == 'recessive') {
        // 열성: 모프에 있으면 호모(a/a)
        allele1 = geneId;
        allele2 = geneId;
      } else {
        // 불완전 우성: 기본 헤테로(wild/A), zygosity=="homozygous"면 호모(A/A)
        if (morph.zygosity == 'homozygous') {
          allele1 = geneId;
          allele2 = geneId;
        } else {
          allele1 = 'wild';
          allele2 = geneId;
        }
      }

      locusMap[locusId] = LocusGenotype(
        locusId: locusId,
        allele1: allele1,
        allele2: allele2,
        inheritance: inheritance,
      );
    }

    // het 유전자 처리 (모프에 없는 경우만 추가)
    for (final geneId in hetGeneIds) {
      final gene = _findGene(morphData.genes, geneId);
      if (gene == null) continue;

      final locusId = gene.alleleGroup ?? gene.id;
      final inheritance = _normalizeInheritance(gene.inheritance);

      // 이미 모프에서 설정된 좌위는 건드리지 않음
      if (locusMap.containsKey(locusId)) continue;

      // 열성 het: wild/a
      // 불완전 우성 het: wild/A (헤테로)
      locusMap[locusId] = LocusGenotype(
        locusId: locusId,
        allele1: 'wild',
        allele2: geneId,
        inheritance: inheritance,
      );
    }

    return ParentGenotype(loci: locusMap.values.toList());
  }

  // ────────────────────────────────────────────
  // Private: 단일 좌위 계산
  // ────────────────────────────────────────────

  /// 단일 좌위의 부모 두 쪽 유전형으로 퍼넷 스퀘어 계산
  ///
  /// 반환: 가능한 (allele1, allele2, probability) 조합 목록
  /// 동일 유전형끼리 확률 합산됨
  static List<_LocusResult> _calculateSingleLocus(
    LocusGenotype father,
    LocusGenotype mother,
  ) {
    // 배우자(gamete) 목록: (allele, 확률)
    final fGametes = _gametes(father);
    final mGametes = _gametes(mother);

    // 결과 누적 맵: "allele1|allele2" → 확률
    final resultMap = <String, double>{};

    for (final fg in fGametes) {
      for (final mg in mGametes) {
        // 정렬 기준: wild는 항상 allele1, 유전자 ID면 알파벳 순
        final String a1;
        final String a2;
        if (fg.allele == 'wild' || (mg.allele != 'wild' && fg.allele.compareTo(mg.allele) <= 0)) {
          a1 = fg.allele;
          a2 = mg.allele;
        } else {
          a1 = mg.allele;
          a2 = fg.allele;
        }

        final key = '$a1|$a2';
        resultMap[key] = (resultMap[key] ?? 0.0) + fg.probability * mg.probability;
      }
    }

    return resultMap.entries
        .map((e) {
          final parts = e.key.split('|');
          return (allele1: parts[0], allele2: parts[1], probability: e.value);
        })
        .toList();
  }

  /// 부모 유전형에서 배우자 목록 추출
  /// 반환: (allele, 확률) 목록 — 각 0.5
  static List<({String allele, double probability})> _gametes(LocusGenotype locus) {
    // 두 대립유전자가 같으면 확률 1.0 하나
    if (locus.allele1 == locus.allele2) {
      return [(allele: locus.allele1, probability: 1.0)];
    }
    return [
      (allele: locus.allele1, probability: 0.5),
      (allele: locus.allele2, probability: 0.5),
    ];
  }

  // ────────────────────────────────────────────
  // Private: 직교곱
  // ────────────────────────────────────────────

  /// 여러 좌위 결과 리스트의 직교곱 생성
  static List<List<_LocusResult>> _cartesianProduct(List<List<_LocusResult>> lists) {
    if (lists.isEmpty) return [[]];

    var result = <List<_LocusResult>>[[]];
    for (final list in lists) {
      final newResult = <List<_LocusResult>>[];
      for (final existing in result) {
        for (final item in list) {
          newResult.add([...existing, item]);
        }
      }
      result = newResult;
    }
    return result;
  }

  // ────────────────────────────────────────────
  // Private: 표현형 이름 매핑
  // ────────────────────────────────────────────

  /// 전체 좌위 유전형 맵에서 표현형 정보 생성
  static _PhenotypeInfo _mapPhenotype(
    _FullGenotypeMap genotypeMap,
    MorphGeneticsData morphData,
    Set<String> allLocusIds,
  ) {
    // 각 좌위별로 발현 상태 분석
    // 발현된 유전자 ID (homo 또는 het) 추적
    final expressedGenes = <String>{}; // 표현형 발현된 유전자
    final superGenes = <String>{}; // 슈퍼폼(호모) 유전자
    final hetGenes = <String>{}; // 헤테로 발현 유전자
    final hetCarrierGenes = <String>{}; // 열성 보인자 유전자
    final genotypeDetails = <String>[];
    String? healthWarning;
    bool isLethal = false;

    for (final locusId in allLocusIds) {
      final lr = genotypeMap[locusId];
      if (lr == null) continue;

      final a1 = lr.allele1;
      final a2 = lr.allele2;

      // wild/wild: 발현 없음
      if (a1 == 'wild' && a2 == 'wild') continue;

      // inheritance 확인
      // 같은 좌위의 유전자 중 첫 번째 비-wild 유전자로 inheritance 조회
      final nonWildAllele = a1 != 'wild' ? a1 : a2;
      final gene = _findGene(morphData.genes, nonWildAllele);
      final inheritance = gene != null ? _normalizeInheritance(gene.inheritance) : 'recessive';

      final isHomo = a1 == a2; // 두 대립유전자 동일
      final isTwoAlleles = a1 != 'wild' && a2 != 'wild' && a1 != a2; // 복합헤테로

      if (inheritance == 'recessive') {
        if (isHomo) {
          // 호모: 발현
          expressedGenes.add(nonWildAllele);

          // 치사 여부 확인
          if (gene?.homozygousLethal == true) {
            isLethal = true;
            final lethalName = gene?.name ?? nonWildAllele;
            final warning = '$lethalName 호모 — 치사 개체';
            healthWarning = healthWarning == null ? warning : '$healthWarning\n$warning';
          } else if (gene?.healthWarning != null) {
            final hw = gene!.healthWarning!;
            healthWarning = healthWarning == null ? hw : '$healthWarning\n$hw';
          }

          final name = gene?.name ?? nonWildAllele;
          genotypeDetails.add(name);
        } else if (isTwoAlleles) {
          // 복합 헤테로: 두 열성 대립유전자 조합
          final crossName = _lookupCrossResult(a1, a2, morphData);
          if (crossName != null) {
            expressedGenes.add(a1);
            expressedGenes.add(a2);
            genotypeDetails.add(crossName);
          } else {
            // 복합 헤테로지만 이름 없음 — 각각 het 표기
            final n1 = _findGene(morphData.genes, a1)?.name ?? a1;
            final n2 = _findGene(morphData.genes, a2)?.name ?? a2;
            hetCarrierGenes.add(a1);
            hetCarrierGenes.add(a2);
            genotypeDetails.add('복합 Het $n1/$n2');
          }
        } else {
          // wild/a: 보인자 (열성은 표현형 미발현)
          hetCarrierGenes.add(nonWildAllele);
          final name = _findGene(morphData.genes, nonWildAllele)?.name ?? nonWildAllele;
          genotypeDetails.add('Het $name');
        }
      } else {
        // incomplete_dominant
        if (isHomo) {
          // 호모: 슈퍼폼
          superGenes.add(nonWildAllele);
          expressedGenes.add(nonWildAllele);

          // 슈퍼폼 건강 경고
          if (gene?.homozygousLethal == true) {
            isLethal = true;
            final lethalName = gene?.name ?? nonWildAllele;
            final warning = '$lethalName 슈퍼폼 — 치사 개체';
            healthWarning = healthWarning == null ? warning : '$healthWarning\n$warning';
          } else {
            // alleleGroup superHealth 조회
            final ag = morphData.alleleGroupFor(nonWildAllele);
            final superHealthNote = ag?.superHealth[nonWildAllele];
            if (superHealthNote != null) {
              healthWarning = healthWarning == null
                  ? superHealthNote
                  : '$healthWarning\n$superHealthNote';
            } else if (gene?.healthWarning != null) {
              final hw = gene!.healthWarning!;
              healthWarning = healthWarning == null ? hw : '$healthWarning\n$hw';
            }

            final name = gene?.name ?? nonWildAllele;
            genotypeDetails.add('슈퍼 $name');
          }
        } else if (isTwoAlleles) {
          // 복합헤테로 (불완전 우성끼리 다른 대립유전자)
          final crossName = _lookupCrossResult(a1, a2, morphData);
          if (crossName != null) {
            expressedGenes.add(a1);
            expressedGenes.add(a2);
            hetGenes.add(a1);
            hetGenes.add(a2);
            genotypeDetails.add(crossName);
          } else {
            final n1 = _findGene(morphData.genes, a1)?.name ?? a1;
            final n2 = _findGene(morphData.genes, a2)?.name ?? a2;
            expressedGenes.add(a1);
            expressedGenes.add(a2);
            hetGenes.add(a1);
            hetGenes.add(a2);
            genotypeDetails.add('$n1/$n2');
          }
        } else {
          // wild/A: 헤테로 발현
          hetGenes.add(nonWildAllele);
          expressedGenes.add(nonWildAllele);

          final name = gene?.name ?? nonWildAllele;
          genotypeDetails.add(name);
        }
      }
    }

    // morphData.morphs에서 표현형 이름 매칭 시도
    final matchedMorph = _matchMorph(
      expressedGenes: expressedGenes,
      superGenes: superGenes,
      hetGenes: hetGenes,
      morphs: morphData.morphs,
    );

    // 표현형 이름 결정
    final String phenotypeName;
    final String? phenotypeNameEn;

    if (isLethal) {
      // 치사 개체는 이름보다 경고 우선
      phenotypeName = genotypeDetails.isNotEmpty ? genotypeDetails.join(' + ') : '치사 개체';
      phenotypeNameEn = null;
    } else if (matchedMorph != null) {
      phenotypeName = matchedMorph.name;
      phenotypeNameEn = matchedMorph.nameEn;
    } else if (genotypeDetails.isEmpty) {
      // 모두 wild/wild
      phenotypeName = '노멀';
      phenotypeNameEn = 'Normal';
    } else {
      phenotypeName = genotypeDetails.join(' + ');
      phenotypeNameEn = null;
    }

    // 유전형 상세 — 매칭된 모프가 있어도 het/보인자 정보는 유지
    final finalDetails = List<String>.from(genotypeDetails);

    // 고유 키 생성 (동일 표현형 합산용)
    // expressedGenes + hetCarrierGenes + superGenes를 정렬해 결정론적 키 구성
    final keyParts = [
      ...expressedGenes.toList()..sort(),
      ...superGenes.map((g) => 'S:$g').toList()..sort(),
      ...hetCarrierGenes.map((g) => 'H:$g').toList()..sort(),
    ];
    final key = keyParts.isEmpty ? 'normal' : keyParts.join(',');

    return _PhenotypeInfo(
      key: key,
      name: phenotypeName,
      nameEn: phenotypeNameEn,
      healthWarning: healthWarning,
      isLethal: isLethal,
      genotypeDetails: finalDetails,
    );
  }

  /// morphs 목록에서 유전자 Set이 일치하는 모프 찾기
  static MorphEntry? _matchMorph({
    required Set<String> expressedGenes,
    required Set<String> superGenes,
    required Set<String> hetGenes,
    required List<MorphEntry> morphs,
  }) {
    if (expressedGenes.isEmpty) return null;

    for (final morph in morphs) {
      final morphGeneSet = morph.genes.toSet();
      if (morphGeneSet != expressedGenes) continue;

      // zygosity 매칭
      if (morph.zygosity == 'homozygous') {
        // 슈퍼폼 모프: 모든 유전자가 superGenes에 있어야 함
        if (superGenes.containsAll(morphGeneSet)) return morph;
      } else if (morph.zygosity == 'heterozygous') {
        // 헤테로 모프
        if (hetGenes.containsAll(morphGeneSet)) return morph;
      } else {
        // zygosity 미지정: 발현 유전자 일치면 매칭
        return morph;
      }
    }
    return null;
  }

  // ────────────────────────────────────────────
  // Private: 전체 교배 경고
  // ────────────────────────────────────────────

  static List<String> _buildGlobalWarnings(List<OffspringOutcome> outcomes) {
    final warnings = <String>[];

    final lethalTotal = outcomes
        .where((o) => o.isLethal)
        .fold<double>(0.0, (sum, o) => sum + o.probability);

    if (lethalTotal > 0) {
      final percent = (lethalTotal * 100).toStringAsFixed(0);
      warnings.add('이 교배에서 약 $percent% 확률로 치사 개체가 발생합니다.');
    }

    return warnings;
  }

  // ────────────────────────────────────────────
  // Private: 유틸리티
  // ────────────────────────────────────────────

  /// 좌위 목록에서 특정 locusId 찾기
  static LocusGenotype? _findLocus(List<LocusGenotype> loci, String locusId) {
    for (final l in loci) {
      if (l.locusId == locusId) return l;
    }
    return null;
  }

  /// 유전자 목록에서 geneId로 찾기
  static MorphGene? _findGene(List<MorphGene> genes, String geneId) {
    for (final g in genes) {
      if (g.id == geneId) return g;
    }
    return null;
  }

  /// 두 대립유전자의 복합 헤테로 이름 조회
  ///
  /// 키: 두 allele를 알파벳 순 정렬 후 "+" 연결
  static String? _lookupCrossResult(String a1, String a2, MorphGeneticsData morphData) {
    // allele가 속한 alleleGroup 찾기
    AlleleGroup? group;
    for (final ag in morphData.alleleGroups) {
      if (ag.members.contains(a1) && ag.members.contains(a2)) {
        group = ag;
        break;
      }
    }
    if (group == null) return null;

    // 키 생성: 알파벳 순 정렬 후 "+" 연결
    final sorted = [a1, a2]..sort();
    final key = sorted.join('+');

    for (final cr in group.crossResults) {
      if (cr.key == key) return cr.name;
    }
    return null;
  }

  /// inheritance 정규화 (codominant → incomplete_dominant로 처리)
  static String _normalizeInheritance(String inheritance) {
    switch (inheritance) {
      case 'incomplete_dominant':
      case 'codominant':
      case 'dominant':
        return 'incomplete_dominant';
      default:
        return 'recessive';
    }
  }
}

// ──────────────────────────────────────────────
// 내부 누적 클래스 (계산 중간 상태)
// ──────────────────────────────────────────────

class _PhenotypeAccumulator {
  final String key;
  final String phenotypeName;
  final String? phenotypeNameEn;
  double probability;
  final String? healthWarning;
  final bool isLethal;
  final List<String> genotypeDetails;

  _PhenotypeAccumulator({
    required this.key,
    required this.phenotypeName,
    this.phenotypeNameEn,
    required this.probability,
    this.healthWarning,
    required this.isLethal,
    required this.genotypeDetails,
  });
}

class _PhenotypeInfo {
  final String key;
  final String name;
  final String? nameEn;
  final String? healthWarning;
  final bool isLethal;
  final List<String> genotypeDetails;

  const _PhenotypeInfo({
    required this.key,
    required this.name,
    this.nameEn,
    this.healthWarning,
    required this.isLethal,
    required this.genotypeDetails,
  });
}
