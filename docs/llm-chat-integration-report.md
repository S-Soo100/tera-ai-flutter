# LLM 앱 내 통합 보고서 — Tera AI 사례

> 작성일: 2026-04-10
> 프로젝트: Tera AI (파충류 사육 가이드 앱)
> 작성 목적: 다른 에이전트/프로젝트가 LLM 채팅 기능을 분석·재현·개선할 수 있도록

---

## 1. 프로젝트 배경

### 1.1 앱 개요
- **이름**: Tera AI
- **도메인**: 파충류(게코) 사육 가이드
- **타겟 사용자**: 레오파드/크레스티드/펫테일 게코 사육자 및 브리더
- **스택**: Flutter + Riverpod + GoRouter + Hive
- **Phase**: P0 (로컬 전용, 인증 없음, 백엔드 없음)

### 1.2 LLM 도입 동기
사용자가 앱 내 정적 위키(JSON 기반 사육 정보)만으로는 답을 얻지 못하는 **구체적·상황적 질문**에 대응하기 위해 도입.

**정적 위키로 답할 수 없는 질문 예시:**
- "크레스티드 게코 50마리 관리하는데 인력이 얼마나 필요해?"
- "펫테일 게코 산란 세팅을 위한 준비물은?"
- "습도가 20% 이하로 떨어지면 어떤 문제가 생겨?"

### 1.3 핵심 설계 원칙

| 원칙 | 설명 | 구현 근거 |
|------|------|---------|
| **검증 우선** | LLM의 일반 지식보다 앱 내 검증 데이터 우선 | 시스템 프롬프트 + care_info 컨텍스트 주입 |
| **투명한 신뢰도** | 사용자가 답변의 근거를 판단할 수 있어야 함 | 앱 코드 레벨 출처 강제 표시 |
| **지식 축적** | 반복 질문에 대한 점진적 품질 향상 | KnowledgeEntry 캐시 + confidence 시스템 |
| **안전 장치** | 잘못된 답변이 영속되지 않아야 함 | 사용자 피드백 → confidence 하락 → 자동 삭제 |

---

## 2. 아키텍처 개요

### 2.1 시스템 구성도

```
┌─────────────────────────────────────────────────────────┐
│                    사용자 (Flutter UI)                     │
│  ChatScreen → ChatBubble → QuotaIndicator                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Presentation Layer (Riverpod)                │
│  ChatMessagesNotifier                                    │
│  ├── 한도 체크 (ChatQuota)                                │
│  ├── 캐시 히트 판정 (KnowledgeRepository)                  │
│  ├── 컨텍스트 빌딩 (ContextBuilder)                        │
│  ├── API 호출 (GroqApiRepository)                         │
│  ├── 지식 추출 (KnowledgeExtractor)                        │
│  └── 출처 첨부 (앱 코드 강제, LLM 위임 아님)                │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
┌──────────────┐ ┌────────┐ ┌──────────────┐
│ CareInfo JSON │ │ Hive   │ │ Groq API     │
│ (번들 데이터)  │ │ (로컬) │ │ (외부 LLM)   │
│ 3종 사육 정보  │ │ 대화   │ │ llama-3.3    │
│ + 출처 URL    │ │ 지식   │ │ -70b         │
│              │ │ 한도   │ │              │
└──────────────┘ └────────┘ └──────────────┘
```

### 2.2 파일 구조

```
lib/features/chat/
├── domain/                          # Hive 모델 4개
│   ├── conversation.dart            # typeId:2 — 대화 세션
│   ├── chat_message.dart            # typeId:3 — 메시지 (knowledgeEntryId 포함)
│   ├── knowledge_entry.dart         # typeId:4 — 축적된 지식
│   └── chat_quota.dart              # typeId:5 — 일일 한도
├── data/                            # 비즈니스 로직 5개
│   ├── chat_repository.dart         # 대화/메시지/한도 CRUD
│   ├── knowledge_repository.dart    # 지식 캐시 검색·축적·피드백
│   ├── groq_api_repository.dart     # OpenAI 호환 API 호출
│   ├── context_builder.dart         # 프롬프트 조립기 (핵심 모듈)
│   └── knowledge_extractor.dart     # 규칙 기반 지식 추출
└── presentation/                    # UI 5개
    ├── chat_providers.dart          # Riverpod 상태 관리
    ├── chat_screen.dart             # 채팅 화면 (토스 스타일)
    ├── chat_list_screen.dart        # 대화 기록 목록
    └── widgets/
        ├── chat_bubble.dart         # 메시지 버블 + URL 링크 + 피드백 버튼
        └── quota_indicator.dart     # 한도 표시 바
```

---

## 3. LLM 프로바이더 선정

### 3.1 비교 검토

| 프로바이더 | 무료 티어 | 호환성 | 한국어 | 선정 여부 |
|-----------|---------|--------|--------|---------|
| **Groq** | 1,000 RPD, 30 RPM | OpenAI 호환 | 양호 | **채택** |
| DeepSeek | 크레딧 후 저렴 | OpenAI 호환 | 양호 | 후보 |
| Gemini | 15 RPM 무료 | 자체 SDK | 중간 | 패스 |
| OpenAI | 유료 | 네이티브 | 우수 | 비용 문제 |

### 3.2 채택 근거
- **무료 티어**: 가입만으로 1,000 RPD, 신용카드 불필요 → P0 MVP에 적합
- **OpenAI 호환**: `baseUrl` + `model` + API key만 변경하면 다른 프로바이더로 교체 가능
- **모델**: `llama-3.3-70b-versatile` (128K 컨텍스트, 무료 티어 500K TPD)

### 3.3 API 설정

```dart
baseUrl: 'https://api.groq.com/openai/v1/chat/completions'
model: 'llama-3.3-70b-versatile'
maxTokens: 1024
temperature: 0.3      // 사실 기반 답변을 위해 낮게 설정
timeout: 30초
```

### 3.4 API 키 관리

```
.env 파일 → flutter_dotenv로 로드 → dotenv.env['GROQ_API_KEY']
.env는 .gitignore에 등록 (커밋 안 됨)
.env는 pubspec.yaml assets에 등록 (번들됨)
```

**알려진 보안 한계**: `.env`가 APK/IPA에 번들되므로 디컴파일 시 키 노출 가능. P2에서 백엔드 프록시로 전환 필요.

---

## 4. 컨텍스트 빌딩 파이프라인 (핵심)

### 4.1 전체 흐름

이 파이프라인이 LLM 통합의 **핵심 가치**를 결정한다. 같은 LLM이라도 컨텍스트 품질에 따라 답변 품질이 극적으로 달라진다.

```
사용자 질문 "크레스티드 게코 습도가 자꾸 올라가는데 어떻게 해?"
    │
    ▼
┌─ Step 1: 종 감지 ──────────────────────────────────┐
│  질문 키워드 "크레스티드" → crested-gecko            │
│  우선순위: 질문 > 대화 기본값 > 개체 > 이전 대화 4개  │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 2: 카테고리 감지 ────────────────────────────┐
│  "습도" → humidity 카테고리                         │
│  매칭 없으면 → 이전 대화 4개에서 카테고리 추출        │
│  "자료","정보" 등 포괄 키워드 → 전체 6카테고리        │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 3: care_info 스니펫 조립 ────────────────────┐
│  CareInfoRepository.getCareInfo("crested-gecko")   │
│  → humidity 카테고리만 추출:                         │
│    "습도: 60~80%, 미스팅: 건습 사이클..."             │
│  → 카테고리 관련 출처만 필터링                        │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 4: 개체 정보 (선택) ─────────────────────────┐
│  petId가 있으면 PetRepository에서 로드               │
│  "이름: 꼬미, 종: 크레스티드, 나이: 11개월"           │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 5: 캐시 지식 검색 ──────────────────────────┐
│  KnowledgeRepository.findRelevant() → 상위 3개     │
│  이전에 축적된 관련 Q&A를 컨텍스트에 추가              │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 6: 대화 히스토리 ───────────────────────────┐
│  최근 6개 메시지 (user/assistant 교대)              │
└────────────────────────────────────────────────────┘
    │
    ▼
┌─ Step 7: messages 배열 조립 ──────────────────────┐
│  [system: 프롬프트 + [앱 데이터]]                    │
│  [user: 이전 질문]                                  │
│  [assistant: 이전 답변]                             │
│  [user: 현재 질문]                                  │
│                                                    │
│  + 반환: BuildContextResult                        │
│    { messages, hasCareData, speciesId, sources }   │
└────────────────────────────────────────────────────┘
```

### 4.2 키워드 매칭 시스템

**종 감지 (3종):**

| speciesId | 키워드 |
|-----------|-------|
| leopard-gecko | 레오파드, 레파게, 레게 |
| crested-gecko | 크레스티드, 크레게, 크레 |
| fat-tailed-gecko | 펫테일, 팻테일, 아프리칸 |

**카테고리 감지 (6종):**

| 카테고리 | 키워드 (총 72개) |
|---------|----------------|
| temperature | 온도, 핫존, 쿨존, 바스킹, 히팅, 히터, 서모스탯, 야간, 보온, 난방, 체온 |
| humidity | 습도, 탈피, 하이드, 미스팅, 건조, 장마, 수분, 물그릇, 물, 과습, 환기, 분무 |
| enclosure | 사육장, 케이지, 기질, 바닥재, 테라리움, 용품, UVB, 조명, 바닥, 인테리어, 레이아웃 |
| diet | 먹이, 급여, 밀웜, 귀뚜라미, 듀비아, 칼슘, 비타민, 보충제, 식단, 사료, 급수, 식사, 밥 |
| health | 병, 질병, 탈피, 꼬리, 구토, 설사, 기생충, 수의사, 화상, 아파, 아픈, 증상, 치료, 건강, 죽 |
| breeding | 번식, 교배, 모프, 유전, 인큐, 알, 해칭, 브리딩, 산란, 짝짓기, 임신, 포란, 부화, 인큐베이터 |

**포괄적 요청 키워드** (전체 카테고리 활성화):
자료, 정보, 가이드, 전체, 전부, 총정리, 사육법, 키우는 법, 기르는 법

### 4.3 후속 질문 맥락 유지

**문제**: "습도 하이드 몇 %야?" 다음에 "그러면 겨울에는?" → 종/카테고리 키워드 없음.

**해결**: 현재 질문에 키워드 없으면 이전 대화 4개를 스캔하여 종/카테고리 계승.

```dart
// 종 감지 실패 시
if (resolvedSpeciesId == null) {
  final history = chatRepo.getRecentMessages(conversationId, limit: 4);
  for (final msg in history) {
    resolvedSpeciesId = detectSpecies(msg.content, null);
    if (resolvedSpeciesId != null) break;
  }
}
// 카테고리도 동일 로직
```

**한계**: 5번째 이전 메시지의 맥락은 소실됨. 대화 요약 기능 없음 (P2 과제).

### 4.4 시스템 프롬프트

```
게코 사육 전문 AI. 레오파드·크레스티드·펫테일 게코 3종 전문.

규칙:
- [앱 데이터]가 있으면 참고하되 "앱 데이터에 따르면" 같은 메타 언급 없이 바로 답변.
- [앱 데이터]가 없거나 부족해도 3종에 대해선 일반 지식으로 성실히 답변. 거부 금지.
- 3종 외 종 → "현재 지원하지 않는 종입니다." 한 줄로 끝.
- 확실하지 않으면 모른다고 솔직히.
- 병원 가야 할 상황이면 짧게 경고.
- 한국어, 간결체. 서론/반복/출처표기 금지 — 출처는 앱이 자동으로 붙입니다.
```

**프롬프트 설계 교훈:**
1. LLM에게 **하지 말 것**을 명시하는 것이 **할 것**보다 효과적
2. "출처는 앱이 자동으로 붙입니다" → LLM이 자체 출처를 달지 않게 함
3. "메타 언급 없이" → "앱 데이터에 따르면..." 같은 장황한 서문 방지
4. 간결체 지시 → 답변 길이 자연스럽게 제한

### 4.5 토큰 예산

| 세그먼트 | ~토큰 | 비고 |
|---------|-------|------|
| 시스템 프롬프트 | 200 | 간소화 후 |
| care_info 컨텍스트 | 400~800 | 카테고리 수에 따라 |
| 개체 정보 | 100~200 | 선택 |
| 캐시 지식 | 300~400 | 최대 3개 |
| 대화 히스토리 | 800~1200 | 최근 6개 |
| 사용자 질문 | 50~100 | |
| **응답 예산** | **1024** | maxTokens |
| **합계** | **~3000~4000** | Groq 128K 대비 매우 여유 |

---

## 5. 출처 시스템

### 5.1 설계 철학

**핵심 원칙: LLM에게 출처를 위임하지 않는다.**

LLM은 출처 표기를 일관되게 따르지 않고, 가짜 URL을 생성할 수 있다. 따라서 출처는 **앱 코드가 100% 강제 첨부**한다.

### 5.2 작동 방식

```
ContextBuilder.buildContext()
  → BuildContextResult 반환
    ├── hasCareData: bool     (care_info가 주입됐는가)
    └── sources: List<String> (카테고리 관련 출처만 필터링)

ChatMessagesNotifier.sendMessage()
  → AI 응답 수신 후 앱 코드가 분기:
    ├── hasCareData == true  → 응답 끝에 "📎 출처:\n- 이름 URL" 첨부
    └── hasCareData == false → 응답 끝에 "⚠️ 일반 지식 기반" 첨부
```

### 5.3 카테고리별 출처 필터링

모든 출처를 항상 나열하지 않고, **질문의 카테고리와 관련된 출처만** 표시.

```dart
static const Map<String, Set<String>> _sourceCategories = {
  'ReptiFiles — Leopard Gecko Care': {'temperature', 'humidity', 'enclosure', 'diet', 'health'},
  'Pangea Reptile — Care Guide': {'diet', 'humidity', 'enclosure'},
  'Zen Habitats — Substrate Guide': {'enclosure'},  // 기질 질문에서만 표시
  // ...
};
```

**결과:**
- 습도 질문 → ReptiFiles + Pangea (2개)
- 기질 질문 → Zen Habitats + Bio Dude (2개)
- 브리딩 질문 → 관련 출처 없음 → 출처 미표시

### 5.4 출처 URL 관리

**원칙: 홈페이지 루트 URL은 출처가 아니다.**

`reptizen.com/`, `reptropolis.com/`, `reptilesmagazine.com/` 같은 홈페이지 URL은 제거.
실제 콘텐츠 페이지를 가리키는 URL만 유지 (8개).

**한계**: URL은 하드코딩. 외부 페이지가 이동/삭제되면 깨진 링크. P2에서 DB 관리 + 주기적 검증 필요.

---

## 6. 지식 축적 시스템

### 6.1 개요

단순 채팅이 아니라 **대화에서 재사용 가능한 지식을 자동 추출·축적**하여, 반복 질문에 대한 답변 품질과 속도를 점진적으로 개선.

### 6.2 지식 추출 (KnowledgeExtractor)

**추출 조건** (모두 충족):
1. AI 응답 길이 >= 100자
2. 질문이 인사가 아님 (안녕, 하이, hi 등)
3. 질문에 사육 카테고리 키워드 1개 이상 포함

**추출 결과:**
- question: 원본 질문 (trim)
- answer: AI 응답 (최대 500자)
- category: 키워드 매칭 카테고리
- keywords: 질문+응답에서 추출한 키워드 리스트
- confidence: **0.5** (초기값)
- useCount: **0** (초기값)

### 6.3 관련도 스코어링

```
score = keyword_overlap * confidence * (1 + log(useCount + 1))
```

| 변수 | 설명 | 범위 |
|------|------|------|
| keyword_overlap | 질문 키워드 ∩ 엔트리 키워드 | 0~N |
| confidence | 신뢰도 | 0.0~0.9 |
| useCount | 사용 횟수 | 0~∞ |

- `overlap == 0` → 즉시 스킵
- `score <= 0.5` → 필터 아웃
- 상위 3개 반환

### 6.4 캐시 히트 판정

```
score > 2.0 → 캐시 히트
```

- API 호출 없이 기존 답변 즉시 반환
- 일일 한도 미차감
- UI에 "즉시 답변" 배지 표시

### 6.5 Confidence 갱신 메커니즘

| 이벤트 | 변화 | 비고 |
|--------|------|------|
| useCount 증가 (캐시 사용) | confidence += 0.05 | 최대 0.9 (사람 검증 없이 1.0 불가) |
| 사용자 "부정확" 피드백 | confidence -= 0.3 | 최소 0.0 |
| confidence <= 0.1 | 엔트리 자동 삭제 | 오답 순환 차단 |

### 6.6 지식 축적 라이프사이클

```
Day 1: "탈피가 안 벗겨져요"
  → AI 응답 → KnowledgeEntry(confidence:0.5, useCount:0)

Day 3: "발가락에 탈피 껍질"
  → 키워드 "탈피" 매칭 → Day1 엔트리를 컨텍스트 주입
  → AI가 더 정확한 응답 (이전 지식 참고)
  → useCount:1, confidence:0.55

Day 10: 비슷한 탈피 질문
  → score > 2.0 → 캐시 히트! API 미호출, 즉시 응답
  → useCount:5, confidence:0.75

사용자가 "부정확" 탭:
  → confidence: 0.75 - 0.3 = 0.45
  → 캐시 히트 불가로 전환 → 다음 질문은 새 API 호출
```

### 6.7 오답 순환 차단

**4명의 비평가(데카르트/소크라테스/쇼펜하우어/니체)가 공통 지적한 최대 위험:**
틀린 답변이 캐시 → useCount 증가 → 영구 오답 순환.

**차단 메커니즘:**
1. confidence 최대 0.9 (자동으로 1.0 도달 불가)
2. 사용자 "부정확" 버튼 → confidence -0.3
3. confidence <= 0.1 → 자동 삭제
4. 신고 3회면 거의 확실히 삭제 (0.5 → 0.2 → 삭제)

---

## 7. 메시지 전송 전체 플로우

```
사용자가 질문 입력 후 전송 버튼 탭
    │
    ├── 한도 확인 (canSendMessage)
    │   └── 초과 → error: 'quota_exceeded', 종료
    │
    ├── 유저 메시지 Hive 저장 + UI 갱신 (isLoading: true)
    │
    ├── 종 감지 (detectSpecies)
    │
    ├── 캐시 히트 확인 (isCacheHit, score > 2.0)
    │   └── 히트 → 캐시 답변 표시, useCount++, confidence+=0.05
    │           한도 미차감, "즉시 답변" 배지, 종료
    │
    ├── 컨텍스트 빌딩 (buildContext)
    │   → BuildContextResult { messages, hasCareData, sources }
    │
    ├── Groq API 호출 (sendChat)
    │   └── 실패 → error 표시, 종료
    │
    ├── 앱 코드가 출처/경고 강제 첨부
    │   ├── hasCareData → "📎 출처: ..."
    │   └── !hasCareData → "⚠️ 일반 지식 기반"
    │
    ├── AI 응답 Hive 저장 + 한도 차감 + UI 갱신
    │
    ├── 지식 추출 (KnowledgeExtractor.extract)
    │   └── 추출 가능 → KnowledgeEntry 저장
    │
    └── 대화 목록 갱신
```

---

## 8. 한도 관리

| 항목 | Debug | Release |
|------|-------|---------|
| 일일 한도 | 999회 (무제한) | 20회 |
| 판정 | `kDebugMode` 컴파일 상수 | |
| 캐시 히트 | 미차감 | 미차감 |
| 리셋 시점 | 자정 (날짜 키 변경) | 자정 |
| 저장소 | Hive `chat_quota` 박스 | |

---

## 9. UI 구성

### 9.1 디자인 스타일: 토스(Toss) 참조

- **입력바**: pill 형태 + 원형 전송 버튼 (primary 색상)
- **유저 버블**: primary 배경, 우측 정렬, 최대 너비 75%
- **AI 버블**: surface 배경, 좌측 정렬, 최대 너비 82%, URL 자동 링크
- **캐시 버블**: tertiary 배경, "즉시 답변" 배지
- **로딩**: 스피너 + "답변 생성 중..." 텍스트
- **SafeArea**: 하단 홈바/노치 침범 없음

### 9.2 신뢰도 표시 (코드 강제)

| 상태 | 표시 | 구현 위치 |
|------|------|---------|
| care_info 주입됨 | 📎 출처: (관련 출처 나열) | chat_providers.dart |
| care_info 미주입 | ⚠️ 일반 지식 기반 | chat_providers.dart |
| 캐시 답변 | 즉시 답변 배지 | chat_bubble.dart |

**핵심: LLM 프롬프트가 아닌 앱 코드가 100% 결정.**

### 9.3 피드백 버튼

AI 버블 하단에 "부정확" 버튼. 탭 시:
1. `KnowledgeRepository.reportBadAnswer()` 호출
2. confidence -0.3
3. SnackBar: "피드백 감사합니다. 답변 품질 개선에 반영됩니다."

### 9.4 진입점 (4곳)

| 위치 | 경로 | 전달 파라미터 |
|------|------|-------------|
| 위키 탭 — 카테고리 그리드 카드 | `/chat/new?speciesId=` | 선택된 종 |
| 위키 탭 — FAB | `/chat/new?speciesId=` | 선택된 종 |
| 위키 상세 화면 — FAB | `/chat/new?speciesId=` | 해당 종 |
| 개체 상세 화면 — FAB | `/chat/new?petId=&speciesId=` | 개체+종 |

---

## 10. 개발 과정에서 발견된 교훈

### 10.1 LLM에게 위임하면 안 되는 것

| 위임한 것 | 문제 | 해결 |
|----------|------|------|
| 출처 표기 | 일관성 없음, 가짜 URL 생성 | 앱 코드 강제 첨부 |
| 신뢰도 표시 (⚠️) | LLM이 생략하거나 잊음 | hasCareData 분기로 코드 강제 |
| 답변 거부 판단 | 지원 종인데도 거부 | 프롬프트에 "거부 금지" 명시 |
| 출처 관련도 판단 | 무관한 출처 나열 | 카테고리별 출처 필터링 |

**원칙: LLM은 답변 생성에만 집중. 메타데이터(출처, 신뢰도, 포맷)는 앱이 처리.**

### 10.2 프롬프트 엔지니어링 반복 기록

| 버전 | 변경 | 효과 |
|------|------|------|
| v1 | "앱 데이터 기반과 일반 지식을 구분합니다" | AI가 매번 "앱 데이터에 따르면..." 장황하게 서술 |
| v2 | "메타 설명 금지 — 바로 내용을 말해" | 간결해짐 |
| v3 | "출처 규칙 5개항" | AI가 규칙을 일관되게 안 따름 |
| v4 | "출처표기 금지 — 출처는 앱이 자동으로 붙입니다" | 출처를 앱 코드로 이관, LLM 부담 제거 |
| v5 | "3종에 대해선 일반 지식으로 성실히 답변. 거부 금지" | 지원 종에 대한 불필요한 거부 해소 |

### 10.3 키워드 매칭의 한계와 대응

| 한계 | 사례 | 대응 |
|------|------|------|
| 동의어 누락 | "수분공급" → humidity 미매칭 | "수분" 키워드 추가 |
| 형태소 미분석 | "먹이주기" → "먹이" 미매칭 | 부분 포함 검사 (contains) |
| 후속 질문 맥락 소실 | "그러면 겨울에는?" | 이전 4개 메시지 스캔 |
| 포괄적 요청 미인식 | "전체 사육 가이드" | _comprehensiveKeywords 추가 |

### 10.4 버그 발견·수정 기록

| 버그 | 원인 | 수정 |
|------|------|------|
| 종 감지 우선순위 역전 | hintSpeciesId가 질문 키워드보다 우선 | 질문 키워드 먼저 체크 |
| 한도 표시 미갱신 | remainingMessagesProvider 미갱신 | ref.invalidate() 추가 |
| Hero 태그 충돌 | FAB 5개가 같은 Hero 태그 | 각 FAB에 고유 heroTag |
| iOS URL 열기 실패 | Info.plist에 쿼리 스킴 미등록 | LSApplicationQueriesSchemes 추가 |
| url_launcher 네이티브 에러 | iOS pod 캐시 문제 | flutter clean + pod install |

---

## 11. 알려진 한계

### 11.1 LLM 한계

| 한계 | 영향 | 완화 | P2 해결 |
|------|------|------|---------|
| Hallucination | 잘못된 사육 정보 → 동물 피해 | 프롬프트 가드레일 + ⚠️ 경고 | 사실 검증 파이프라인 |
| 한국어 뉘앙스 | 간혹 어색한 표현 | temperature 0.3 | 한국어 특화 모델 |
| 출처 URL 모름 | LLM이 정확한 URL 생성 불가 | 앱 코드 강제 첨부 | DB 관리 |

### 11.2 구조적 한계

| 한계 | 영향 | P2 해결 |
|------|------|---------|
| 키워드 매칭 (형태소 분석 없음) | 새 토픽 키워드 누락 | 임베딩 검색 |
| 이전 대화 4개 스캔 한계 | 긴 대화에서 맥락 소실 | 대화 요약 |
| API 키 앱 번들 | 디컴파일 시 노출 | 백엔드 프록시 |
| 기기별 지식 풀 | 기기 간 공유 안 됨 | 서버 통합 |
| 프롬프트 인젝션 무방비 | 악의적 입력 처리 못함 | 입력 sanitization |

---

## 12. 모듈 분리 가이드

### 12.1 재사용 가능 요소 (도메인 무관)

| 모듈 | 파일 | 설명 |
|------|------|------|
| Hive 모델 4개 | domain/*.dart | 대화/메시지/지식/한도 |
| ChatRepository | data/chat_repository.dart | CRUD + 한도 관리 |
| KnowledgeRepository | data/knowledge_repository.dart | 스코어링 + 캐시 히트 + 피드백 |
| KnowledgeExtractor | data/knowledge_extractor.dart | 규칙 기반 추출 |
| GroqApiRepository | data/groq_api_repository.dart | OpenAI 호환 API |
| ChatScreen | presentation/chat_screen.dart | 토스 스타일 UI |
| ChatBubble | presentation/widgets/chat_bubble.dart | URL 링크 + 피드백 |

### 12.2 교체 필요 요소 (도메인 의존)

| 요소 | 현재 (Tera AI) | 교체 대상 |
|------|--------------|----------|
| 시스템 프롬프트 | 게코 사육 전문 | 도메인별 전문가 설정 |
| 카테고리 키워드 | temperature/diet 등 6개 | 도메인별 토픽 |
| 종 키워드 | 레오파드/크레스티드/펫테일 | 도메인별 엔티티 |
| care_info 스니펫 빌더 | CareInfoDetail 모델 | 도메인 데이터 모델 |
| 출처 URL 매핑 | 파충류 사육 사이트 8개 | 도메인별 출처 |
| 카테고리-출처 관련도 | _sourceCategories | 도메인별 매핑 |

### 12.3 분리 시 인터페이스

```dart
abstract class ChatConfig {
  String get systemPrompt;
  Map<String, List<String>> get categoryKeywords;
  Map<String, List<String>> get entityKeywords;      // 종 → 엔티티
  List<String> get comprehensiveKeywords;
  Map<String, String> get sourceUrls;
  Map<String, Set<String>> get sourceCategories;
  Future<({String snippet, List<String> sources})> buildDataSnippet(
    String entityId, Set<String> categories);
}
```

이 인터페이스만 구현하면 ContextBuilder가 어떤 도메인에서도 동작.

---

## 13. 성과 지표

### 13.1 구현 규모
- **새 파일**: 18개 (domain 8, data 5, presentation 5)
- **수정 파일**: 8개 (router, wiki, my_pets, main, pubspec 등)
- **총 추가 코드**: ~3,400줄
- **새 패키지**: 4개 (http, flutter_dotenv, url_launcher, hive_generator)
- **Hive 모델**: 4개 (typeId 2~5)

### 13.2 품질 지표 (크리틱 기반)

| 지표 | 초기 구현 | 크리틱 후 개선 |
|------|----------|-------------|
| 출처 표시 일관성 | ~40% (LLM 재량) | **100%** (코드 강제) |
| 캐시 오답 생존 | 영구 | 신고 3회면 삭제 |
| 신뢰도 UI 표시 | LLM 의존 | 코드 강제 (hasCareData 분기) |
| 홈페이지 루트 출처 | 3개 포함 | 0개 (전부 제거) |
| 무관한 출처 표시 | 종 단위 전체 나열 | 카테고리별 필터링 |

### 13.3 4철학자 크리틱 점수

| 비평가 | 역할 | 점수 | 핵심 지적 |
|--------|------|------|----------|
| 데카르트 | 데이터 무결성 | 7.5/10 | confidence 0.5 고정, 출처 URL 루트 |
| 소크라테스 | 비즈니스 로직 | 8/10 | "검증이란 누구의 동의를 얻어 사용하는가?" |
| 쇼펜하우어 | 보안 | 9/10 | API 키 노출, 캐시 오답 순환 |
| 니체 | UX | 6.5/10 | "JSON→LLM→홈페이지 링크 포장 = 검증 아님" |
| **종합** | | **7.75/10** | 3대 결함 수정 후 구조적 개선 완료 |

---

## 14. 다른 프로젝트 적용 시 체크리스트

### Phase 1: 기반 구축
- [ ] LLM 프로바이더 선정 (Groq/DeepSeek/OpenRouter)
- [ ] API 키 관리 방식 결정 (.env / --dart-define / 백엔드 프록시)
- [ ] 도메인 데이터 준비 (JSON 번들 / API / DB)
- [ ] Hive 모델 4개 세팅 (typeId 충돌 확인)

### Phase 2: 컨텍스트 빌딩
- [ ] 도메인별 카테고리 키워드 정의
- [ ] 도메인별 엔티티 키워드 정의
- [ ] 데이터 스니펫 빌더 구현 (도메인 모델 → 텍스트)
- [ ] 시스템 프롬프트 작성 (간결하게, 출처 규칙 없이)
- [ ] 출처 URL 매핑 (홈페이지 루트 금지)
- [ ] 카테고리-출처 관련도 매핑

### Phase 3: 안전 장치
- [ ] 출처를 앱 코드에서 강제 첨부 (LLM 위임 금지)
- [ ] 신뢰도 UI 코드 레벨 강제 (hasCareData 분기)
- [ ] 사용자 피드백 버튼 (confidence 하락 → 오답 삭제)
- [ ] confidence 최대 0.9 제한 (사람 검증 없이 1.0 불가)
- [ ] 일일 한도 설정 (Debug/Release 분리)

### Phase 4: 검증
- [ ] 4철학자 크리틱 실행
- [ ] 캐시 오답 순환 시나리오 테스트
- [ ] 후속 질문 맥락 유지 테스트
- [ ] 출처 URL 실제 유효성 확인
