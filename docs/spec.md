# Flutter 앱 기획서 v2

## 1. 앱 개요
- **앱 이름**: Tera AI
- **한줄 설명**: 게코 사육자를 위한 사육 위키, 개체 관리, 모프 유전 계산기, 자진신고 가이드 + 게코캠·사육장 IoT 제어 올인원 앱
- **타겟 사용자**: 레오파드 게코 / 크레스티드 게코 / 펫테일 게코 사육자 및 브리더. 2026.6.13 자진신고 기한을 앞둔 국내 사육자
- **플랫폼**: iOS + Android (Flutter)
- **MVP 전략**: 3종(레오파드 게코, 크레스티드 게코, 펫테일 게코)을 깊게 → 이후 종 확장

## 2. 백엔드

> **현황(2026-06-09)**: 아래 "로컬 전용" 항목은 P0 초기 설계 기록이다. 현재 앱은 Supabase(인증·유저 데이터·게코캠) + terra-server(사육장 IoT)에 실연동돼 있다.

**현재 아키텍처**
- **Supabase**: Email/Password 인증 + 유저 데이터 CRUD(`pets`/`pet_events`/`media`/대화) + 레퍼런스 데이터. 게코캠 메타(`camera_clips`). 접속/스키마: `docs/supabase-setup.md`, `docs/supabase-schema.md`.
- **terra-server (사육장 IoT)**: 동일 Supabase 프로젝트 공유 + REST(`api.terra-server.uk`). 디바이스 제어(`commands`)·온습도 실시간(`telemetry`)·BLE 페어링. 단일 진실 소스: `~/Downloads/APP_INTEGRATION.md`.
- **petcam-lab (게코캠)**: 영상 클립 스트리밍 백엔드(`docs/flutter-cloud-migration-plan.md` Phase C).
- **로컬 저장소**: Hive (설정, 캐시).

**P0 초기 설계 (기록용)**
- ~~종류: 없음 (로컬 전용) / 인증: 없음 / 번들 데이터: assets/data/ JSON~~
- > TODO(P1) 로컬 알림 · TODO(P2) Supabase 도입 — **P2 완료, 위 현황 참조.**

## 3. 하단 탭 구성

> **현황(2026-06-09)**: 3탭 → **5탭**으로 개편(`StatefulShellRoute.indexedStack`, `app_router.dart`). 아래 §4 이후 흐름 서술은 일부 초기 IA(홈/위키/내개체/자진신고) 기준이라 점진 갱신 중. 사육 위키·자진신고는 보조 라우트(`/wiki`, `/search`)로 유지.

| 탭 순서 | 이름 | 경로 | 화면 | 설명 |
|---------|------|------|------|------|
| 1 | 홈 | `/home` | HomeScreen | 대시보드 — 내 개체/사육장 요약 + D-day |
| 2 | 마이 크레 | `/my-pets` | MyPetsScreen | [개체목록\|리포트] 탭 — 개체 CRUD + 어젯밤 리포트(요약+하이라이트) |
| 3 | 크레캠 | `/crecam` | CrecamScreen | 크레캠 카메라 + `motion_clips` 비디오(썸네일·즐겨찾기·AI분류칩) — terra-server |
| 4 | 사육장 | `/smart-cage` | SmartCageScreen | **terra-server IoT** — 온습도 실시간 + 팬/히터/LED/릴레이 제어 + BLE 페어링 |
| 5 | 커뮤니티 | `/community` | CommunityScreen | 게시판 (Supabase) |

> 보조 라우트: `/wiki`(사육 위키 — 3종 범주별 가이드 + 모프 계산기 + 종 비교 + 지식그래프), `/search`(백색목록 검색), 자진신고 가이드.

## 4. 핵심 사용자 흐름

```
━━━ 흐름 1: 첫 진입 (개체 미등록) ━━━

[앱 시작]
  → SplashScreen (로고 1초)
  → HomeScreen

[홈 — 빈 상태]
  → 화면:
    ⏰ 자진신고 마감 D-XX 배너 (탭 → 자진신고 탭)
    ─────────────────
    🦎 "개체를 등록하고 맞춤 사육 가이드를 받아보세요"
    [+ 첫 개체 등록하기] 버튼
    ─────────────────
    📖 사육 가이드
    [레오파드 게코] [크레스티드 게코] [펫테일 게코]  ← 카드형
    ─────────────────
    🔍 백색목록 검색  ← 탭하면 검색 오버레이
    "우리 집 도마뱀, 합법일까?"


━━━ 흐름 2: 사육 위키 탐색 ━━━

[위키 탭 진입]
  → 화면: 상단 종 선택 칩 (레오파드 | 크레스티드 | 펫테일)
  → 기본 정보 요약 카드: 난이도, 수명, 성체 크기, 성격
  → 범주 카드 그리드:
    [🌡️ 온도·습도]  [🏠 사육장]
    [🍽️ 먹이]       [⚠️ 초보 실수]
    [🧬 모프 계산기]  [📋 종 비교]

[온도·습도 상세] 레오파드 게코 선택 상태
  → 화면:
    바스킹 표면  34~36℃
    핫존        32~33℃
    쿨존        21~25℃
    야간        16~22℃
    ───
    기본 습도    30~40%
    습도 하이드  70~80%
    💡 "한국 여름 장마철 과습 → 환기 필수"
    💡 "겨울 난방 시 건조 → 습도 하이드 중요"

[사육장 상세]
  → 화면:
    최소 크기: 90×45×45cm
    ✅ 권장 기질: 배양토+플레이샌드 6:4 / 슬레이트 타일
    ❌ 피해야 할 것: 모래 단독(장폐색), 왈넛 껍데기, 칼슘 샌드
    필수 용품: 웜 하이드, 쿨 하이드, 모이스트 하이드, 물그릇, 서모스탯+히팅패드
    조명: UVB 권장 (Arcadia ShadeDweller 7%)

[먹이 상세]
  → 화면:
    주식: 듀비아(추천) / 귀뚜라미 / 밀웜(보조) / BSFL / 실크웜
    간식: 왁스웜(월 1~2회) / 슈퍼웜
    보충제: 칼슘 매 식사 더스팅 / 비타민 주 1~2회
    급여 주기: 유아 매일 → 어린개체 격일 → 성체 주 2~3회
    크기 기준: "머리 너비보다 작은 곤충"
    ⚠️ 야생 곤충 절대 금지 (기생충/농약)

[초보 실수 상세]
  → 화면: 아코디언 리스트 (탭하면 상세 + 대안 펼침)
    ❌ 히트록 사용 → 복부 화상. 서모스탯 연결 히팅패드로!
    ❌ 모래 단독 기질 → 장폐색. 야생 서식지는 암석 지대
    ❌ 야간 조명 → 적색광도 인식함. 세라믹 히터로!
    ❌ 베타카로틴 보충제만 → 레티놀 전환 불가. 레티놀 형태 필수
    ... (종별 5~9개)

[모프 계산기] 위키에서 종 선택 상태로 진입
  → 화면: 아빠 모프 드롭다운 / 엄마 모프 드롭다운 / [결과 보기]
  → 결과: 퍼넷 스퀘어 기반 확률순 결과 카드
  → 경고: 치사 조합(릴리화이트×릴리화이트, 화이트아웃×화이트아웃) 빨간 경고 표시
  → 건강 주의: 에니그마 증후군, 레몬 프로스트 종양 등 경고

[종 비교] 3종 비교 테이블
  → 화면: 온도, 습도, 사육장 크기, 난이도, 먹이 등 항목별 나란히 비교


━━━ 흐름 3: 내 개체 등록 ━━━

[내 개체 탭 — 빈 상태]
  → 화면:
    "아직 등록된 개체가 없어요"
    [+ 개체 등록하기]

[개체 등록 폼]
  → 화면:
    이름*:        [          ]  ← "모찌"
    종 선택*:     [레오파드 게코 ▾]  ← 3종 우선, 직접 입력도 가능
    모프:         [마크스노 ▾]  ← 종 선택 시 모프 목록 자동 로드
    성별:         [♂ 수컷 | ♀ 암컷 | ❓ 미확인]
    생년월(추정):  [2025년 3월]
    입양일:       [2025년 5월]
    체중(g):      [    ] (선택)
    사진:         [📷 사진 추가]  ← 갤러리/카메라
    메모:         [          ]
    [저장]

[내 개체 목록]
  → 카드 리스트:
    ┌──────────────────────────┐
    │ 📷  모찌                  │
    │ 레오파드 게코 · 마크스노 · ♂│
    │ 입양 11개월째              │
    └──────────────────────────┘

[개체 상세]
  → 프로필 카드 (사진, 이름, 종, 모프, 성별, 나이, 체중)
  → "이 종의 사육 위키 보기" 바로가기
  → 메모 / 체중 기록 히스토리
  → [수정] [삭제]


━━━ 흐름 4: 홈 — 개체 등록 후 재방문 ━━━

[홈 — 개체 있음]
  → 화면:
    ⏰ 자진신고 마감 D-XX 배너
    ─────────────────
    🦎 내 개체 (2)
    [📷 모찌 · 레오파드] [📷 꼬미 · 크레스티드]
    [+ 추가]
    ─────────────────
    📖 사육 가이드
    [레오파드 게코] [크레스티드 게코] [펫테일 게코]
    ─────────────────
    🔍 백색목록 검색


━━━ 흐름 5: 자진신고 가이드 ━━━

[자진신고 탭]
  → 화면:
    ⏰ 자진신고 마감까지 D-XX
    기한: 2026.6.13 | 계도기간: ~2026.12.13

    ⚠️ 주의: 정부24가 아닙니다!
    📌 WIMS 바로가기 (wims.mcee.go.kr) [열기]

    ▸ 10단계 절차 (아코디언)
    1. WIMS 접속
    2. 회원가입/로그인
    3. 민원신청 메뉴
    4. 카테고리 선택 (지정관리 야생동물)
    5. 신고 유형 선택 (양도·양수·보관 신고)
    6. 보관 선택
    7. 신고서 작성 (종명, 수량, 취득일, 경위)
    8. 서류 첨부 (PDF/PNG/JPG)
    9. 제출
    10. 확인증 발급 (즉시~3일)

    📎 필요 서류 체크리스트
    ☐ 신고서 (WIMS 자동 제공)
    ☐ 동물 사진 (측면·전면)
    ☐ 취득경위 증빙 (영수증 또는 경위서)

    💬 자주 묻는 질문 (8개)
    "자진신고 = 보관신고 같은 건가요?"
    "정부24에서 하나요?"
    "6/13 넘기면 바로 과태료?"
    ...


━━━ 흐름 6: 백색목록 검색 ━━━

[홈에서 검색바 탭]
  → 검색 오버레이/화면
  → 입력: "레오파드"
  → 결과: 실시간 필터링 (한글명/학명/영어명)
  → 3종은 🟢 "상세 정보 보기" 뱃지 → 위키로 연결
  → 나머지 종은 합법 여부 + 카테고리만 표시, "사육 정보 곧 추가 예정"
```

## 5. 화면 목록

### 기본 화면
| 화면 | 경로 | 설명 |
|------|------|------|
| SplashScreen | / | 로고 1초 → HomeScreen |
| HomeScreen | /home | 대시보드 (D-day, 내 개체 요약, 사육 가이드, 검색) |
| ErrorScreen | /error | 에러 표시 + 재시도 |

### 위키 화면
| 화면 | 경로 | 설명 |
|------|------|------|
| WikiScreen | /wiki | 종 선택 + 범주 그리드 |
| WikiDetailScreen | /wiki/:speciesId/:category | 범주별 상세 (temperature, enclosure, diet, mistakes) |
| SpeciesCompareScreen | /wiki/compare | 3종 비교 테이블 |
| MorphCalcScreen | /wiki/:speciesId/morph-calc | 모프 유전 계산기 |

### 내 개체 화면
| 화면 | 경로 | 설명 |
|------|------|------|
| MyPetsScreen | /my-pets | 개체 목록 + 어젯밤 리포트 탭 |
| PetAddScreen | /my-pets/add | 개체 등록 폼 |
| PetDetailScreen | /my-pets/:petId | 개체 상세 (프로필, 메모, 체중 기록) |
| PetEditScreen | /my-pets/:petId/edit | 개체 수정 |

### 자진신고 화면
| 화면 | 경로 | 설명 |
|------|------|------|
| GuideScreen | /guide | D-day + 10단계 + 서류 + FAQ |

### 검색 화면
| 화면 | 경로 | 설명 |
|------|------|------|
| SearchScreen | /search | 백색목록 검색 (오버레이 또는 풀스크린) |

> **TODO (P1):** OnboardingScreen (첫 실행 종 선택 + 소개)
> **TODO (P2):** LoginScreen, ProfileScreen, NotificationScreen

## 6. 데이터 모델

> Phase 0은 백엔드 없이 동작. 번들 데이터는 `assets/data/` JSON, 사용자 데이터는 Hive 로컬 저장.

### Species (백색목록 종)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | String | Y | 고유 ID (예: "leopard-gecko") |
| koreanName | String | Y | 한글명 |
| scientificName | String | Y | 학명 |
| commonName | String? | N | 영어 일반명 |
| category | String | Y | "도마뱀" / "뱀" / "거북" / "양서류" |
| family | String | Y | 과명 |
| registrationRequired | bool | Y | 자진신고 대상 여부 |
| hasCareInfo | bool | Y | 사육 정보 존재 여부 (3종만 true) |
| hasMorphData | bool | Y | 모프 데이터 존재 여부 |
| tags | List\<String\> | Y | 태그 |

### CareInfo (사육 정보 — 3종)

```json
{
  "species_id": "leopard-gecko",
  "species_name_ko": "레오파드 게코",
  "scientific_name": "Eublepharis macularius",
  "last_updated": "2026-04-01",
  "difficulty": "beginner",
  "lifespan": "10~20년",
  "adult_size": "전장 18~25cm, 체중 45~80g",
  "temperament": "온순하고 핸들링 친화적...",
  "temperature": {
    "basking_surface": { "min": 34, "max": 36 },
    "hot_zone": { "min": 32, "max": 33 },
    "cool_zone": { "min": 21, "max": 25 },
    "night": { "min": 16, "max": 22 },
    "unit": "℃",
    "notes": "한국 기후 적응 팁"
  },
  "humidity": {
    "min": 30, "max": 40,
    "humid_hide": { "min": 70, "max": 80 },
    "notes": "계절별 주의사항"
  },
  "enclosure": {
    "min_size": "90×45×45cm",
    "substrate": ["권장 기질 목록"],
    "substrate_avoid": ["피해야 할 기질"],
    "essentials": ["필수 용품"],
    "lighting": "조명 가이드"
  },
  "diet": {
    "main": ["주식 목록"],
    "treat": ["간식"],
    "supplement": ["보충제 + 주기"],
    "frequency": "성장 단계별 급여 주기",
    "feeding_size": "크기 기준",
    "water": "급수 방법",
    "notes": "주의사항"
  },
  "common_mistakes": ["실수 + 대안 설명"],
  "sources": ["출처"]
}
```

### MorphGenetics (모프 유전 데이터 — 3종)

```json
{
  "species_id": "leopard-gecko",
  "calculator_type": "full",
  "genes": [
    {
      "id": "tremper-albino",
      "name": "트렘퍼 알비노",
      "inheritance": "recessive",
      "allele_group": "albino",
      "description": "설명",
      "health_warning": "건강 경고 (해당 시)"
    }
  ],
  "morphs": [
    {
      "id": "raptor",
      "name": "랩터",
      "genes": ["tremper-albino", "eclipse", "murphy-patternless"],
      "description": "콤보 설명"
    }
  ],
  "notes": { "특이사항 키-값" }
}
```

**3종 모프 데이터 현황:**

| 종 | 유전자 수 | 모프/콤보 수 | 계산기 타입 | 특이사항 |
|----|----------|-------------|------------|---------|
| 레오파드 게코 | 15 | 20+ | full | 3계통 알비노 별개 로커스, 에니그마 증후군 경고 |
| 펫테일 게코 | 10 | 17 | full | 화이트아웃 호모 치사, 패턴리스 로커스 대립유전자 |
| 크레스티드 게코 | 4 (멘델) + 11 (라인브리드) | 9 | mini | 릴리화이트 호모 치사, 대부분 폴리제닉 |

### Pet (내 개체 — Hive 로컬 저장)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | String | Y | UUID |
| name | String | Y | 개체 이름 |
| speciesId | String | Y | 종 ID |
| speciesName | String | Y | 종 한글명 (표시용) |
| morph | String? | N | 모프명 |
| sex | String | Y | "male" / "female" / "unknown" |
| birthDate | DateTime? | N | 생년월 (추정) |
| adoptionDate | DateTime? | N | 입양일 |
| weight | double? | N | 최근 체중 (g) |
| photoPath | String? | N | 로컬 사진 경로 |
| memo | String? | N | 자유 메모 |
| createdAt | DateTime | Y | 등록일 |
| updatedAt | DateTime | Y | 수정일 |

### WeightLog (체중 기록)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | String | Y | UUID |
| petId | String | Y | 개체 ID |
| weight | double | Y | 체중 (g) |
| date | DateTime | Y | 측정일 |
| note | String? | N | 메모 |

### GuideData (자진신고 가이드)

```json
{
  "deadline": "2026-06-13",
  "grace_period_end": "2026-12-13",
  "report_system": {
    "name": "야생동물종합관리시스템 (WIMS)",
    "url": "https://wims.mcee.go.kr"
  },
  "steps": [10단계],
  "required_documents": [서류 목록],
  "faq": [8개 FAQ]
}
```

## 7. API 엔드포인트

> Phase 0은 백엔드 없음. 전부 로컬.

| 기능 | Phase 0 | Phase 2 |
|------|---------|---------|
| 종 검색 | 로컬 JSON 필터링 | GET /species?q= |
| 사육 정보 | 로컬 JSON 로드 | GET /species/:id/care |
| 모프 계산 | 로컬 엔진 | GET /morph/calc |
| 내 개체 CRUD | Hive 로컬 | Supabase RPC |
| 인증 | 없음 | Supabase Auth |

> Repository 패턴으로 데이터 접근 추상화. P2에서 구현체만 교체.

## 8. 테마/스타일
- **Primary Color**: #2E7D32 (Green 800 — 테라리움/자연)
- **Secondary Color**: #FF8F00 (Amber 800 — 따뜻한 악센트)
- **다크 모드**: 지원 (ColorScheme.fromSeed)
- **폰트**: Pretendard (한글)
- **디자인**: Material Design 3

## 9. 다국어
- **기본**: ko (Phase 0 한글 단일)
- **번역**: Generator 기반 ko.json. 학명/영어명은 직접 표시

> **TODO (P1):** en 추가

## 10. 기술 스택

| 영역 | 선택 |
|------|------|
| 프레임워크 | Flutter |
| 상태관리 | Riverpod |
| 라우팅 | GoRouter |
| 로컬 저장 | Hive (내 개체, 설정) |
| 번들 데이터 | assets/data/ JSON |
| 이미지 | 로컬 갤러리/카메라 (image_picker) |

## 11. 데이터 파일 구조

```
assets/data/
├── whitelist.json              ← 백색목록 종 (검색용)
├── care_info/
│   ├── leopard-gecko.json      ← 레오파드 게코 사육 정보
│   ├── crested-gecko.json      ← 크레스티드 게코 사육 정보
│   └── fat-tailed-gecko.json   ← 펫테일 게코 사육 정보
├── morphs/
│   ├── leopard-gecko.json      ← 모프 유전 데이터 (15 유전자, 20+ 콤보)
│   ├── crested-gecko.json      ← 모프 유전 데이터 (4 멘델 + 11 라인브리드)
│   └── fat-tailed-gecko.json   ← 모프 유전 데이터 (10 유전자, 17 모프)
└── guide_steps.json            ← 자진신고 가이드 (WIMS 10단계 + FAQ)
```

> 데이터 소스: `/Users/baek/tera-ai-product-master/products/app/data/` 에서 복사/변환

---

## 부록: 메인 3종 요약

### 레오파드 게코 (Eublepharis macularius)
- 난이도: 입문 | 수명: 10~20년 | 크기: 18~25cm
- 온도: 핫존 32~33℃, 쿨존 21~25℃, 야간 16~22℃
- 습도: 30~40% (습도 하이드 70~80%)
- 사육장: 90×45×45cm, 배열(히팅패드) 필수
- 먹이: 듀비아/귀뚜라미/밀웜, 성체 주 2~3회
- 모프: 15개 유전자, RAPTOR/디아블로 블랑코 등 20+ 콤보

### 크레스티드 게코 (Correlophus ciliatus)
- 난이도: 입문 | 수명: 15~20년 | 크기: 18~23cm
- 온도: 핫존 26~29℃ (29℃ 초과 치명!), 야간 18~22℃
- 습도: 60~80% (건습 사이클 핵심)
- 사육장: 45×45×60cm (세로형), 수목성
- 먹이: CGD(Pangea/Repashy) + 귀뚜라미, 성체 격일
- 모프: 4 멘델 유전자 + 11 라인브리드 (릴리화이트 호모 치사)

### 펫테일 게코 (Hemitheconyx caudicinctus)
- 난이도: 입문 | 수명: 10~20년 | 크기: 18~25cm
- 온도: 핫존 32~35℃, 쿨존 24~27℃, 야간 20~24℃
- 습도: 50~70% (레오파드보다 높음! 습도 하이드 80~90%)
- 사육장: 60×30×30cm~90×45×30cm
- 먹이: 귀뚜라미/듀비아, 성체 주 2~3회
- 모프: 10개 유전자, 화이트아웃 호모 치사, 17 모프/콤보
