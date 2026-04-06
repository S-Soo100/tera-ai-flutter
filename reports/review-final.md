# 종합 검수 결과 — 크리틱 + 검수 1차

> 일시: 2026-04-06
> 대상: tera-ai-flutter (앱 v2 전면 리팩토링 커밋)
> 검수자: 4철학자(데카르트/소크라테스/쇼펜하우어/니체) + 4모델(Gemini/Opus/Sonnet/Haiku)

---

## 요약

| 검수자 | 점수 | 핵심 한마디 |
|--------|------|------------|
| 데카르트 | 7/10 | "펫테일 습도 하이드가 조용히 증발한다" |
| 소크라테스 | 7/10 | "위키로 가는 모든 경로가 종 정보 없이 /wiki만 호출" |
| 쇼펜하우어 | 7/10 | "법규 면책 조항이 UI 어디에도 없다" |
| 니체 | 7/10 | "6/13 이후 이 앱을 다시 열 이유가 없다" |
| Gemini | - | HomeScreen Riverpod 반응성 누락 |
| Opus | 21건 | guideDataProvider 이중 정의, pet 동기화 단절 |
| Sonnet | 17건 | 코드베이스 40% dead code, D-day 3중 중복 |
| Haiku | Yes | pet_edit_screen 초기화 로직이 가장 약함 |
| **종합** | **7/10** | **위키 종 전달 누락 + Dead code 40% + D-day 중복이 3대 이슈** |

---

## 🔴 다수 공통 — 반드시 수정 (5개 이상 지적)

### 1. 레거시 Dead Code ~40% (6명 지적)
> 데카르트, 소크라테스, 니체, Gemini, Opus, Sonnet

- `features/species_detail/` 폴더 전체 (라우터 미등록)
- `features/morph_calc/` 폴더 전체 (구버전, ID도 `leo-gecko`로 불일치)
- `features/home/presentation/` — species_card.dart, category_chips.dart, popular_searches.dart
- `features/guide/data/guide_repository.dart` — 정부24 기반 5단계 (구버전)
- `features/guide/domain/guide_step.dart` — 구버전 모델
- `features/guide/presentation/dday_countdown.dart` — 미사용
- `features/home/domain/care_info.dart` — 구버전 모델
- `lib/shared/` — connectivity_provider.dart (return true 하드코딩), legal_badge.dart

**조치**: 레거시 파일 일괄 삭제. 라우터에 등록되지 않은 모든 화면/위젯 제거.

### 2. 위키 이동 시 종 정보 미전달 (5명 지적)
> 소크라테스, 니체, Gemini, Opus, Haiku

- `home_screen.dart` — 사육 가이드 카드 onTap이 `context.go('/wiki')`만 호출
- `pet_detail_screen.dart` — "이 종의 사육 위키 보기"가 `context.push('/wiki')`만 호출
- `search_screen.dart` — featured 종 "상세 정보"가 `context.go('/wiki')`만 호출

**조치**: 이동 전에 `ref.read(selectedWikiSpeciesProvider.notifier).state = speciesId` 설정, 또는 쿼리 파라미터로 전달.

### 3. D-day 계산 4중 중복 (5명 지적)
> 데카르트, 소크라테스, Gemini, Opus, Sonnet

- `home_screen.dart:17` — 인라인 계산
- `guide_providers.dart:13` — Provider로 계산
- `app_constants.dart:26` — static getter
- `guide_data.dart:128` — JSON deadline 파싱

**조치**: `AppConstants.daysUntilDeadline` 하나로 통일. 나머지 계산 모두 제거.

---

## 🟡 2~4모델 공통 — 수정 권장

### 4. HomeScreen pet 상태 갱신 안 됨 (3명)
> 소크라테스, Gemini, Opus

`petRepositoryProvider`를 직접 watch → Hive 변경을 감지 못함.
**조치**: `ref.watch(petListProvider)` 사용으로 변경.

### 5. guideDataProvider 이중 정의 (3명)
> 데카르트, Opus, Sonnet

guide_screen.dart와 guide_providers.dart에 동일 이름 provider 존재.
**조치**: guide_screen.dart의 로컬 정의 제거, guide_providers.dart의 것을 import.

### 6. 모프 계산기 빈 껍데기 (3명)
> 데카르트, 니체, Sonnet

wiki/morph_calc_screen.dart가 항상 "준비 중" 메시지만 표시.
**조치**: 퍼넷 스퀘어 엔진 구현 또는 기능 설명 개선 ("곧 추가" → 구체적 안내).

### 7. 미사용 의존성 (2명)
> 쇼펜하우어, Sonnet

dio, flutter_secure_storage, connectivity_plus — 미사용이면서 공격 표면 확장.
**조치**: pubspec.yaml에서 제거.

### 8. 펫테일 humid_hide 파싱 실패 (2명)
> 데카르트, Opus(암시)

fat-tailed-gecko.json의 `humid_hide`가 문자열인데 CareInfoDetail.fromJson이 Map만 처리.
**조치**: 문자열 케이스 추가 처리, 또는 JSON 구조를 Map으로 수정.

---

## 🔵 단독 지적 — 확인 필요

| 이슈 | 출처 | 심각도 |
|------|------|--------|
| 법규 면책 조항(disclaimer) 부재 | 쇼펜하우어 | 높음 (법적 리스크) |
| 체크리스트 비영속 (앱 재시작 시 초기화) | 니체 | 중간 |
| WIMS url_launcher 미구현 (SnackBar로 URL만 표시) | 니체 | 중간 |
| 체중 입력에 복수 소수점 허용 `1.2.3` | Opus | 낮음 |
| pet_edit_screen _initFromPet build마다 호출 | Haiku | 중간 |
| Species.commonName non-nullable (스펙은 nullable) | Opus | 낮음 |
| 홈→등록→pop 시 탭 불일치 | 소크라테스 | 중간 |
| google_fonts 런타임 폰트 다운로드 시도 가능성 | 쇼펜하우어 | 낮음 |
| 모프 genes 슬래시 표기법 불일치 | 데카르트 | 중간 |
| Hive typeId 마이그레이션 위험 | 쇼펜하우어 | 미래 |

---

## 💡 Haiku 직감 판정
- **동작 여부**: Yes — 기본 흐름은 동작하지만 상태 동기화에 구멍
- **가장 약한 부분**: pet_edit_screen의 `_initFromPet()`
- **최우선 수정**: pet_edit_screen 초기화 → initState로 이동

## 🟢 Sonnet 실용성 평가
- **과잉 설계**: 3종 앱에 검색 UI는 과함. 홈 대시보드도 위키와 중복
- **코드베이스 40% 데드**: 모프계산기 이중, species_detail 미사용, 구버전 가이드
- **1인 유지보수**: 현재 구조에서 "어디를 고쳐야 하지?" 혼란 예상
