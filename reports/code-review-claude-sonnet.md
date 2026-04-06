# Claude Sonnet 코드 검수 결과 (실용성)

> 검수 일시: 2026-04-06  
> 검수 모델: claude-sonnet-4-6  
> 검수 기준: 과잉 설계 / 단순화 가능 / 중복 코드 / UX 관점 / 유지보수성

---

## 요약

- 발견 이슈: **17건** (심각 3 / 중요 8 / 개선 6)
- 전반적 평가: 구조 자체는 합리적이나, **같은 코드를 두 개의 기능 트리에 병렬로 구현**한 흔적이 뚜렷하다. features/morph_calc와 features/wiki/morph_calc, features/species_detail과 실제 미사용 위젯 등 초기 설계 변경 과정에서 생긴 유물이 정리되지 않았다.

---

## 1. 과잉 설계

### [심각] 모프 계산기가 두 개 존재한다
- `lib/features/morph_calc/` — 구버전. 하드코딩된 lookup table 방식. `leo-gecko` / `ball-python` 두 종만 지원. 실제 앱에서 라우터에 연결되지 않은 상태.
- `lib/features/wiki/presentation/morph_calc_screen.dart` — 현재 실제 사용 중인 버전. JSON 기반 유전 엔진.

구버전 morph_calc 전체 폴더(data, domain, presentation 3개 파일)가 데드 코드다.

**관련 파일:**
- `lib/features/morph_calc/` 폴더 전체 (3파일)
- `lib/features/morph_calc/data/morph_repository.dart:1-67` — `ball-python` 하드코딩, speciesId가 `leo-gecko`로 되어 있어 메인 `leopard-gecko`와도 불일치

### [심각] `species_detail` feature가 현재 앱과 연결되지 않는다
`lib/features/species_detail/` 폴더 전체(화면, 프로바이더, 위젯 3개)가 GoRouter(`lib/core/router/app_router.dart`)에 경로 등록이 없다. `SpeciesCard`에서 `context.push('/species/${species.id}')`를 호출하지만 이 경로가 라우터에 없다.

**관련 파일:**
- `lib/features/species_detail/presentation/species_detail_screen.dart`
- `lib/features/home/presentation/species_card.dart:23` — `/species/` 경로 호출
- `lib/features/home/presentation/category_chips.dart`, `popular_searches.dart` — 사용처 불명

### [중요] `home/domain/care_info.dart`가 실사용되지 않는다
`CareInfo` 클래스는 `CareInfoCard`(`species_detail`)에서만 쓰이는데, `species_detail` 화면 자체가 라우팅에서 제외된 상태다. 실사용 care 정보는 `wiki/domain/care_info_detail.dart`의 `CareInfoDetail`이 담당한다. 두 모델이 같은 목적을 위해 병렬 존재.

**관련 파일:**
- `lib/features/home/domain/care_info.dart` — 전체 데드 코드 가능성 높음
- `lib/features/species_detail/presentation/care_info_card.dart` — 연쇄 데드 코드

---

## 2. 단순화 제안

### [중요] D-Day 계산이 3군데서 독립적으로 계산된다
같은 마감일(2026-06-13)을 향한 D-Day 계산이 세 곳에 흩어져 있다.

| 위치 | 방식 |
|------|------|
| `lib/core/constants/app_constants.dart:27` | `AppConstants.daysUntilDeadline` (static getter) |
| `lib/features/guide/presentation/guide_providers.dart:12-15` | `ddayProvider` (Riverpod Provider, 하드코딩) |
| `lib/features/home/presentation/home_screen.dart:17` | `DateTime(2026, 6, 13).difference(...)` 인라인 계산 |
| `lib/features/guide/domain/guide_data.dart:128-131` | `daysRemaining` getter (JSON의 deadline 파싱) |

`AppConstants.daysUntilDeadline` 또는 `ddayProvider` 하나로 통일하면 된다. `home_screen.dart`의 인라인 계산은 특히 즉시 제거 가능.

### [중요] `guideDataProvider`가 두 파일에 중복 선언된다
- `lib/features/guide/presentation/guide_screen.dart:6-10` — `guideDataProvider` 선언
- `lib/features/guide/presentation/guide_providers.dart:6-10` — 동일한 `guideDataProvider` 선언

두 파일에 동일한 provider가 있어서 import 방향에 따라 어느 쪽이 실제 사용되는지 혼란스럽다. `guide_screen.dart` 내부 선언은 제거하고 `guide_providers.dart`로 단일화해야 한다.

**관련 파일:**
- `lib/features/guide/presentation/guide_screen.dart:6-10`
- `lib/features/guide/presentation/guide_providers.dart:6-10`

### [중요] `GuideRepository`(`guide/data/`)가 실사용되지 않는다
`lib/features/guide/data/guide_repository.dart`는 Riverpod provider로 등록되지 않고, `GuideScreen`도 이를 참조하지 않는다. 실제 Guide 데이터는 `guideDataProvider`가 JSON을 직접 파싱한다. Repository가 있지만 정부24 기준의 낡은 안내(신고 경로 오류 포함)를 하드코딩하고 있어 더 혼란스럽다.

**관련 파일:**
- `lib/features/guide/data/guide_repository.dart` — 전체 데드 코드

### [개선] `GuideStep`이 두 개의 domain 파일에 각각 정의된다
- `lib/features/guide/domain/guide_step.dart` — `detail`이 non-nullable `String`
- `lib/features/guide/domain/guide_data.dart` — `GuideStep`을 다시 정의, `detail`이 nullable `String?`

두 곳에 동일한 이름의 클래스가 있다. `guide_step.dart`의 것은 사용되지 않는다.

**관련 파일:**
- `lib/features/guide/domain/guide_step.dart` — 데드 코드 (guide_data.dart의 것으로 통일)

### [개선] `SpeciesRepository`에 `getAll()`과 `allSpecies` getter가 중복이다
- `lib/features/home/data/species_repository.dart:63` — `get allSpecies`
- `lib/features/home/data/species_repository.dart:67` — `getAll()` (allSpecies를 그대로 반환)

둘 중 하나만 남겨도 된다. 1인 개발에서 이런 alias는 혼란만 가중.

### [개선] `connectivity_provider.dart`가 stub이다
`lib/shared/providers/connectivity_provider.dart`는 항상 `true`를 반환하는 stub이고, 앱 어디에서도 이 provider를 `watch`하는 코드가 없다. `dio`와 `connectivity_plus` 패키지를 쓰고 있지만 오프라인 처리가 전혀 없다. 파일을 지우거나 실제 구현을 붙여야 한다.

---

## 3. 중복 코드

### [심각] `PetAddScreen`과 `PetEditScreen`의 폼이 거의 동일하다
두 화면이 공유하는 코드:
- `_speciesOptions` 상수 — 두 파일에 동일하게 하드코딩
- `_morphsBySpecies` 상수 — 두 파일에 동일하게 하드코딩 (합계 약 50줄이 두 번)
- `_pickDate()` 메서드 — 거의 동일
- `_formatDate()` 메서드 — 완전 동일
- 폼 필드 위젯 블록 — 종 선택, 모프, 성별, 날짜, 체중, 메모 전체 반복

특히 `_morphsBySpecies`는 Add에서 수정해도 Edit에 반영이 안 되는 버그로 이어질 수 있다.

**관련 파일:**
- `lib/features/my_pets/presentation/pet_add_screen.dart:39-82` — 모프 상수
- `lib/features/my_pets/presentation/pet_edit_screen.dart:39-82` — 동일 모프 상수 복붙
- 두 파일의 `_formatDate`, `_pickDate` 메서드

### [중요] `_InfoRow` 위젯이 두 feature에 각각 존재한다
- `lib/features/wiki/presentation/wiki_detail_screen.dart:208-236` — `_InfoRow` (label 고정폭 100)
- `lib/features/species_detail/presentation/care_info_card.dart:113-144` — `_InfoRow` (label 고정폭 80)

같은 역할인데 폭만 다르다. `shared/widgets/`로 빼서 파라미터화하면 된다.

### [중요] `_SectionHeader` 위젯도 두 feature에 각각 존재한다
- `lib/features/wiki/presentation/wiki_detail_screen.dart:189-206` — primary 색상 적용
- `lib/features/species_detail/presentation/care_info_card.dart:97-111` — 색상 없음

**관련 파일:**
- `lib/shared/widgets/` — 현재 `legal_badge.dart` 하나뿐. 공통 위젯 추가 여지.

### [중요] D-Day 배너 위젯도 두 개다
- `lib/features/guide/presentation/dday_countdown.dart` — `DdayCountdown` (큰 숫자 강조형)
- `lib/features/species_detail/presentation/dday_banner.dart` — `DdayBanner` (한 줄 텍스트형)
- `lib/features/home/presentation/home_screen.dart:32,75-122` — `_DdayBanner` (인라인 구현)

총 3가지 D-Day 배너 구현체가 있다. `home_screen.dart`의 것이 가장 완성도가 높고 실제로 보이는 것이므로, 나머지 둘은 현재 연결 경로 없음.

---

## 4. UX 관점

### [중요] 모프 계산기의 "결과 보기" 버튼이 빈 결과를 보여준다
`lib/features/wiki/presentation/morph_calc_screen.dart:144-147`에서 계산 버튼 클릭 시 "퍼넷 스퀘어 엔진이 곧 추가될 예정이에요"라는 플레이스홀더 텍스트가 나온다. 버튼이 활성화되어 누를 수 있는 상태인데 결과가 없다면, 유저는 버그인지 미구현인지 구분하지 못한다. 버튼을 비활성화하거나, 탭 자체에서 "준비 중" 배지를 붙이는 게 낫다.

**관련 파일:**
- `lib/features/wiki/presentation/morph_calc_screen.dart:112-157`

### [중요] 홈 화면의 "사육 가이드" 섹션 탭이 위키 루트로만 이동한다
`lib/features/home/presentation/home_screen.dart:52` — 3종 카드를 탭하면 `context.go('/wiki')`로 이동해서 종 선택 상태가 초기화된다. 유저가 "크레스티드 게코" 카드를 탭했는데 위키에서 레오파드 게코가 선택된 채 열린다. `selectedWikiSpeciesProvider`를 같이 변경하거나, 경로에 speciesId를 담아야 한다.

**관련 파일:**
- `lib/features/home/presentation/home_screen.dart:52`

### [중요] 검색 화면에서 "상세 정보" ActionChip이 위키 루트만 간다
`lib/features/search/presentation/search_screen.dart:93` — 검색 결과에서 상세 정보 버튼을 누르면 `context.go('/wiki')`로 이동. 검색한 종을 선택하고 들어갔는데 해당 종이 선택되지 않은 채 위키가 열린다.

### [개선] 체중 기록 삭제에 확인 다이얼로그가 없다
`lib/features/my_pets/presentation/pet_detail_screen.dart:366` — X 버튼 한 번으로 체중 로그가 즉시 삭제된다. 개체 삭제는 확인 다이얼로그가 있는데(`_confirmDelete`) 체중 기록 삭제는 없다. 실수로 누르면 복구 불가.

### [개선] `GuideScreen`의 WIMS 바로가기 버튼이 URL을 SnackBar로 보여준다
`lib/features/guide/presentation/guide_screen.dart:104-118` — `url_launcher`가 없어서 실제 이동 대신 URL 문자열을 SnackBar에 표시한다. "바로가기" 버튼인데 아무 데도 가지 않는다. `url_launcher` 패키지를 추가하거나, 버튼 라벨을 "URL 복사"로 바꾸는 게 정직하다.

---

## 5. 유지보수성

### [중요] `_morphsBySpecies` 상수가 JSON 데이터와 이중 관리된다
`pet_add_screen.dart`, `pet_edit_screen.dart` 두 곳에 하드코딩된 모프 목록이 `assets/data/morphs/*.json`의 데이터와 별도로 관리된다. JSON에는 유전 정보까지 있는데, Add/Edit 폼은 별도의 하드코딩 리스트를 쓴다. 나중에 JSON을 업데이트해도 폼의 드롭다운은 바뀌지 않는다.

현실적 해결: `MorphGeneticsData.selectableMorphNames`를 FutureProvider로 올려서 폼에서 `ref.watch`로 읽는 것이 좋다.

### [중요] `pubspec.yaml`에 `dio`와 `flutter_secure_storage`가 있지만 사용처가 없다
앱이 순수 로컬(Hive)로만 동작하는데 네트워크 라이브러리(dio)와 보안 저장소(flutter_secure_storage)를 의존성에 들고 있다. 빌드 크기와 권한 이슈. Phase 1에서 필요하면 그때 추가해도 충분.

**관련 파일:**
- `pubspec.yaml:17-18`

### [개선] `RouteProvider`가 매 빌드마다 새 GoRouter 인스턴스를 만든다
`lib/core/router/app_router.dart:18` — `Provider<GoRouter>`로 선언되어 있어서 Riverpod가 routerProvider를 dispose하고 재생성할 때마다 GoRouter 인스턴스도 새로 만들어진다. GoRouter는 일반적으로 앱 생명주기 동안 단일 인스턴스로 유지해야 한다. `keepAlive: true` 또는 top-level 변수로 빼는 것이 안전하다.

**관련 파일:**
- `lib/core/router/app_router.dart:18`

### [개선] `easy_localization` 도입이 불완전하다
`ko.json`에 키가 정의되어 있지만, 실제 UI 코드에서는 `.tr()` 대신 한국어 리터럴을 직접 쓰는 곳이 대부분이다. 예: `home_screen.dart`의 "사육 가이드", "백색목록 검색", `wiki_screen.dart`의 칩 레이블 전체, `wiki_detail_screen.dart`의 섹션 헤더들, `my_pets_screen.dart` 전체. 단일 언어 앱에서 `easy_localization`의 오버헤드(초기화, JSON 로드)를 감수하면서 정작 `.tr()`은 일부에서만 쓴다. 모두 `.tr()`로 통일하거나, 패키지 자체를 제거하고 상수 파일로 관리하는 게 낫다.

**관련 파일:**
- `pubspec.yaml:14` — easy_localization 의존
- `lib/features/home/presentation/home_screen.dart` — 한국어 리터럴 직접 사용
- `lib/features/wiki/presentation/wiki_screen.dart:10-23` — 칩 레이블 하드코딩

---

## 이슈 우선순위 요약

| 순위 | 이슈 | 파일 | 난이도 |
|------|------|------|--------|
| 1 | `pet_add_screen` / `pet_edit_screen` 모프 상수 중복 → 공통 상수 파일로 분리 | pet_add_screen.dart:39-82, pet_edit_screen.dart:39-82 | 낮음 |
| 2 | `guideDataProvider` 중복 선언 제거 | guide_screen.dart:6-10 | 낮음 |
| 3 | `home_screen.dart` D-Day 인라인 계산 → AppConstants 사용 | home_screen.dart:17 | 낮음 |
| 4 | 홈/검색 → 위키 이동 시 선택 종 동기화 | home_screen.dart:52, search_screen.dart:93 | 낮음 |
| 5 | 데드 코드 정리 (morph_calc 구버전, guide_repository, guide_step 중복, species_detail 미연결) | 폴더 단위 | 낮음 |
| 6 | `dio` / `flutter_secure_storage` 의존성 제거 | pubspec.yaml | 낮음 |
| 7 | 모프 폼 드롭다운 → JSON 데이터에서 동적 로드 | pet_add_screen, pet_edit_screen | 중간 |
| 8 | 모프 계산기 미구현 버튼 처리 | morph_calc_screen.dart:112 | 낮음 |
