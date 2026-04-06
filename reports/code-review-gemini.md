제시해주신 Tera AI Flutter 프로젝트 코드에 대한 상세 리뷰 결과입니다. 검수 기준에 따라 발견된 이슈들을 정리하였습니다.

---

## 1. 수치 및 날짜 불일치 (Numerical/Date Mismatch)

*   **`lib/features/home/presentation/home_screen.dart:18`**: 자진신고 마감일(`2026, 6, 13`)이 하드코딩되어 있습니다. `AppConstants.registrationDeadline`이 이미 정의되어 있음에도 이를 사용하지 않아, 상수 값이 변경될 경우 홈 화면의 D-day 계산만 틀려질 위험이 있습니다.
*   **`lib/features/guide/domain/guide_data.dart:136`**: `GuideData`는 JSON에서 날짜를 파싱(`DateTime.parse(deadline)`)하여 D-day를 계산합니다. 만약 `assets/data/guide_steps.json` 내의 날짜와 `AppConstants`의 날짜가 다를 경우, 홈 화면과 가이드 화면의 D-day가 다르게 표시되는 치명적인 데이터 불일치가 발생합니다.

## 2. 네이밍 및 상수 비일관성 (Naming Inconsistency)

*   **주요 종(Featured Species) 정의 중복**:
    *   `lib/core/constants/app_constants.dart:12`: `featuredSpeciesIds`
    *   `lib/features/wiki/data/care_info_repository.dart:14`: `featuredSpeciesIds` (중복 정의)
    *   `lib/features/home/data/species_repository.dart:5`: `_featuredSpecies` (객체 리스트로 중복 정의)
    *   **이슈**: 특정 종의 ID가 변경되거나 추가될 때 3곳을 모두 수정해야 합니다. 한 곳(`AppConstants`)으로 관리하고 참조하는 방식이 권장됩니다.
*   **성별 표기 혼용**:
    *   `lib/features/my_pets/domain/pet.dart:67`: `sexDisplay`에서 '♂ 수컷', '♀ 암컷' 사용.
    *   `lib/features/my_pets/domain/pet.dart:5`: 주석에는 `male, female, unknown`으로 명시.
    *   **이슈**: 데이터 레이어(Hive)와 UI 레이어 간의 성별 문자열 값이 일관되지 않을 경우 `switch` 문에서 `default`로 빠질 위험이 있습니다.

## 3. 패턴 위반 (Pattern Violations)

*   **Riverpod 반응성 누락 (Critical)**:
    *   **`lib/features/home/presentation/home_screen.dart:13-16`**: `petRepo.getAllPets()`를 `build` 메서드 내에서 직접 호출하고 있습니다. 
    *   **이슈**: `petRepo`는 단순히 저장소 인스턴스일 뿐입니다. 새로운 개체가 등록되거나 삭제되어도 `HomeScreen`은 이를 감지하지 못하고 리빌드되지 않습니다. `ref.watch(petListProvider)`를 사용하여 리스트를 구독해야 합니다.
*   **Localization 패턴 미준수**:
    *   **`lib/core/router/app_router.dart:123-138`**: `NavigationBar`의 라벨('홈', '사육 위키' 등)이 한국어 생문자열로 하드코딩되어 있습니다.
    *   **이슈**: `main.dart`에서 `EasyLocalization`을 설정했음에도 불구하고 라벨에 `.tr()`을 적용하지 않아 다국어 대응이 불가능합니다.
*   **Hard-coded Context Navigation**:
    *   **`lib/features/home/presentation/home_screen.dart:50`**: 가이드 섹션 클릭 시 `context.go('/wiki')`로 이동하도록 되어 있는데, 코드의 맥락상 위키가 아닌 `/home` 내부의 가이드나 특정 종 상세로 가야 할 것으로 보입니다. (비즈니스 로직 확인 필요)

## 4. 누락 (Omissions) 및 잠재적 에러

*   **JSON 파싱 예외 처리 부족**:
    *   **`lib/features/wiki/domain/care_info_detail.dart:132-135`**: `common_mistakes`와 `sources` 필드 파싱 시 `null` 체크나 기본값 처리가 없습니다. JSON 데이터에 해당 키가 누락되어 있을 경우 앱이 크래시될 수 있습니다. (다른 필드들처럼 `?.map(...)?.toList() ?? []` 패턴 권장)
*   **성별 아이콘 누락**:
    *   **`lib/features/my_pets/domain/pet.dart:82`**: `sexIcon` 메서드에서 `male`, `female` 외의 경우 `?`를 반환하는데, UI에서는 성별 미확인 개체에 대한 처리가 모호할 수 있습니다.
*   **무게 데이터 동기화**:
    *   **`lib/features/my_pets/domain/pet.dart:28`**: `Pet` 클래스에 `weight` 필드가 있는데, 별도의 `WeightLog` 저장소(`pet_repository.dart:73`)가 존재합니다. 
    *   **이슈**: 최신 무게가 `WeightLog`에 추가되었을 때 `Pet` 객체의 `weight` 필드도 업데이트되는지, 아니면 `weight` 필드가 중복 데이터(Dead field)인지 명확하지 않습니다.

## 5. Dead Code (사용되지 않는 코드)

*   **`lib/core/constants/app_constants.dart:4-9`**: `categories` ('도마뱀', '뱀' 등) 상수가 정의되어 있으나, `SpeciesRepository`에서는 이를 참조하지 않고 자체적인 문자열 리터럴을 사용하고 있습니다.
*   **`lib/features/wiki/data/care_info_repository.dart:19-23`**: `speciesNames` 맵은 정의되어 있으나 클래스 내에서 전혀 사용되지 않고 있습니다. (Wiki 화면에서는 `CareInfoDetail` 객체의 `speciesNameKo`를 사용함)
*   **`lib/features/home/data/species_repository.dart:36`**: `_otherSpecies` 리스트에 정의된 종들 중 다수가 현재 UI 상에서 도달할 방법이 없거나(상세 페이지 부재), 단순 검색 결과로만 노출됩니다.
*   **`lib/features/guide/domain/guide_data.dart:150`**: `isInGracePeriod` 게터는 정의되어 있으나 UI(`guide_screen.dart`)에서 사용되지 않고 있습니다.

---

### **종합 권고 사항:**
1.  `AppConstants`에 날짜 및 주요 종 ID를 **단일 소스(Single Source of Truth)**로 몰아넣고 다른 파일에서 이를 참조하십시오.
2.  `HomeScreen`에서 `petRepositoryProvider` 직접 호출을 중단하고 `petListProvider`를 `watch` 하십시오.
3.  JSON 파싱(`fromJson`) 시 모든 리스트 타입에 대해 `?? []` 처리를 하여 데이터 누락 시의 안정성을 확보하십시오.
4.  D-day 계산 로직을 `AppConstants` 혹은 전용 유틸리티 함수로 통합하여 화면 간 수치 불일치를 방지하십시오.
