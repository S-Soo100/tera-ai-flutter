# 크레스티드 게코 모프 데이터 업데이트 — 에이전트 브리핑

> 작성: 2026-04-14, product-master 레포에서 전달  
> 대상: tera-ai-flutter 프로젝트 AI 에이전트

---

## 무엇이 바뀌었나

### 1. 리서치 문서 5종 추가 (`docs/species-research/`)

| 파일 | 내용 | 핵심 포인트 |
|------|------|------------|
| `crested-gecko-sable-morph.md` | 세이블 모프 종합 | 불완전우성, Gecko Haven 발견, 한국 브리더 핵심 역할, 슈퍼 세이블 건강 OK |
| `crested-gecko-axanthic-morph.md` | 아잔틱 모프 종합 | 유일한 열성, 3대 라인(AE/MSL/Obscurial), 색소세포 생물학 |
| `crested-gecko-cappuccino-morph.md` | 카푸치노+하이웨이 | RCK 한국 발견, 슈퍼폼 건강 이슈, 대립유전자 복합체 |
| `crested-gecko-lilly-white-morph.md` | 릴리 화이트 종합 | UK 발견, 치사 슈퍼폼, 콤보 수요 1위 |
| `crested-gecko-pattern-color-morphs.md` | 패턴·색상·구조 형질 | 7그룹 재분류, 팬텀(열성), 2025 시장 가격표 |

**모든 문서에 원본 출처 URL 포함** (영문+한국어 총 80+ 소스). AI 컨텍스트 빌더에서 참조 가능.

### 2. `assets/data/morphs/crested-gecko.json` 업데이트

#### 추가된 것

**genes 섹션 (4 → 6개):**
- `sable` — 세이블 (불완전우성, allele_group 지정)
- `highway` — 하이웨이 (불완전우성, allele_group 지정)
- 기존 `cappuccino`에 `allele_group: "cappuccino-sable-highway"` 추가
- 모든 유전자에 `discovered_by`, `discovered_year` 필드 추가

**allele_groups 섹션 (신규):**
- `cappuccino-sable-highway` 복합체 정의
- `cross_results`: 루왁 등 복합 헤테로 결과
- `super_health`: 슈퍼폼별 건강 상태 비교

**morphs 섹션 (9 → 17개):**
- `sable`, `super-sable`, `luwak`, `sorak`, `lilly-sable`, `phantom-axanthic`, `phantom-cappuccino`, `luwak-lilly` 추가

**line_bred_traits 섹션 (11 → 22개):**
- 7그룹 분류 체계 적용 (`group` 필드 추가)
- `brindle`, `patternless`, `quadstripe`, `superstripe`, `empty-back`, `snowflake`, `whitewall`, `chevron`, `halloween`, `cream`, `crowned` 추가
- `pinstripe`에 `variants` 배열 추가

**pattern_groups 섹션 (신규):**
- `flame-harlequin`: 커버리지 스펙트럼
- `tiger-brindle`: 연속성 스펙트럼
- `pinstripe`: 구조적 변형 계열
- `spot`: 점 유형 계열

#### 수정된 것

- `last_updated`: `2026-04-01` → `2026-04-14`
- `calculator_note`: 유전자 6개로 업데이트, 대립유전자 복합체 언급 추가
- `cappuccino` gene: `allele_group: null` → `"cappuccino-sable-highway"`, `health_warning` 추가
- `axanthic` 한글명: `액산틱` → `아잔틱` (표준 표기)
- 각 유전자·모프 `description` 리서치 기반으로 보강

---

## 앱 코드에서 활용 포인트

### 브리딩 계산기 (Morph Calculator)

1. **대립유전자 복합체 로직 필요**
   - `allele_groups`의 `members`를 읽어서, 같은 그룹 유전자끼리는 **같은 좌위에서 경쟁**하도록 계산
   - 예: 카푸치노 × 세이블 → 루왁(복합 헤테로), 카푸치노 × 카푸치노 ≠ 세이블 × 세이블
   - `cross_results`로 복합 헤테로 이름/설명 자동 매핑

2. **건강 경고 시스템**
   - `homozygous_lethal: true` → 릴리 × 릴리 교배 시 경고
   - `health_warning` 필드 → 슈퍼 카푸치노/하이웨이 생산 시 경고
   - `super_health` → 슈퍼폼 비교 정보 제공

3. **유전자 6개로 확장**
   - 기존 4개(릴리/아잔틱/팬텀/카푸치노) → 6개(+세이블/하이웨이)
   - 대립유전자 복합체 내 조합은 별도 로직 (일반 독립 유전자와 다름)

### 위키/도감 (Species Wiki)

4. **패턴 그룹 계층 구조**
   - `pattern_groups`로 스펙트럼 관계 시각화
   - `group` 필드로 관련 형질 묶어서 표시

5. **리서치 문서 → 컨텍스트 빌더**
   - `docs/species-research/*.md`의 내용을 AI 채팅 컨텍스트에 활용 가능
   - 특히 모프별 역사·유전 설명, 식별 팁, 건강 정보

### 가격/시장 정보

6. **리서치 문서에 2025 시장 가격표 포함**
   - `pattern-color-morphs.md` 하단의 종합 가격표
   - 한국 시장 가격도 포함 (원화)
   - 앱에 가격 참고 기능 추가 시 데이터 소스로 활용

---

## 주의사항

- `allele_groups`는 새 섹션이므로 **파서가 이 필드를 읽을 수 있는지 확인** 필요
- `pattern_groups`도 새 섹션 — 위키 UI에서 활용하려면 모델 클래스 확장 필요
- `line_bred_traits`의 `group` 필드도 신규 — 기존 파서와 호환성 체크
- `zygosity` 필드가 일부 morphs에 추가됨 (super-cappuccino, super-sable, sorak)
- JSON 스키마 변경이므로 **기존 Hive/모델 클래스 업데이트 후 적용** 권장

---

## 원본 레포

- product-master: `feat/knowledge-graph-layer` 브랜치
- 커밋: `5fea372 feat: 크레스티드 게코 모프 종합 리서치 5종 문서화`
