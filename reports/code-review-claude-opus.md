# Claude Opus 코드 검수 결과

**검수 일시:** 2026-04-06
**검수 대상:** tera-ai-flutter 전체 lib/ + assets/data/
**검수 모델:** Claude Opus 4.6 (1M context)

## 요약
- 발견 이슈: **21건** (심각 5, 경고 9, 참고 7)

---

## 🔴 심각 (버그/논리 오류)

### S-01. `guideDataProvider` 이중 정의 — 런타임 충돌 또는 데드 코드
- **파일:** `lib/features/guide/presentation/guide_screen.dart:7` + `lib/features/guide/presentation/guide_providers.dart:6`
- **내용:** `guideDataProvider`가 `guide_screen.dart` 상단(line 7)과 `guide_providers.dart`(line 6)에 **동일한 이름으로 두 번 정의**되어 있다. guide_screen.dart가 자체 파일의 로컬 정의를 사용하므로 guide_providers.dart의 것은 무시되지만, 다른 파일에서 guide_providers.dart를 import하면 **다른 인스턴스**의 provider를 watch하게 돼서 캐시 미스 및 이중 로딩이 발생한다.
- **영향:** guide_screen.dart에서 JSON을 로드한 캐시와, guide_providers.dart를 import한 다른 화면의 캐시가 별개로 동작.

### S-02. `SpeciesDetailScreen`의 `careInfoProvider` — 미정의 또는 import 누락
- **파일:** `lib/features/species_detail/presentation/species_detail_screen.dart:26`
- **내용:** `ref.watch(careInfoProvider(speciesId))`를 호출하지만, 이 파일에는 `careInfoProvider`에 대한 import가 없다. `home_providers.dart`를 import하고 있는데, 거기에 `careInfoProvider`는 정의되어 있지 않다. `wiki_providers.dart`에 있는 `careInfoProvider`는 `FutureProvider<CareInfoDetail, String>` 타입인데, species_detail_screen.dart line 59에서 `if (careInfo != null)` 동기적 null 체크를 하고 있어 **타입 불일치** 가능성이 높다. 컴파일 에러이거나, 다른 곳에 별도 `careInfoProvider`가 있어야 하는데 없다.
- **영향:** 이 화면은 빌드 자체가 안 될 수 있음.

### S-03. `SpeciesCard`가 존재하지 않는 라우트 `/species/:id`로 네비게이션
- **파일:** `lib/features/home/presentation/species_card.dart:23`
- **내용:** `context.push('/species/${species.id}')` — 그러나 `app_router.dart`에 `/species/:id` 경로가 **등록되어 있지 않다**. GoRouter에서 매칭 실패 시 에러 발생.
- **영향:** SpeciesCard를 탭하면 라우팅 에러. 다만 현재 HomeScreen에서 SpeciesCard를 직접 사용하지 않으므로 실제 크래시는 안 나지만, 언제든 연결하면 터진다.

### S-04. HomeScreen이 `petRepositoryProvider`를 직접 사용 — petListProvider와 동기화 안 됨
- **파일:** `lib/features/home/presentation/home_screen.dart:14`
- **내용:** `final petRepo = ref.watch(petRepositoryProvider); final pets = petRepo.getAllPets();`로 Hive를 직접 조회한다. 그런데 내 개체 탭에서는 `petListProvider`(StateNotifier)를 통해 CRUD를 수행하고 state를 관리한다. Repository를 직접 조회하면 petListProvider의 state가 갱신되어도 HomeScreen이 **리빌드되지 않는다**. `petRepositoryProvider`는 `Provider<PetRepository>`라서 Hive 데이터가 변해도 ref.watch가 트리거되지 않음.
- **영향:** 내 개체 탭에서 개체를 추가/삭제한 뒤 홈 탭으로 돌아와도 목록이 갱신 안 됨 (탭 재진입 시에도 StatefulShellRoute가 위젯을 유지하므로 안 바뀜).

### S-05. 체중 입력 필드에서 복수 소수점 허용
- **파일:** `lib/features/my_pets/presentation/pet_add_screen.dart:306`, `pet_edit_screen.dart:360`
- **내용:** `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))` — 이 정규식은 `1.2.3.4` 같은 입력도 허용한다. `double.tryParse`에서 null 반환되어 체중이 저장 안 되는 건 안전하지만, UX상 사용자가 입력했는데 저장 안 되는 혼란 발생.
- **영향:** 사용자가 잘못된 체중값을 입력해도 검증 메시지 없이 무시됨.

---

## 🟡 경고 (엣지케이스/설계 결함)

### W-01. D-day 카운트다운이 마감 후 음수 표시
- **파일:** `lib/features/home/presentation/home_screen.dart:99`
- **내용:** `'자진신고 마감 D-$daysLeft'` — 2026.6.13 이후에는 `D--42` 같은 음수가 표시된다. `GuideData.daysRemaining`에는 `isExpired` 체크가 있지만, HomeScreen은 자체 계산(`DateTime(2026, 6, 13).difference(DateTime.now()).inDays`)을 하면서 **만료 처리가 없다**.
- **영향:** 마감 후 어색한 UI. guide_providers.dart의 `ddayProvider`나 `AppConstants.daysUntilDeadline`을 쓰지 않고 3곳에서 각각 D-day를 계산하는 것도 유지보수 리스크.

### W-02. D-day 계산 로직 3중 중복 + 미묘한 차이
- **파일:** `home_screen.dart:17`, `guide_providers.dart:13`, `app_constants.dart:26`, `guide_data.dart:128`
- **내용:** D-day를 4곳에서 독립적으로 계산한다. `DateTime(2026, 6, 13)`을 하드코딩한 곳 2개 + JSON에서 파싱하는 곳 2개. JSON의 deadline이 변경되면 하드코딩 된 곳은 따라가지 않는다.

### W-03. `Species.commonName`이 non-nullable인데 스펙은 nullable
- **파일:** `lib/features/home/domain/species.dart:5`
- **내용:** 스펙(docs/spec.md line 253)에서 `commonName`은 `String?`(nullable)으로 정의했지만 도메인 모델은 `final String commonName`(required). 향후 commonName이 없는 종을 추가하면 빈 문자열을 넣어야 한다.
- **영향:** 데이터 확장 시 마찰.

### W-04. `GuideRepository`와 `GuideData`(JSON 기반) 이중 경로
- **파일:** `lib/features/guide/data/guide_repository.dart`, `lib/features/guide/domain/guide_data.dart`
- **내용:** `GuideRepository`는 "정부24" 기반 5단계 절차를 하드코딩하고 있고, `GuideData`는 JSON에서 "WIMS" 기반 10단계를 로드한다. **스펙은 WIMS 10단계**가 맞다. GuideRepository의 데이터는 완전히 구식(정부24, 5단계)이며, 실제 GuideScreen은 JSON 기반 GuideData를 쓰고 있어 GuideRepository는 dead code이긴 하지만, 누군가 실수로 쓰면 **잘못된 안내**를 제공한다.
- **영향:** 오래된 데이터가 코드에 남아 있어 혼란/사고 위험.

### W-05. 위키 → 종 비교 이동 시 종 선택 상태 미전달
- **파일:** `lib/features/wiki/presentation/wiki_screen.dart:137-138`
- **내용:** "종 비교"를 탭하면 `/wiki/compare`로 이동하는데, `SpeciesCompareScreen`은 항상 3종 전부를 고정으로 비교한다. 이건 스펙상 맞긴 한데, "모프 계산기"로 갈 때는 `selectedSpecies`를 URL에 넣어서 전달하고 있어서 일관성은 OK. 다만 `context.push('/wiki/$selectedSpecies/morph-calc')`에서 종 칩 선택 없이 화면 진입 시 기본값 `leopard-gecko`가 쓰이는데, 이건 의도한 것으로 보임. **실제 문제는 아님.**

### W-06. `pet_detail_screen.dart`의 위키 바로가기가 종 선택 없이 /wiki로만 이동
- **파일:** `lib/features/my_pets/presentation/pet_detail_screen.dart:62`
- **내용:** `context.push('/wiki')` — 해당 개체의 speciesId를 wiki의 `selectedWikiSpeciesProvider`에 설정하지 않는다. 사용자가 펫테일 게코 상세에서 "이 종의 사육 위키 보기"를 눌러도 위키 화면은 기본값(레오파드 게코)을 표시한다.
- **영향:** 사용자 기대와 다른 화면 표시.

### W-07. 검색 화면에서 "상세 정보" 탭해도 위키 종 선택 미연동
- **파일:** `lib/features/search/presentation/search_screen.dart:92`
- **내용:** `context.go('/wiki')` — featured 종의 "상세 정보" 버튼을 눌러도 wiki의 selectedWikiSpeciesProvider가 해당 종으로 바뀌지 않는다. W-06과 동일한 패턴.

### W-08. `_searchQueryProvider`가 SearchScreen 내부 로컬 정의 — 뒤로가기 시 상태 잔존
- **파일:** `lib/features/search/presentation/search_screen.dart:7`
- **내용:** `_searchQueryProvider`가 파일 레벨 private provider라서, SearchScreen을 나갔다 들어와도 이전 검색어가 provider에 남아있다. 다만 TextField의 controller는 새로 생성되므로 **UI에는 빈 칸이 보이지만 provider에는 값이 남아** 결과 리스트가 잠깐 표시될 수 있다.

### W-09. `CareInfoRepository` — provider로 생성하지만 매번 새 인스턴스
- **파일:** `lib/features/wiki/data/care_info_repository.dart:7-9`
- **내용:** `careInfoRepositoryProvider`가 `Provider<CareInfoRepository>((ref) => CareInfoRepository())`로 정의되어 있다. Riverpod의 `Provider`는 lazy singleton이라 실제로는 한 번만 생성되므로 큰 문제는 아니지만, **인스턴스 캐시(`_cache`, `_morphCache`)가 Provider 생명주기에 묶여 있어** hot restart 없이는 오래된 캐시가 남을 수 있다. Phase 0에서는 번들 데이터라 문제 없지만, Phase 2에서 서버 데이터로 전환 시 캐시 무효화 전략 필요.

---

## 🔵 참고 (Dead code/개선 제안)

### I-01. Dead code: `features/morph_calc/` 전체 패키지
- **파일:** `lib/features/morph_calc/` (data, domain, presentation 3개 파일)
- **내용:** 라우터에서 참조하는 `MorphCalcScreen`은 `wiki/presentation/morph_calc_screen.dart`이다. `features/morph_calc/` 패키지는 라우터에 등록되지 않았고, 어디에서도 import하지 않는다. 내부 데이터도 `leo-gecko`(ID 불일치 — 실제는 `leopard-gecko`)를 사용하는 등 **이전 프로토타입 잔재**로 보인다.
- **영향:** 패키지 전체 삭제 가능.

### I-02. Dead code: `features/species_detail/` 전체 패키지
- **파일:** `lib/features/species_detail/` (4개 파일)
- **내용:** `SpeciesDetailScreen`, `CareInfoCard`(species_detail 버전), `DdayBanner`, `species_detail_providers.dart` — 라우터에 등록되지 않았고, 다른 파일에서 import하지 않는다. `SpeciesCard`가 `/species/:id`로 push하지만 해당 라우트도 없다.
- **영향:** 패키지 전체 삭제 가능.

### I-03. Dead code: `features/home/presentation/popular_searches.dart`
- **파일:** `lib/features/home/presentation/popular_searches.dart:11`
- **내용:** `popularSearchesProvider`를 watch하지만 이 provider는 `home_providers.dart`에 정의되어 있지 않다 (검색해도 없음). 컴파일 에러 대상이거나, 어딘가 숨어 있거나, 사용하지 않는 위젯이다. HomeScreen에서 이 위젯을 사용하지 않는다.

### I-04. Dead code: `features/home/presentation/species_card.dart`, `category_chips.dart`
- **파일:** 해당 2개 파일
- **내용:** HomeScreen이나 다른 화면에서 사용하지 않는다. 이전 디자인의 잔재.

### I-05. Dead code: `features/home/domain/care_info.dart`
- **파일:** `lib/features/home/domain/care_info.dart`
- **내용:** `CareInfo` 클래스 — wiki 쪽에서는 `CareInfoDetail`을 사용한다. `care_info_card.dart`(species_detail 내)에서만 참조하는데, 그것도 dead code(I-02). 이 모델은 `humidity`를 `int` 단일값으로 갖는 등 JSON 구조와 맞지 않다.

### I-06. Dead code: `features/guide/domain/guide_step.dart`
- **파일:** `lib/features/guide/domain/guide_step.dart`
- **내용:** `GuideStep` 클래스가 여기와 `guide_data.dart` 양쪽에 정의되어 있다. `guide_repository.dart`만 이 파일을 import하는데, guide_repository 자체가 dead code(W-04).

### I-07. `shared/providers/connectivity_provider.dart`, `shared/widgets/legal_badge.dart`, `core/error/app_exception.dart` — 미사용 또는 스텁
- **파일:** 해당 3개 파일
- **내용:** `connectivityProvider`는 항상 true를 반환하는 스텁. `LegalBadge`는 `species_card.dart`(dead code)에서만 사용. `AppException` 계열은 아무 곳에서도 throw/catch하지 않는다. Phase 0 스텁이므로 급하지 않지만 정리 대상.

---

## 구조 요약

| 카테고리 | 사용 중 | Dead code |
|---------|--------|-----------|
| features/home | home_screen.dart, home_providers.dart, species_repository.dart, species.dart | care_info.dart, species_card.dart, category_chips.dart, popular_searches.dart |
| features/wiki | 전체 사용 중 | — |
| features/my_pets | 전체 사용 중 | — |
| features/guide | guide_screen.dart, guide_data.dart (도메인), guide_providers.dart | guide_repository.dart, guide_step.dart (domain) |
| features/search | 사용 중 | — |
| features/morph_calc | — | **전체** |
| features/species_detail | — | **전체** |
| features/splash | 사용 중 | — |
| features/error | 사용 중 | — |
| shared/ | — | connectivity_provider.dart, legal_badge.dart |
| core/error | — | app_exception.dart (스텁) |

## 우선순위 권장

1. **즉시 수정** (S-01, S-04): guideDataProvider 이중 정의 제거, HomeScreen에서 petListProvider 사용
2. **빠른 수정** (S-05, W-01, W-06, W-07): 체중 입력 검증, D-day 만료 처리, 위키 종 연동
3. **정리** (I-01~I-07): Dead code 일괄 삭제 — 코드베이스 40% 가량 정리됨
4. **개선** (W-02, W-04): D-day SOT 단일화, GuideRepository 삭제
