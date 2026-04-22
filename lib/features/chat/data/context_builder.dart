import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../my_pets/data/pet_repository.dart';
import '../../wiki/data/care_info_repository.dart';
import '../../wiki/data/citation_repository.dart';
import 'chat_repository.dart';
import 'knowledge_repository.dart';
import 'web_search_repository.dart';

final contextBuilderProvider = Provider<ContextBuilder>((ref) {
  return ContextBuilder(ref);
});

class BuildContextResult {
  final List<Map<String, String>> messages;
  final bool hasCareData;
  final String? speciesId;
  final List<String> sources;
  final List<String> citationIds;
  final List<String> webSources; // "title|url" 형식

  const BuildContextResult({
    required this.messages,
    required this.hasCareData,
    this.speciesId,
    this.sources = const [],
    this.citationIds = const [],
    this.webSources = const [],
  });
}

class ContextBuilder {
  final Ref ref;

  ContextBuilder(this.ref);

  static const Map<String, List<String>> categoryKeywords = {
    'temperature': ['온도', '핫존', '쿨존', '바스킹', '히팅', '히터', '서모스탯', '야간', '보온', '난방', '체온'],
    'humidity': ['습도', '탈피', '하이드', '미스팅', '건조', '장마', '수분', '물그릇', '물', '과습', '환기', '분무'],
    'enclosure': ['사육장', '케이지', '기질', '바닥재', '테라리움', '용품', 'UVB', '조명', '바닥', '인테리어', '레이아웃'],
    'diet': ['먹이', '급여', '밀웜', '귀뚜라미', '듀비아', '칼슘', '비타민', '보충제', '식단', '사료', '급수', '식사', '밥'],
    'health': ['병', '질병', '탈피', '꼬리', '구토', '설사', '기생충', '수의사', '화상', '아파', '아픈', '증상', '치료', '건강', '죽'],
    'breeding': ['번식', '교배', '모프', '유전', '인큐', '알', '해칭', '브리딩', '산란', '짝짓기', '임신', '포란', '부화', '인큐베이터'],
  };

  // "자료", "정보", "가이드" 등 포괄적 요청 시 전체 데이터 주입
  static const List<String> _comprehensiveKeywords = [
    '자료', '정보', '가이드', '전체', '전부', '총정리', '사육법', '키우는 법', '기르는 법',
  ];

  static const Map<String, List<String>> _speciesKeywords = {
    'leopard-gecko': ['레오파드', '레파게', '레게'],
    'crested-gecko': ['크레스티드', '크레게', '크레'],
    'fat-tailed-gecko': ['펫테일', '팻테일', '아프리칸'],
  };

  static const String systemPrompt =
      '''게코 사육 전문 AI. 레오파드·크레스티드·펫테일 게코 3종 전문.

규칙:
- [앱 데이터]가 있으면 참고하되 "앱 데이터에 따르면" 같은 메타 언급 없이 바로 답변.
- [앱 데이터]가 없거나 부족해도 3종에 대해선 일반 지식으로 성실히 답변. 거부 금지.
- 3종 외 종 → "현재 지원하지 않는 종입니다." 한 줄로 끝.
- 확실하지 않으면 모른다고 솔직히.
- 병원 가야 할 상황이면 짧게 경고.
- 한국어, 간결체. 서론/반복/출처표기 금지 — 출처는 앱이 자동으로 붙입니다.''';

  Future<BuildContextResult> buildContext({
    required String question,
    required String conversationId,
    String? speciesId,
    String? petId,
  }) async {
    // 1. speciesId 감지 (현재 질문 → 대화 기본값 → 개체 → 이전 대화에서 추출)
    var resolvedSpeciesId =
        detectSpecies(question, speciesId) ?? _speciesFromPet(petId);
    if (resolvedSpeciesId == null) {
      final chatRepo = ref.read(chatRepositoryProvider);
      final history = chatRepo.getRecentMessages(conversationId, limit: 4);
      for (final msg in history) {
        resolvedSpeciesId = detectSpecies(msg.content, null);
        if (resolvedSpeciesId != null) break;
      }
    }

    // 2. 카테고리 감지 (현재 질문 + 이전 대화에서도 감지)
    final categories = detectCategories(question);
    if (categories.isEmpty) {
      final chatRepo = ref.read(chatRepositoryProvider);
      final history = chatRepo.getRecentMessages(conversationId, limit: 4);
      for (final msg in history) {
        categories.addAll(detectCategories(msg.content));
      }
    }

    // 3. 웹 검색을 비동기로 먼저 시작 (병행)
    final webSearchFuture = _searchWeb(question, resolvedSpeciesId);

    // 4. CareInfo 스니펫 (출처 분리)
    String careSnippet = '';
    List<String> sources = [];
    List<String> citationIds = [];
    bool hasCareData = false;

    if (resolvedSpeciesId != null) {
      final snippetResult = await _buildCareSnippet(resolvedSpeciesId, categories);
      careSnippet = snippetResult.snippet;
      sources = snippetResult.sources;
      citationIds = snippetResult.citationIds;
      hasCareData = careSnippet.isNotEmpty;
    }

    // 5. 개체 정보
    final petContext = petId != null ? _buildPetContext(petId) : '';

    // 6. Knowledge 검색
    String knowledgeContext = '';
    if (resolvedSpeciesId != null) {
      final knowledgeRepo = ref.read(knowledgeRepositoryProvider);
      final relevant =
          knowledgeRepo.findRelevant(question, resolvedSpeciesId);
      if (relevant.isNotEmpty) {
        final buf = StringBuffer('\n[관련 지식]\n');
        for (final entry in relevant) {
          buf.writeln('Q: ${entry.question}');
          buf.writeln('A: ${entry.answer}');
        }
        knowledgeContext = buf.toString();
      }
    }

    // 7. 웹 검색 결과 수집
    final webResult = await webSearchFuture;
    String webContext = '';
    final webSources = <String>[];
    if (webResult.success && webResult.items.isNotEmpty) {
      final buf = StringBuffer('\n[웹 검색 참고]\n');
      for (final item in webResult.items) {
        buf.writeln('${item.title}: ${item.description}');
        webSources.add(item.encoded);
      }
      webContext = buf.toString();
    }

    // 8. 최근 대화 히스토리 (최근 6개)
    final chatRepo = ref.read(chatRepositoryProvider);
    final history =
        chatRepo.getRecentMessages(conversationId, limit: 6);

    // 9. messages 배열 조립
    final systemContent = StringBuffer(systemPrompt);
    if (careSnippet.isNotEmpty || petContext.isNotEmpty ||
        knowledgeContext.isNotEmpty || webContext.isNotEmpty) {
      systemContent.write('\n\n[앱 데이터]\n');
      if (careSnippet.isNotEmpty) systemContent.write(careSnippet);
      if (petContext.isNotEmpty) systemContent.write(petContext);
      if (knowledgeContext.isNotEmpty) systemContent.write(knowledgeContext);
      if (webContext.isNotEmpty) systemContent.write(webContext);
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemContent.toString()},
    ];

    for (final msg in history) {
      messages.add({'role': msg.role, 'content': msg.content});
    }

    messages.add({'role': 'user', 'content': question});

    return BuildContextResult(
      messages: messages,
      hasCareData: hasCareData,
      speciesId: resolvedSpeciesId,
      sources: sources,
      citationIds: citationIds,
      webSources: webSources,
    );
  }

  String? detectSpecies(String question, String? hintSpeciesId) {
    for (final entry in _speciesKeywords.entries) {
      for (final keyword in entry.value) {
        if (question.contains(keyword)) return entry.key;
      }
    }
    if (hintSpeciesId != null && hintSpeciesId.isNotEmpty) {
      return hintSpeciesId;
    }
    return null;
  }

  Set<String> detectCategories(String question) {
    for (final keyword in _comprehensiveKeywords) {
      if (question.contains(keyword)) {
        return categoryKeywords.keys.toSet();
      }
    }

    final result = <String>{};
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (question.contains(keyword)) {
          result.add(entry.key);
          break;
        }
      }
    }
    return result;
  }

  String? _speciesFromPet(String? petId) {
    if (petId == null) return null;
    final repo = ref.read(petRepositoryProvider);
    final pet = repo.getPet(petId);
    return pet?.speciesId;
  }

  Future<({String snippet, List<String> sources, List<String> citationIds})> _buildCareSnippet(
    String speciesId,
    Set<String> categories,
  ) async {
    final repo = ref.read(careInfoRepositoryProvider);
    final info = await repo.getCareInfo(speciesId);
    final buffer = StringBuffer();
    buffer.writeln('종: ${info.speciesNameKo} (${info.scientificName})');

    if (categories.contains('temperature')) {
      buffer.writeln(
          '온도: 핫존 ${info.hotZone.display}℃, 쿨존 ${info.coolZone.display}℃, 야간 ${info.night.display}℃');
      if (info.baskingSurface != null) {
        buffer.writeln('바스킹 표면: ${info.baskingSurface!.display}℃');
      }
      if (info.tempNotes != null) buffer.writeln('참고: ${info.tempNotes}');
    }
    if (categories.contains('humidity') ||
        categories.contains('temperature')) {
      buffer.writeln('습도: ${info.humidityMin}~${info.humidityMax}%');
      if (info.humidHide != null) {
        buffer.writeln('습도 하이드: ${info.humidHide!.display}%');
      }
      if (info.humidityNotes != null) {
        buffer.writeln('습도 참고: ${info.humidityNotes}');
      }
    }
    if (categories.contains('enclosure')) {
      buffer.writeln('사육장 최소: ${info.minSize}');
      buffer.writeln('권장 기질: ${info.substrate.join(", ")}');
      if (info.substrateAvoid.isNotEmpty) {
        buffer.writeln('피할 것: ${info.substrateAvoid.join(", ")}');
      }
      buffer.writeln('필수 용품: ${info.essentials.join(", ")}');
      if (info.lighting != null) buffer.writeln('조명: ${info.lighting}');
    }
    if (categories.contains('diet')) {
      buffer.writeln('주식: ${info.mainDiet.join(", ")}');
      if (info.treats.isNotEmpty) {
        buffer.writeln('간식: ${info.treats.join(", ")}');
      }
      buffer.writeln('보충제: ${info.supplements.join(", ")}');
      buffer.writeln('급여 주기: ${info.feedingFrequency}');
      if (info.dietNotes != null) buffer.writeln('먹이 참고: ${info.dietNotes}');
    }
    if (categories.contains('health')) {
      buffer.writeln('초보 실수: ${info.commonMistakes.join("; ")}');
    }
    if (categories.isEmpty) {
      buffer.writeln(
          '난이도: ${info.difficulty}, 수명: ${info.lifespan}, 크기: ${info.adultSize}');
      buffer.writeln('성격: ${info.temperament}');
    }

    // 출처: citation_ids를 CitationRepository로 hydrate.
    // URL(또는 DOI fallback) 있는 citation만 포함. 레거시 형식 'label url' 유지.
    final resolvedSources = <String>[];
    if (info.citationIds.isNotEmpty) {
      final citationRepo = ref.read(citationRepositoryProvider);
      final citations = await citationRepo.hydrate(info.citationIds);
      for (final c in citations) {
        final url = c.resolvedUrl;
        if (url == null) continue;
        final label = (c.publisher != null && c.publisher!.isNotEmpty)
            ? '${c.publisher} — ${c.title}'
            : c.title;
        resolvedSources.add('$label $url');
      }
    }

    return (snippet: buffer.toString(), sources: resolvedSources, citationIds: info.citationIds);
  }

  String _buildPetContext(String petId) {
    final repo = ref.read(petRepositoryProvider);
    final pet = repo.getPet(petId);
    if (pet == null) return '';
    final buffer = StringBuffer('\n[사용자 개체 정보]\n');
    buffer.writeln('이름: ${pet.name}, 종: ${pet.speciesName}');
    if (pet.morph != null) buffer.writeln('모프: ${pet.morph}');
    buffer.writeln('성별: ${pet.sexDisplay}');
    if (pet.ageDisplay.isNotEmpty) buffer.writeln('나이: ${pet.ageDisplay}');
    if (pet.weight != null) buffer.writeln('체중: ${pet.weight}g');
    return buffer.toString();
  }

  /// 웹 검색 (DuckDuckGo Lite). 실패 시 빈 결과 반환.
  Future<WebSearchResult> _searchWeb(
      String question, String? speciesId) async {
    final webRepo = ref.read(webSearchRepositoryProvider);

    // 종 이름을 쿼리에 포함하여 관련성 향상
    final speciesHint = switch (speciesId) {
      'leopard-gecko' => '레오파드 게코',
      'crested-gecko' => '크레스티드 게코',
      'fat-tailed-gecko' => '펫테일 게코',
      _ => '파충류',
    };
    final trimmedQ = question.length > 80 ? question.substring(0, 80) : question;
    final query = '$speciesHint 사육 $trimmedQ';

    return webRepo.search(query, count: 3);
  }
}
