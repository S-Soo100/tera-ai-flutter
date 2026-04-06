## 데카르트의 의심 보고서

### 의심 지수: 7/10

---

### 기만적 변환 목록

| # | 위치 | 변환 | 위험도 |
|---|------|------|--------|
| 1 | `fat-tailed-gecko.json` → `CareInfoDetail.fromJson` | `humid_hide`가 JSON에서 **문자열**인데, 파서는 `is Map` 체크 후 `TempRange.fromJson()` 호출. 문자열이니까 조건 통과 안 하고 **조용히 null**로 바뀜 | **CRITICAL** — 펫테일 게코의 습도 하이드 정보가 UI에서 아예 사라져 |
| 2 | `morph_repository.dart` (old morph_calc) | species ID가 `'leo-gecko'`로 하드코딩, 나머지는 전부 `'leopard-gecko'` | **CRITICAL** — 두 개의 모프 계산기 시스템이 서로 연결 안 됨 |
| 3 | `guide_screen.dart` vs `guide_providers.dart` | **guideDataProvider가 두 번 선언됨**. 동일 이름의 그림자 변수 | **HIGH** |
| 4 | `guide_repository.dart` | 5단계(정부24). JSON은 10단계(WIMS). 서로 다른 시스템을 안내 | **HIGH** — 레거시 dead code |
| 5 | `fat-tailed-gecko.json` 모프 genes | `"amel/amel"` 슬래시 표기법 vs 레오파드의 `["tremper-albino"]`. `_checkWarnings()`에서 치사 경고 불발 | **MEDIUM** |
| 6 | `crested-gecko.json` | `substrate_avoid` 필드 없음 → 빈 리스트로 패스 | **LOW** |

### 산술 붕괴 시나리오

#### D-day의 코기토: 4곳에서 독립 계산
1. `AppConstants.daysUntilDeadline`
2. `guide_providers.dart` ddayProvider
3. `guide_data.dart` GuideData.daysRemaining
4. `home_screen.dart` 인라인 계산

- 마감일 당일(6/13) `D-0` 표시 — "오늘 마감"인지 "지났"는지 구분 불가
- `home_screen.dart`는 음수 체크 없어 `D--3` 같은 문자열 발생

#### 확률의 명증
- old `morph_repository.dart`의 "수퍼스노 0.25" 표기가 het 포함인지 불명확
- wiki 모프 계산기는 빈 껍데기 (항상 "준비 중" 메시지)

#### 종 ID 참조 무결성
| 소스 | 동기화 |
|------|--------|
| species_repository, app_constants, care_info_repository, JSON | OK |
| **morph_repository.dart (old)** `'leo-gecko'` | **BROKEN** |

#### Hive 직렬화
- Pet(typeId 0, 13필드), WeightLog(typeId 1, 5필드) — .g.dart와 일치
- 위험: `createdAt`/`updatedAt` non-nullable cast → 스키마 변경 시 런타임 크래시

### 판정
**펫테일 게코의 습도 하이드가 조용히 증발한다** — 가장 위험한 기만적 파싱. 이 데이터는 사육자의 생명줄이야. **모프 계산기가 분열되어 있고**, **D-day가 네 곳에서 독립 계산된다**.
