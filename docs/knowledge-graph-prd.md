# PRD — 지식 그래프 + 증거 기반 인용 레이어 (P0.5)

> 작성일: 2026-04-11
> 작성자: 메인 Claude (Designer) — master 레포 설계 동기화 후
> 마스터 SOT: `/Users/baek/tera-ai-product-master/products/app/design/{data-models,architecture,screens,backend}.md` (커밋 `2b341e5`, `c8d3cb1`)
> 관련 문서: `docs/spec.md`, `docs/chat-feature-spec.md`

---

## 1. 컨텍스트 (왜 만드는가)

사업계획서/IR에 **"AI 기반 실시간 지식 그래프 구축 및 증거 기반 리서치"**라는 워딩을 정직하게 쓰기 위해, 현재 자유 텍스트 출처 + 하드코딩된 카테고리 매핑 수준의 구현을 다음 셋이 충족되도록 업그레이드한다.

1. **출처(Citation) 전면화** — 모든 사육 팩트(온습도, 먹이, 질병 등)에 검증 가능한 `citation_id` 부착
2. **종-환경-질병 관계 그래프** — 엔티티-관계가 명시적으로 저장된 구조 (그래프 DB는 미사용, JSON + 메모리 인덱스)
3. **논문/문헌 링크 UI** — 탭 가능한 url_launcher 기반 출처 카드

심사위원이 던질 질문 7개 중 6개를 자신 있게 답할 수 있는 상태가 목표(자동 추출 1개는 Phase 1+ 로드맵으로 정직 답변).

### 1-1. 현재 상태 진단 (구체 위치)

| 위치 | 현재 형태 | 문제 |
|---|---|---|
| `lib/features/wiki/data/care_info_repository.dart:30` | `rootBundle.loadString('assets/data/care_info/$id.json')` 단순 로드 | 출처 메타가 자유 텍스트 |
| `lib/features/wiki/domain/care_info_detail.dart` (확인 필요) | `info.sources: List<String>` 사용 (`context_builder.dart:270` 참조) | 문자열 일치 기반 fragile |
| `lib/features/chat/data/context_builder.dart:45-66` | `_sourceUrls`, `_sourceCategories`가 **Map 상수로 하드코딩** | 데이터/코드 분리 안 됨, 새 출처 추가 시 코드 수정 필요 |
| `lib/features/chat/data/context_builder.dart:268-286` | 카테고리 ↔ 출처 매핑을 string match로 필터 | 사실상 미니 그래프인데 정규화 안 됨 |
| `lib/features/wiki/presentation/wiki_detail_screen.dart` | 출처를 텍스트 나열로만 표시 (확인 필요) | 클릭 불가, 출처 검증 불가 |
| `lib/features/wiki/data/`, `lib/features/wiki/domain/` | citation/graph 없음 | 신규 도입 |
| `lib/shared/widgets/` | **폴더 자체 없음** | 공용 위젯 신규 도입 |

### 1-2. 핵심 인사이트

`context_builder.dart`의 `_sourceUrls` + `_sourceCategories` 구조는 **이미 미니 지식 그래프**다. 출처(노드) ↔ 카테고리(노드) ↔ 종(암묵적 노드)의 관계를 코드 안에 박아둔 것. 이번 PRD의 본질은 **"그 하드코딩을 외부 JSON으로 들어내고, 동시에 종↔환경↔질병 차원을 추가한다"**이다.

---

## 2. CAOF 트랙

**Standard 트랙** — Designer 분석 → flutter-dev 구현 → 자체 검수.

근거:
- 새 외부 패키지 없음 (`url_launcher: ^6.3.1` 이미 있음, `pubspec.yaml:24`)
- 새 디렉토리 1개(`lib/shared/widgets/`)와 기존 wiki feature 확장
- DB 스키마 변경 없음 (Hive 기존 모델 미수정 — citationIds는 채팅 응답에서 별도 추출, 후속 단계)
- 화면 1개 신규 + 1개 수정
- 되돌리기 비용: 중간 (assets/data 신규 파일은 git revert로 즉시 복원, context_builder 리팩토링은 한 함수 범위)

Critical 아닌 이유: Hive typeId 변경/추가 없음, 라우팅 핵심 흐름 변경 없음.

---

## 3. 목표 (Definition of Done)

### MUST (이번 PRD 완료 조건)

1. `assets/data/citations.json`, `assets/data/graph.json`이 번들에 포함되고 `pubspec.yaml`에 등록된다 (이미 `assets/data/`가 등록돼 있어 추가 등록 불필요)
2. `CitationRepository`, `GraphRepository`가 부팅 후 1회 로드 + 메모리 인덱스를 유지한다
3. `WikiDetailScreen`의 출처 섹션이 **탭 가능한 Citation 카드**로 표시되고, 탭하면 `url_launcher`로 외부 브라우저가 열린다
4. `WikiDetailScreen`에 **"관련 정보(Graph)" 섹션**이 추가돼 종 → 환경/질병/먹이 관계를 카드로 노출하고, 카드를 탭하면 `GraphDetailScreen`으로 이동한다
5. `GraphDetailScreen`이 임의 엔티티(env_cond/disease/food/equipment) 상세를 outgoing/incoming 관계 + 출처 카드로 표시한다
6. `context_builder.dart`의 `_sourceUrls`/`_sourceCategories` 하드코딩이 제거되고 `CitationRepository`/`GraphRepository` 주입으로 대체된다
7. `flutter analyze` 에러 0
8. 사용자 디바이스에서 `flutter run` → 레오파드 게코 → 출처 탭 → 외부 브라우저에서 ReptiFiles 페이지 열림이 확인된다 (golden path)

### SHOULD (있으면 좋음, 없어도 PRD는 완료)

- `ChatScreen`에서 AI 응답의 `[cit-xxx]` 토큰을 `[1] [2]` 번호로 치환 + 인용 칩 노출
- 토큰 0개 응답에 `⚠ 출처 미확인` 배지

### WILL NOT (이번 PRD 비목표)

- Hive 모델 schema 변경 (`ChatMessage.citationIds` 필드 추가는 다음 PR로 분리 — typeId 영향 사전 검토 필요)
- Supabase CMS 셋업 (master 레포의 `backend.md`에 설계만 존재, 실제 구축은 별도 트랙)
- citations.json 큐레이션 데이터의 URL 검증 (사용자 본인 액션, 본 PRD 외부)
- 그래프 DB 도입 (Neo4j 등) — 명시적으로 거부. 메모리 Map으로 충분
- AI 답변에서 [cit-xxx] 토큰 자동 추출/저장 — SHOULD에 포함되지만 typeId 변경이 필요해 별도 PR 권장

---

## 4. 변경 범위

### 4-1. 신규 파일

| 경로 | 역할 |
|---|---|
| `assets/data/citations.json` | 출처 메타 (master 레포 `c8d3cb1`에서 가져옴, 6개 항목) |
| `assets/data/graph.json` | Entity/Relation (24 엔티티 + 30 관계, 레오파드 게코 풀스택) |
| `lib/features/wiki/domain/citation.dart` | `Citation` 모델 + `CitationType`/`CitationConfidence` enum + `fromJson` |
| `lib/features/wiki/domain/graph_entity.dart` | `Entity`, `Relation` 모델 + `EntityKind`/`RelationType` enum + `fromJson` |
| `lib/features/wiki/data/citation_repository.dart` | `assets/data/citations.json` 1회 로드, `byId(id)` / `hydrate(List<String>)` API. Riverpod `Provider` 노출 |
| `lib/features/wiki/data/graph_repository.dart` | `assets/data/graph.json` 1회 로드, 메모리 인덱스(`_byFrom`/`_byTo`/`_byType`) 빌드, `outgoing`/`incoming`/`neighbors(depth=2)` API |
| `lib/features/wiki/presentation/graph_detail_screen.dart` | `/graph/:kind/:entityId` 라우트 화면. 엔티티 라벨 + payload + outgoing/incoming + Citation 카드 |
| `lib/shared/widgets/citation_card.dart` | 재사용 위젯. 제목/저자/연도/감수자/confidence 표시, 탭 → `url_launcher`. URL 없으면 DOI fallback, 둘 다 없으면 비활성 + ⓘ 표시 |
| `lib/shared/widgets/relation_card.dart` | 재사용 위젯. 관계 라벨 + 대상 엔티티 라벨 + → 화살표 (탭 → GraphDetailScreen) |

### 4-2. 수정 파일

| 경로 | 변경 내용 |
|---|---|
| `lib/features/wiki/data/care_info_repository.dart` | 변경 없음 (citation_id는 care_info JSON에 이미 포함됨) |
| `lib/features/wiki/domain/care_info_detail.dart` | (확인 필요) `citationIds: List<String>` 필드 추가, `fromJson`에서 `json['citation_ids']` 파싱. 기존 `sources: List<String>`은 `@Deprecated` 보존 |
| `lib/features/wiki/presentation/wiki_detail_screen.dart` | 출처 섹션을 `CitationCard` 리스트로 교체. 신규 "관련 정보(Graph)" 섹션 — `GraphRepository.outgoing("ent-species-$speciesId")`로 관계를 그룹핑 표시. `RelationCard` 재사용 |
| `lib/core/router/app_router.dart` | wiki 브랜치 안에 `GoRoute(path: 'graph/:kind/:entityId', ...)` 추가 → `/wiki/graph/:kind/:entityId` 라우트 등록 (또는 최상위 `/graph/...` — 둘 중 wiki 브랜치 nested 권장, BottomNav 탭 컨텍스트 유지) |
| `lib/features/chat/data/context_builder.dart` | `_sourceUrls`/`_sourceCategories` 하드코딩 Map 삭제. 대신 `CitationRepository.byId(citationId).url` 사용. `_buildCareSnippet` 안에서 `info.sources` 대신 `info.citationIds`로 hydrate. **그래프 컨텍스트 주입은 SHOULD/별도 PR**. |
| `lib/features/wiki/data/care_info_repository.dart` | (옵션) `getMorphData` 옆에 `getCareInfoWithCitations(speciesId)` 헬퍼 추가 — citationIds까지 한 번에 hydrate |

### 4-3. 데이터 마이그레이션

이미 `assets/data/care_info/leopard-gecko.json` 등이 있는데, 거기에 `citation_ids` 필드를 부착해야 한다. **마스터 레포 commit `c8d3cb1`의 leopard-gecko.json 변경분을 그대로 가져와 적용**:

```json
"citation_ids": [
  "cit-reptifiles-leogecko-01",
  "cit-biodude-leogecko-01",
  "cit-zenhab-substrate-01",
  "cit-reptizen-feeding-01",
  "cit-devosjoli-leogecko-01",
  "cit-tera-internal-01"
],
"graph_entity_id": "ent-species-leogecko",
```

같은 패턴으로 `crested-gecko.json`, `fat-tailed-gecko.json`도 부착해야 하지만 **시연용 1종(레오파드 게코)만 풀스택으로 큐레이션**, 나머지는 빈 배열 + `_note: "P0.5 큐레이션 대기"`로 둔다. 큐레이션 진행 시 본인 검증 후 채움.

---

## 5. 데이터 — 절대 규칙 (정정판)

`citations.json`의 `url`/`doi`는 **LLM이 메모리만으로 추측한 값**을 절대 넣지 않는다. 그러나 **WebSearch + WebFetch로 실제 웹 페이지에 접속해 검증**하는 것은 추론이 아니라 사실 확인이므로 권장된다. 도메인 차이를 명확히 — 이미지 ref 환각은 생성 시점에 사후 검증 불가능하지만, 텍스트 출처는 웹에 실재하는 객체라 fetch로 진위 확인이 가능하다.

### 3단계 confidence 승격

| confidence | 의미 | 누가 |
|---|---|---|
| `unverified` | 미검증, url=null, reviewed_*=null | 큐레이션 초안 |
| `medium` | URL 실재 + 페이지 본문이 본 그래프와 정합 확인 | Claude (`reviewed_by: claude-web-verified`) |
| `high` | 전문가 직접 감수 또는 단행본 본문 인용 정합 | 사용자 본인 (`reviewed_by: expert-XXX`) |

### 현재 상태 (2026-04-11)

5개 외부 citation은 이미 Claude WebSearch+WebFetch 검증을 통과해 `medium`으로 승격됨 (master 레포 `products/app/data/citations.json`):

- `cit-reptifiles-leogecko-01` — `https://reptifiles.com/leopard-gecko-care/`
- `cit-biodude-leogecko-01` — `https://www.thebiodude.com/blogs/gecko-caresheets/leopard-gecko-caresheet-2024-updated`
- `cit-zenhab-substrate-01` — `https://www.zenhabitats.com/blogs/reptile-care-sheets-resources/leopard-gecko-complete-substrate-guide`
- `cit-reptizen-feeding-01` — `https://reptizen.com/leopard-gecko-feeding-guide/`
- `cit-devosjoli-leogecko-01` — ISBN 9781620082591 (단행본, url은 Amazon 상품 페이지 fallback)

`cit-tera-internal-01`은 자체 노트라 unverified 유지. 사용자가 노트를 작성하거나 출처 자체 삭제 결정을 내릴 때까지.

**`high` 승격 조건 (사용자 본인 액션):** 수의사/사육 전문가 감수 + de Vosjoli 책 본문 인용 정합 확인.

### 사이드 발견 — context_builder.dart 죽은 링크

검증 과정에서 Flutter 레포 `lib/features/chat/data/context_builder.dart:50-51`의 두 하드코딩 URL이 404임을 발견했다:

| 항목 | 코드의 잘못된 URL | 실제 URL |
|---|---|---|
| The Bio Dude | `/blogs/how-to-guides/leopard-gecko-care-sheet` | `/blogs/gecko-caresheets/leopard-gecko-caresheet-2024-updated` |
| Zen Habitats | `/blogs/reptile-care-sheets` | `/blogs/reptile-care-sheets-resources/leopard-gecko-complete-substrate-guide` |

이 PRD의 Step 6(`context_builder.dart` 하드코딩 제거)에서 `_sourceUrls` Map 자체를 `CitationRepository`로 외부화하면 자동으로 정정된다 — 별도 PR 불필요.

---

## 6. 작업 순서 (flutter-dev에게)

각 단계 끝에 commit, `flutter analyze` 통과 확인.

### Step 1 — 데이터 + 모델 부트스트랩 (commit: `feat: knowledge-graph data + domain`)
1. `assets/data/citations.json`, `assets/data/graph.json` 추가 (master 레포 commit `c8d3cb1`에서 복사)
2. `assets/data/care_info/leopard-gecko.json`에 `citation_ids` + `graph_entity_id` 부착
3. `lib/features/wiki/domain/citation.dart` 생성 — Citation 모델 + 두 enum + fromJson
4. `lib/features/wiki/domain/graph_entity.dart` 생성 — Entity, Relation 모델 + 두 enum + fromJson
5. `flutter analyze` 통과 확인 (이 단계는 사용처 없어 경고만 나면 OK)

### Step 2 — Repository 레이어 (commit: `feat: citation/graph repository with in-memory index`)
1. `lib/features/wiki/data/citation_repository.dart` 생성 — `Provider`, `load()`, `byId()`, `hydrate()`
2. `lib/features/wiki/data/graph_repository.dart` 생성 — `Provider`, `load()`, 메모리 인덱스 빌드, `outgoing`/`incoming`/`neighbors`
3. `flutter analyze` 통과
4. (옵션) `test/features/wiki/data/graph_repository_test.dart` — `outgoing("ent-species-leogecko", REQUIRES_TEMP)` 결과가 4개인지 등 단위 테스트

### Step 3 — 공용 위젯 (commit: `feat: citation_card + relation_card widgets`)
1. `lib/shared/widgets/` 폴더 신규 생성
2. `citation_card.dart` — Citation 받아 카드 렌더링, 탭 → `url_launcher.launchUrl`. confidence별 색상 배지
3. `relation_card.dart` — Relation + 대상 Entity 라벨 받아 렌더링, onTap 콜백
4. `flutter analyze` 통과

### Step 4 — WikiDetailScreen 출처 섹션 교체 (commit: `feat(wiki): citation cards + graph relations section`)
1. `wiki_detail_screen.dart`에서 기존 출처 텍스트 섹션 찾아 `CitationCard` 리스트로 교체
2. 본문 로드 시 `careInfoRepository.getCareInfo(id)` 후 `citationIds`를 `citationRepository.hydrate()`로 변환 → 카드 빌드
3. 신규 "관련 정보" 섹션 추가 — `graphRepository.outgoing("ent-species-$speciesId")` 후 `RelationType`별 그룹핑 → `RelationCard` 리스트
4. `RelationCard` onTap → `context.go('/wiki/graph/${entity.kind.name}/${entity.id}')`
5. `flutter analyze` + 사용자 확인용 핫리로드 시연 가능 상태

### Step 5 — GraphDetailScreen + 라우터 (commit: `feat(wiki): GraphDetailScreen + route`)
1. `lib/features/wiki/presentation/graph_detail_screen.dart` 생성 — `kind`, `entityId` 파라미터, 헤더/outgoing/incoming/citations 섹션
2. `lib/core/router/app_router.dart`의 wiki 브랜치 안에 GoRoute 추가
3. `flutter analyze` 통과
4. 핸드 테스트: 레오파드 게코 → MBD 카드 탭 → GraphDetailScreen → "원인: UVB 약/무" 카드 탭 → 또 다른 GraphDetailScreen 드릴다운

### Step 6 — context_builder 하드코딩 제거 (commit: `refactor(chat): externalize source mapping to citation_repository`)
1. `_sourceUrls`, `_sourceCategories` Map 상수 삭제
2. `_buildCareSnippet`에서 `info.sources` 대신 `info.citationIds` 사용, `citationRepository.hydrate()`로 변환
3. 출처 표시 형식은 기존 `'$source $url'` 유지(채팅 출력 형식 변경 회피 — 별도 PR)
4. `flutter analyze` + 채팅 핸드 테스트 ("레오파드 핫존 온도?" → 응답 + 출처 URL 정상)

### Step 7 — 검증 + PR (commit: 없음, PR 생성)
- `flutter test` 통과 (있다면)
- `gh pr create` (제목: `feat: P0.5 지식 그래프 + 증거 기반 인용 레이어`)

**총 commit 6개, 단일 PR로 머지.**

---

## 7. 검증 시나리오 (수동 QA)

`flutter run`으로 디바이스에서:

1. **출처 탭 → 외부 브라우저** — Wiki → 레오파드 게코 → 온도 → 출처 카드 탭 → ReptiFiles 페이지 열림 (단, citations.json url이 채워진 경우만. 미검증이면 ⓘ 비활성)
2. **그래프 드릴다운** — Wiki → 레오파드 게코 → "관련 정보" → "이 종이 잘 걸리는 질병: 대사성 골질환(MBD)" → GraphDetailScreen → "원인: UVB 약/무" → 또 다른 GraphDetailScreen
3. **incoming 관계** — GraphDetailScreen에서 MBD 진입 → "이 질병에 취약한 종: 레오파드 게코" 노출 + 탭 → species 페이지로 복귀
4. **챗봇 회귀** — Chat에서 "레오파드 게코 핫존 온도 알려줘" → 응답 + 출처 URL이 기존과 동일하게 노출 (refactor가 회귀 안 일으켰는지)
5. **미검증 출처 배지** — confidence:unverified citation은 카드 상단에 ⚠ 표시
6. **flutter analyze** 0 에러
7. **타 종 회귀** — crested-gecko, fat-tailed-gecko 화면이 깨지지 않는지 (citation_ids 빈 배열로 둠)

---

## 8. 의존성

- **신규 패키지: 0개** (`url_launcher: ^6.3.1` 이미 `pubspec.yaml:24`에 있음)
- **신규 assets 등록: 0개** (`assets/data/`가 이미 `pubspec.yaml:38`에 등록됨, 새 JSON 파일은 그대로 인식됨)
- **Hive typeId 영향: 없음** (이번 PRD에서는 Hive 모델 미수정. `ChatMessage.citationIds`는 별도 PR)

---

## 9. 위험과 완화

| 위험 | 완화 |
|---|---|
| `_sourceUrls` 리팩토링이 채팅 출처 노출에 회귀 일으킴 | Step 6를 마지막으로 미루고, 검증 시나리오 4번을 의무화 |
| LLM이 만든 가짜 URL이 그대로 들어감 | confidence=unverified로 강제 시작, UI ⚠ 배지, URL=null이면 카드 비활성 |
| GraphDetailScreen 무한 드릴다운 | `neighbors(depth=2)` 상한 + 라우터 진입 시 BackStack은 GoRouter 기본 동작에 위임 |
| `crested-gecko.json` 등 citation_ids 없는 종에서 NPE | Repository에서 빈 배열 기본값 보장 + `CitationCard` null 체크 |
| GoRoute 경로 충돌 (`:speciesId/:category` vs `graph/:kind/:entityId`) | `graph`를 정적 prefix로 두면 GoRouter가 우선 매칭 — 명시적 경로가 동적 파라미터보다 먼저 |
| 그래프 JSON 파싱 실패 | `GraphRepository.load()`에서 try/catch + AppException으로 ErrorScreen 라우팅 |
| Step 6 전후 채팅 회귀를 사용자가 못 알아챔 | Step 6 commit 메시지에 "회귀 검증 필수" 명시 + PR 본문 체크리스트 |

---

## 10. 심사위원 Q&A 방어 시뮬레이션

| 질문 | 답변 가능 여부 | 근거 |
|---|---|---|
| 그래프 DB 뭐 써요? | ✅ "Postgres 정규화(설계 단계) + 앱은 메모리 Map 인덱스. 수십 종 규모에 Neo4j는 과잉." | `graph_repository.dart` |
| 실시간 업데이트 주기? | ✅ "P0.5는 앱 번들 주1회, P1은 Supabase Storage 1시간 폴링." | master backend.md |
| 출처 검증 수준? | ✅ "각 citation에 reviewed_by + confidence. 미감수는 ⚠ 배지." | citations.json + CitationCard UI |
| 엔티티 관계가 실제로 저장되나? | ✅ `graph.json` + `GraphRepository.outgoing/incoming` | Step 2 |
| 사용자가 출처 확인 가능? | ✅ url_launcher 카드 (Wiki/Chat 양쪽) | Step 4, 6 |
| 근거 없는 응답 처리? | ⚠ SHOULD 항목 — 별도 PR | 본 PRD 비목표 |
| 엔티티 자동 추출되나? | ⚠ "Phase 0.5는 LLM 초안 + 전문가 감수. 자동 추출은 Phase 1+." (정직 답변) | master 데이터 큐레이션 정책 |

---

## 11. 후속 PR 후보 (이번 PRD 외부)

1. **`feat(chat): citationIds in ChatMessage + token parsing`** — Hive `ChatMessage`에 `@HiveField(7) List<String> citationIds` 추가, 응답에서 `[cit-xxx]` 토큰 추출 + 칩 UI. **typeId 영향 0이지만 HiveField 신규 등록 + 마이그레이션 코드 필요 → Critical 트랙 검토**
2. **`feat(chat): graph context injection in context_builder`** — `GraphRepository.neighbors(depth=2)` 결과를 시스템 프롬프트 `[관련 그래프]` 섹션으로 주입, AI가 `[cit-xxx]` 인용 강제
3. **`feat(backend): Supabase CMS bootstrap`** — master `backend.md`의 Phase 0.5 스키마를 Supabase에 적용 + GitHub Action 익스포트 스크립트
4. **`docs(curation): citation 검증 + crested/fat-tailed gecko 큐레이션`** — 사용자 본인 작업, 코드 변경 없음

---

## 12. 참고

- 마스터 SOT 커밋: `2b341e5` (설계 5종), `c8d3cb1` (샘플 데이터), `0dcfbb3` (donts audit)
- 마스터 브랜치: `feat/knowledge-graph-layer` (`/Users/baek/tera-ai-product-master/`)
- 본 PRD가 master의 `backend.md`/`data-models.md`/`screens.md`/`architecture.md`와 충돌하면 master를 SOT로 본다 (master 갱신 → 본 PRD 갱신)
