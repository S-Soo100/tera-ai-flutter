# Tera AI Chat — 기능 명세서 v1.0

> 최종 업데이트: 2026-04-10
> 상태: P0 구현 완료, 개선 검토 대상

---

## 1. 개요

파충류 사육자가 자연어로 질문하면 AI가 앱 내 검증 데이터 + 일반 지식을 조합하여 답변하는 채팅 시스템.
단순 휘발성 챗봇이 아니라 **대화 영속화 + 지식 캐시 축적** 구조.

### 핵심 가치
| 가치 | 설명 |
|------|------|
| 검증된 정보 우선 | 앱 내 care_info JSON(출처 명시)을 컨텍스트로 주입 |
| 개인 맞춤 | 사용자 등록 개체(종, 나이, 체중) 반영 |
| 지식 축적 | Q&A에서 재사용 가능한 지식을 자동 추출·캐싱 |
| 한도 관리 | 디바이스 단위 일일 한도 (Release: 20회, Debug: 999회) |

---

## 2. 아키텍처

```
lib/features/chat/
├── domain/                          # Hive 모델
│   ├── conversation.dart            # typeId: 2 — 대화 세션
│   ├── chat_message.dart            # typeId: 3 — 개별 메시지
│   ├── knowledge_entry.dart         # typeId: 4 — 축적된 지식
│   └── chat_quota.dart              # typeId: 5 — 일일 한도
├── data/                            # 비즈니스 로직
│   ├── chat_repository.dart         # 대화/메시지/한도 CRUD
│   ├── knowledge_repository.dart    # 지식 캐시 검색·축적
│   ├── groq_api_repository.dart     # Groq API 호출
│   ├── context_builder.dart         # 프롬프트 조립기 (핵심)
│   └── knowledge_extractor.dart     # 규칙 기반 지식 추출
└── presentation/                    # UI
    ├── chat_providers.dart          # Riverpod 상태 관리
    ├── chat_screen.dart             # 채팅 화면
    ├── chat_list_screen.dart        # 대화 기록 목록
    └── widgets/
        ├── chat_bubble.dart         # 메시지 버블 (URL 링크 지원)
        └── quota_indicator.dart     # 한도 표시 바
```

### 의존성
| 패키지 | 용도 |
|--------|------|
| `http` | Groq API HTTP 호출 |
| `flutter_dotenv` | .env 파일에서 API 키 로드 |
| `url_launcher` | 출처 URL 브라우저 열기 |
| `hive` / `hive_flutter` | 로컬 데이터 영속화 (기존) |
| `flutter_riverpod` | 상태 관리 (기존) |
| `uuid` | ID 생성 (기존) |

---

## 3. 데이터 모델

### 3.1 Conversation (Hive typeId: 2)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | UUID |
| title | String | 첫 질문 앞 30자로 자동 생성, 수정 가능 |
| petId | String? | 개체 연동 시 해당 개체 ID |
| speciesId | String? | 종 컨텍스트 (진입 시 설정) |
| createdAt | DateTime | 생성 시각 |
| updatedAt | DateTime | 마지막 메시지 시각 |
| messageCount | int | 메시지 수 |
| tags | List\<String\> | 자동 태깅 (미사용, P2 대비) |
| isArchived | bool | 소프트 삭제 |

### 3.2 ChatMessage (Hive typeId: 3)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | UUID |
| conversationId | String | 소속 대화 ID |
| role | String | `"user"` 또는 `"assistant"` |
| content | String | 메시지 본문 |
| createdAt | DateTime | 생성 시각 |
| tokenCount | int? | AI 응답 토큰 수 (user 메시지는 null) |
| fromCache | bool | 캐시 답변 여부 (기본 false) |

### 3.3 KnowledgeEntry (Hive typeId: 4)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | String | UUID |
| question | String | 정규화된 질문 |
| answer | String | AI 답변 (최대 500자) |
| speciesId | String | 해당 종 |
| category | String | temperature/humidity/diet/health/... |
| keywords | List\<String\> | 검색용 키워드 |
| createdAt | DateTime | 생성 시각 |
| useCount | int | 검색 매칭 횟수 (증가할수록 신뢰도 상승) |
| confidence | double | 0.0~1.0 (초기값 0.5) |
| sourceConversationId | String | 원본 대화 ID |

### 3.4 ChatQuota (Hive typeId: 5)

| 필드 | 타입 | 설명 |
|------|------|------|
| date | String | `"YYYY-MM-DD"` (Hive key로 사용) |
| messageCount | int | 당일 사용 횟수 |

---

## 4. AI 프로바이더

### 4.1 현재 설정

| 항목 | 값 |
|------|-----|
| 프로바이더 | Groq |
| 엔드포인트 | `https://api.groq.com/openai/v1/chat/completions` |
| 모델 | `llama-3.3-70b-versatile` |
| API 키 | `.env` 파일 (`GROQ_API_KEY`) |
| max_tokens | 1024 |
| temperature | 0.3 |
| timeout | 30초 |
| 프로토콜 | OpenAI 호환 (POST /v1/chat/completions) |

### 4.2 에러 처리

| 상황 | 반환값 | UI 표시 |
|------|--------|---------|
| API 키 미설정 | `error: 'GROQ_API_KEY not set'` | "답변을 가져오지 못했습니다" |
| Rate limit (429) | `error: 'rate_limit'` | "답변을 가져오지 못했습니다" |
| 기타 HTTP 에러 | `error: 'HTTP <code>'` | "답변을 가져오지 못했습니다" |
| 네트워크 에러 | `error: 'network_error: ...'` | "답변을 가져오지 못했습니다" |
| 타임아웃 | catch로 잡힘 | "답변을 가져오지 못했습니다" |

### 4.3 교체 가능성

OpenAI 호환 API이므로 `_baseUrl` + `_model` + API 키만 변경하면 DeepSeek, OpenRouter 등으로 교체 가능.

---

## 5. 컨텍스트 빌딩 파이프라인

### 5.1 전체 흐름

```
사용자 질문
    │
    ▼
① 종 감지 ─────────────────────────────────────────────
   질문 키워드 → 대화 기본값(speciesId) → 개체(petId) → 이전 대화 4개 스캔
    │
    ▼
② 카테고리 감지 ────────────────────────────────────────
   질문 키워드 매칭 → 포괄적 요청("자료","정보") 시 전체 카테고리
   매칭 없으면 → 이전 대화 4개 스캔
    │
    ▼
③ care_info 스니펫 조립 ────────────────────────────────
   CareInfoRepository → 매칭된 카테고리 섹션만 텍스트로 변환
   카테고리 있으면 출처 URL도 포함
    │
    ▼
④ 개체 정보 주입 (petId 있는 경우) ─────────────────────
   PetRepository → 이름, 종, 모프, 성별, 나이, 체중
    │
    ▼
⑤ 캐시 지식 검색 ──────────────────────────────────────
   KnowledgeRepository.findRelevant() → 상위 3개 Q&A 주입
    │
    ▼
⑥ 대화 히스토리 ───────────────────────────────────────
   최근 6개 메시지 (user/assistant 교대)
    │
    ▼
⑦ messages 배열 조립 ──────────────────────────────────
   [system: 프롬프트 + 앱 데이터] + [히스토리] + [user: 질문]
```

### 5.2 종 감지 (`detectSpecies`)

**우선순위:** 질문 키워드 > 대화 기본값 > 개체 종 > 이전 대화

| speciesId | 감지 키워드 |
|-----------|-----------|
| `leopard-gecko` | 레오파드, 레파게, 레게 |
| `crested-gecko` | 크레스티드, 크레게, 크레 |
| `fat-tailed-gecko` | 펫테일, 팻테일, 아프리칸 |

### 5.3 카테고리 감지 (`detectCategories`)

| 카테고리 | 감지 키워드 |
|---------|-----------|
| temperature | 온도, 핫존, 쿨존, 바스킹, 히팅, 히터, 서모스탯, 야간, 보온, 난방, 체온 |
| humidity | 습도, 탈피, 하이드, 미스팅, 건조, 장마, 수분, 물그릇, 물, 과습, 환기, 분무 |
| enclosure | 사육장, 케이지, 기질, 바닥재, 테라리움, 용품, UVB, 조명, 바닥, 인테리어, 레이아웃 |
| diet | 먹이, 급여, 밀웜, 귀뚜라미, 듀비아, 칼슘, 비타민, 보충제, 식단, 사료, 급수, 식사, 밥 |
| health | 병, 질병, 탈피, 꼬리, 구토, 설사, 기생충, 수의사, 화상, 아파, 아픈, 증상, 치료, 건강, 죽 |
| breeding | 번식, 교배, 모프, 유전, 인큐, 알, 해칭, 브리딩, 산란, 짝짓기, 임신, 포란, 부화, 인큐베이터 |

**포괄적 요청 키워드** (전체 카테고리 활성화):
`자료`, `정보`, `가이드`, `전체`, `전부`, `총정리`, `사육법`, `키우는 법`, `기르는 법`

### 5.4 care_info 스니펫 구성

| 카테고리 | 주입 데이터 |
|---------|-----------|
| temperature | 핫존, 쿨존, 야간, 바스킹(선택), 참고 + 습도 범위 |
| humidity | 습도 범위, 습도 하이드(선택), 습도 참고 |
| enclosure | 최소 크기, 권장/회피 기질, 필수 용품, 조명 |
| diet | 주식, 간식, 보충제, 급여 주기, 먹이 참고 |
| health | 초보 실수 목록 |
| (매칭 없음) | 난이도, 수명, 크기, 성격 (기본 정보) |

출처 URL은 **카테고리 매칭이 있을 때만** 포함.

### 5.5 시스템 프롬프트 (현재)

```
게코 사육 전문 AI. 레오파드·크레스티드·펫테일 게코 3종 전문.

답변 규칙:
- [앱 데이터]가 있으면 참고하되 메타 설명 없이 바로 답변.
- [앱 데이터]가 없거나 부족해도 3종에 대해선 일반 지식으로 성실히 답변. 거부 금지.
- 3종 외 종 → "현재 지원하지 않는 종입니다." 한 줄로 끝.
- 확실하지 않으면 솔직하게 모른다고.
- 병원 가야 할 상황이면 짧게 경고.
- 한국어, 간결체. 서론/반복 금지.

출처 규칙:
- 답변에 실제로 활용한 근거가 있을 때만 "📎 출처:"를 달아.
- 활용하지 않은 출처는 절대 나열하지 마.
- 외부 출처 URL을 확실히 아는 경우만 포함. 가짜 URL 금지.
- 근거 없는 일반 상식이면: "⚠️ 일반 지식 기반입니다. 전문가 확인을 권장합니다."
```

---

## 6. 지식 축적 시스템

### 6.1 지식 추출 (`KnowledgeExtractor`)

**추출 조건** (모두 충족 시):
1. AI 응답 길이 >= 100자
2. 질문이 인사가 아님 (안녕, 하이, hi, hello, 감사, 고마워)
3. 질문에 사육 관련 키워드 1개 이상 포함

**추출 결과:**
- `question`: 원본 질문 (trim)
- `answer`: AI 응답 (최대 500자 잘림)
- `category`: 키워드 매칭이 가장 많은 카테고리 (없으면 `'general'`)
- `keywords`: 질문+응답 합친 텍스트에서 추출
- `confidence`: 초기값 0.5
- `useCount`: 초기값 0

### 6.2 키워드 추출 알고리즘

```
입력 텍스트
  → 비문자/비한글 제거 (정규식)
  → 소문자화
  → 공백 분리
  → 길이 2 미만 토큰 제거
  → 불용어 32개 제거 (이,가,은,는,을,를,...)
  → 중복 제거 (Set)
```

### 6.3 관련도 스코어링 (`findRelevant`)

```
score = keyword_overlap * confidence * (1 + log(useCount + 1))
```

| 변수 | 설명 |
|------|------|
| keyword_overlap | 질문 키워드 ∩ 엔트리 키워드의 크기 |
| confidence | 0.0~1.0 (초기 0.5) |
| useCount | 검색 매칭 횟수 (사용할수록 증가) |

- `overlap == 0` → 즉시 스킵
- `score <= 0.5` → 필터 아웃
- 상위 3개 반환

### 6.4 캐시 히트 판정

```
score > 2.0 → 캐시 히트
```

- 캐시 히트 시 API 호출 없이 기존 답변 반환
- 일일 한도 미차감
- UI에 "즉시 답변" 배지 표시

### 6.5 지식 축적 라이프사이클

```
Day 1: "탈피가 안 벗겨져요" 질문
  → AI 응답 → KnowledgeEntry 저장 (confidence:0.5, useCount:0)

Day 3: "발가락에 탈피 껍질" 질문
  → 키워드 "탈피" 매칭 → Day1 엔트리를 컨텍스트에 주입
  → AI가 더 정확한 응답 (이전 지식 참고)
  → useCount +1

Day 10: 비슷한 탈피 질문
  → score > 2.0 (confidence 증가 + useCount 누적)
  → 캐시 히트! API 미호출, 즉시 응답
```

---

## 7. 한도 관리

| 항목 | Debug | Release |
|------|-------|---------|
| 일일 한도 | 999회 | 20회 |
| 판정 기준 | `kDebugMode` | `kDebugMode` |
| 캐시 히트 | 미차감 | 미차감 |
| 리셋 시점 | 자정 (날짜 키 변경) | 자정 |
| 저장소 | Hive `chat_quota` 박스 | Hive `chat_quota` 박스 |

### 한도 초과 시 동작
1. 전송 버튼 비활성화 (회색)
2. 입력 필드 비활성화
3. 에러 바 표시: "오늘 질문 횟수를 다 사용했어요"
4. SnackBar 팝업

---

## 8. UI 구성

### 8.1 진입점 (4곳)

| 위치 | 경로 | 전달 파라미터 |
|------|------|-------------|
| 위키 탭 — 카테고리 그리드 카드 | `/chat/new?speciesId=` | 선택된 종 |
| 위키 탭 — FAB | `/chat/new?speciesId=` | 선택된 종 |
| 위키 상세 화면 — FAB | `/chat/new?speciesId=` | 해당 종 |
| 개체 상세 화면 — FAB | `/chat/new?petId=&speciesId=` | 개체+종 |
| 위키 AppBar 히스토리 아이콘 | `/chat` | 없음 (목록) |

### 8.2 라우팅

| 경로 | 화면 | 설명 |
|------|------|------|
| `/chat` | ChatListScreen | 대화 기록 목록 |
| `/chat/new` | ChatScreen | 새 대화 (쿼리 파라미터로 petId, speciesId) |
| `/chat/:conversationId` | ChatScreen | 기존 대화 이어가기 |

### 8.3 ChatScreen 구성

```
┌─ AppBar ──────────────────────────────┐
│  ← 뒤로   대화 제목...     🕐 기록    │
├───────────────────────────────────────┤
│  4/20 ━━━━━━━━━━━━━━━━━━━━━           │  QuotaIndicator
├───────────────────────────────────────┤
│                                       │
│  [빈 상태: 환영 화면 + 예시 칩 4개]     │
│  또는                                  │
│  [메시지 리스트]                        │
│    ┌─────────────────────┐            │
│    │ 유저 메시지 (primary) │  ← 우측   │
│    └─────────────────────┘            │
│  ┌────────────────────────┐           │
│  │ AI 응답 (surface)       │ ← 좌측   │
│  │ URL은 파란색 링크로 표시  │           │
│  └────────────────────────┘           │
│  ┌────────────────────────┐           │
│  │ ⚡ 즉시 답변             │ ← 캐시  │
│  │ (tertiary 배경)         │           │
│  └────────────────────────┘           │
│                                       │
├───────────────────────────────────────┤
│  ┌─────────────────────┐  ┌──┐       │
│  │ 질문을 입력하세요...   │  │ ↑│       │  InputBar
│  └─────────────────────┘  └──┘       │
└───────────────────────────────────────┘
```

### 8.4 버블 스타일

| 종류 | 정렬 | 배경 | 최대 너비 | 특이사항 |
|------|------|------|---------|---------|
| 유저 | 우측 | primary | 75% | 흰색 텍스트 |
| AI | 좌측 | surfaceContainerHighest (60%) | 82% | URL 자동 링크 |
| 캐시 | 좌측 | tertiaryContainer (50%) | 82% | ⚡ 즉시 답변 배지 |
| 로딩 | 좌측 | surfaceContainerHighest | - | 스피너 + "답변 생성 중..." |

### 8.5 URL 링크 처리

- 정규식으로 `https?://` URL 자동 감지
- 파란색 + 밑줄 스타일
- 탭 → `url_launcher`로 외부 브라우저 열기
- iOS: `Info.plist`에 `LSApplicationQueriesSchemes` (https, http) 등록 필요

---

## 9. 출처 시스템

### 9.1 출처 데이터 관리

출처는 `assets/data/citations.json`에서 중앙 관리 (28개). 각 care_info JSON의 `citation_ids` 필드로 참조.

| 종 | citation_ids 수 | 주요 출처 |
|----|----------------|----------|
| 레오파드 게코 | 6 | ReptiFiles, Bio Dude, Zen Habitats, Reptizen 등 |
| 크레스티드 게코 | 3 | ReptiFiles, Pangea Reptile, Reptropolis |
| 펫테일 게코 | 4 | ReptiFiles, Gecko Time, Josh's Frogs, Reptile Magazine |

`CitationRepository`가 JSON을 로드하여 ID 기반 조회 (`hydrate()`) 제공.

### 9.2 출처 표시 아키텍처

출처는 `ChatMessage`의 **구조적 필드**로 관리 (content 문자열에 삽입하지 않음):

| HiveField | 필드 | 타입 | 용도 |
|-----------|------|------|------|
| 8 | `citationIds` | `List<String>` | Citation ID 리스트 |
| 9 | `sourceType` | `String?` | `"care_data"` / `"web_search"` / `"general_knowledge"` |
| 10 | `webSources` | `List<String>` | 웹 검색 출처 (`"title|url"` 형식) |

**sourceType 결정 로직** (`chat_providers.dart`):
1. `citationIds`가 있으면 → `care_data`
2. `webSources`가 있으면 → `web_search`
3. 둘 다 없으면 → `general_knowledge`

### 9.3 출처 표시 UI

| sourceType | 표시 | 위젯 |
|-----------|------|------|
| `care_data` | 인라인 칩 (`[ReptiFiles🔗] [Pangea🔗]`) | `_CitationChips` (ConsumerWidget) |
| `web_search` | 웹 출처 칩 (🌐 아이콘) | `_WebSourceChips` |
| `general_knowledge` | 면책 배지 ("AI 학습 데이터 기반 · 전문가 확인 권장") | `_GeneralKnowledgeBadge` |
| 레거시 (null) | content에서 `\n\n출처:\n` 패턴 파싱 | `_parseContentBody()` |

칩 탭 → `url_launcher`로 외부 브라우저 열기.

### 9.4 웹 검색 통합

모든 질문에 DuckDuckGo Lite 웹 검색을 **비동기 병행** 실행하여 LLM 컨텍스트에 보조 정보 주입.

| 항목 | 내용 |
|------|------|
| 엔진 | DuckDuckGo Lite (HTML 파싱) |
| API 키 | 불필요 |
| 결과 수 | 최대 3건 |
| 타임아웃 | 5초 |
| 실패 시 | graceful degradation (빈 결과, 앱 정상 작동) |
| 쿼리 구성 | `"{종 이름} 사육 {질문(80자 제한)}"` |
| 트리거 | 항상 (care_info 유무 무관) |

웹 검색 결과는 시스템 프롬프트의 `[웹 검색 참고]` 섹션으로 주입되며, 출처 URL은 `ChatMessage.webSources`에 저장.

### 9.5 레거시 호환

기존 메시지 (citationIds/sourceType 필드 없음)는 content 문자열을 파싱하여 처리:
- `\n\n출처:\n` 패턴 → 본문만 추출
- `\n\n일반 지식 기반 답변입니다.` 패턴 → 면책 배지 표시

### 9.6 현재 한계

- DuckDuckGo HTML 파싱은 구조 변경 시 무음 실패 가능 (graceful degradation으로 앱 영향 없음)
- AI의 "일반 지식" 답변은 hallucination 위험 존재
- care_data와 web_search 출처가 동시에 존재할 수 있으나 sourceType은 단일 값 (primary source 기준)

---

## 10. 알려진 한계 및 개선 과제

### 10.1 LLM 관련

| 한계 | 영향 | 개선 방안 |
|------|------|---------|
| llama-3.3-70b의 출처 표기 불일관 | 출처 누락/과다 나열 | 앱 레이어에서 구조적 출처 관리로 해결됨 |
| 3종 외 종에 대한 hallucination | 잘못된 정보 제공 가능 | 프롬프트 가드레일 (구현됨) |
| 한국어 뉘앙스 부족 | 간혹 어색한 표현 | 한국어 특화 모델 검토 |
| 외부 URL 기억 못함 | 참고 자료 링크 부재 | DuckDuckGo 웹 검색 + citation_ids로 해결됨 |

### 10.2 키워드 매칭 관련

| 한계 | 영향 | 개선 방안 |
|------|------|---------|
| 키워드 목록이 수동 관리 | 새 토픽 추가 시 누락 가능 | 키워드 자동 확장 또는 임베딩 검색 (P2) |
| 형태소 분석 없음 | "먹이주기" → "먹이" 매칭 실패 | 형태소 분석기 도입 (P2) |
| 후속 질문 맥락 이해 한계 | 이전 4개 메시지만 스캔 | 대화 전체 요약 → 맥락 유지 |

### 10.3 지식 축적 관련

| 한계 | 영향 | 개선 방안 |
|------|------|---------|
| 기기별 독립 지식 풀 | 다른 기기에서 축적 안 됨 | P2 서버 통합 |
| confidence 자동 증가 없음 | useCount만 증가, confidence 고정 | useCount 기반 confidence 자동 조정 |
| 잘못된 지식 삭제 UI 없음 | 오답이 캐시되면 반복 표시 | 사용자 피드백("잘못된 답변") 버튼 |
| 캐시 히트 임계값 고정 (2.0) | 최적값 불명 | A/B 테스트 또는 사용자 피드백 기반 조정 |

### 10.4 UX 관련

| 한계 | 영향 | 개선 방안 |
|------|------|---------|
| 스트리밍 미지원 | 응답 전체 대기 후 한번에 표시 | SSE 스트리밍 구현 |
| 대화 검색 없음 | 과거 대화 찾기 어려움 | 대화 내 검색 기능 |
| 대화 기록 내보내기 없음 | 유용한 답변 보관 어려움 | 텍스트/PDF 내보내기 |
| 마크다운 렌더링 없음 | AI 응답의 볼드/리스트 미표시 | flutter_markdown 도입 |

---

## 11. P2 마이그레이션 경로

| 항목 | P0 (현재) | P2 (서버) |
|------|----------|----------|
| 대화 저장 | Hive 로컬 | Supabase `conversations` 테이블 |
| 메시지 저장 | Hive 로컬 | Supabase `chat_messages` 테이블 |
| 지식 저장 | Hive (기기별) | Supabase `knowledge_entries` (공유) |
| AI API 호출 | 클라이언트 직접 Groq | 백엔드 프록시 (키 보호) |
| 한도 관리 | Hive (기기별) | 서버 유저별 관리 |
| 지식 검색 | 키워드 매칭 | 벡터 임베딩 유사도 |
| 지식 검증 | 없음 | 관리자 리뷰 |
| 출처 관리 | citations.json + citation_ids | Supabase `citations` 테이블 |
| 웹 검색 | DuckDuckGo Lite (클라이언트) | Edge Function 프록시 |

**마이그레이션 방법:** Repository 구현체만 교체. Provider/UI 레이어 변경 없음.

---

## 12. 모듈 분리 가이드

이 채팅 시스템을 다른 프로젝트에서 재사용하려면:

### 12.1 교체 필요 요소 (도메인 의존)

| 요소 | 현재 (Tera AI) | 교체 대상 |
|------|--------------|----------|
| 시스템 프롬프트 | 게코 사육 전문 | 도메인별 커스텀 |
| 카테고리 키워드 | temperature, diet 등 6개 | 도메인별 키워드 맵 |
| 종 키워드 | 레오파드/크레스티드/펫테일 | 도메인별 엔티티 감지 |
| care_info 스니펫 빌더 | CareInfoDetail 모델 의존 | 도메인 데이터 모델 |
| 출처 URL 매핑 | 파충류 사육 사이트 11개 | 도메인별 출처 |
| 포괄적 요청 키워드 | 자료, 정보, 가이드... | 도메인별 |

### 12.2 재사용 가능 요소 (도메인 무관)

| 요소 | 설명 |
|------|------|
| Hive 모델 4개 | Conversation, ChatMessage, KnowledgeEntry, ChatQuota |
| ChatRepository | 대화/메시지/한도 CRUD |
| KnowledgeRepository | 스코어링 알고리즘, 캐시 히트 판정 |
| KnowledgeExtractor | 추출 조건, 키워드 추출 |
| GroqApiRepository | OpenAI 호환 API 호출 (프로바이더 교체 가능) |
| ChatScreen / ChatListScreen | 채팅 UI (토스 스타일) |
| ChatBubble (URL 링크 포함) | 메시지 버블 |
| QuotaIndicator | 한도 표시 |
| chat_providers.dart | 메시지 전송 플로우, 캐시 판정, 지식 추출 파이프라인 |

### 12.3 분리 시 구조 제안

```
packages/
  ai_chat_core/              # 도메인 무관 코어
    ├── domain/              # 모델 4개
    ├── data/
    │   ├── chat_repository.dart
    │   ├── knowledge_repository.dart
    │   ├── groq_api_repository.dart → ai_api_repository.dart
    │   └── knowledge_extractor.dart
    └── presentation/        # UI

  ai_chat_config/            # 도메인별 설정 (인터페이스)
    └── chat_config.dart
        ├── systemPrompt: String
        ├── categoryKeywords: Map<String, List<String>>
        ├── entityKeywords: Map<String, List<String>>
        ├── comprehensiveKeywords: List<String>
        ├── sourceUrls: Map<String, String>
        └── buildContextSnippet(entityId, categories): Future<String>
```

---

## 13. 메시지 전송 플로우 (전체)

```
사용자가 질문 입력 후 전송 버튼 탭
    │
    ▼
ChatMessagesNotifier.sendMessage(question)
    │
    ├── 한도 확인 (canSendMessage)
    │   └── 초과 → error: 'quota_exceeded', 종료
    │
    ├── 유저 메시지 Hive 저장 + UI 갱신 (isLoading: true)
    │
    ├── 종 감지 (detectSpecies)
    │
    ├── 캐시 히트 확인 (isCacheHit)
    │   └── 히트 → 캐시 답변 표시, useCount++, 한도 미차감, 종료
    │
    ├── 컨텍스트 빌딩 (buildContext)
    │   ├── care_info 스니펫
    │   ├── 개체 정보
    │   ├── 캐시 지식 (top 3)
    │   └── 대화 히스토리 (최근 6개)
    │
    ├── Groq API 호출 (sendChat)
    │   └── 실패 → error 표시, 종료
    │
    ├── AI 응답 Hive 저장 + 한도 차감 + UI 갱신
    │
    ├── 지식 추출 (KnowledgeExtractor.extract)
    │   └── 추출 가능 → KnowledgeEntry Hive 저장
    │
    └── 대화 목록 갱신 (conversationListProvider.refresh)
```
