## 소크라테스의 질문들

### 아포리아 지수: 7/10

---

### 산파술적 질문 (답하지 않고 질문만)

**1. 두 개의 세계가 공존하고 있지 않은가?**

`features/species_detail/`, `features/morph_calc/`, `features/home/presentation/species_card.dart`, `features/home/presentation/popular_searches.dart`, `features/home/presentation/category_chips.dart` -- 이 파일들은 `easy_localization`의 `.tr()`을 쓰고, `species_detail_screen.dart`는 라우트 `/species/:id`로 가는데, `app_router.dart`에는 그 라우트가 없거든? 이 파일들이 라우터에서도, 다른 화면에서도 import되지 않는다면, "존재하되 참조되지 않는 코드"는 코드인가 유령인가?

**2. 홈은 petListProvider를 모르는데, 어떻게 개체를 보여주지?**

`home_screen.dart`는 `petRepository.getAllPets()`를 직접 호출하고 있어. 그런데 `my_pets_providers.dart`에는 `petListProvider`라는 StateNotifier가 따로 있거든. 홈이 repository를 직접 읽고, 내 개체 탭이 StateNotifier를 통해 읽는다면 -- pet을 추가한 뒤 홈으로 돌아왔을 때, 홈은 어떻게 새 데이터를 알게 되지? `ConsumerWidget`이 `ref.watch(petRepositoryProvider)`를 하고 있지만, `PetRepository`는 plain `Provider`라 Hive 변경을 알려주지 않잖아. 홈이 리빌드되는 시점이 정확히 언제인지, 혹시 stale 상태로 남아있는 건 아닌지?

**3. "첫 개체 등록하기" 후 어디로 돌아가지?**

`_EmptyPetsSection`에서 `context.go('/my-pets/add')`로 이동하고, `pet_add_screen.dart`의 `_save()`에서 `context.pop()`을 하거든. `/home`에서 `go()`로 `/my-pets/add`로 갔으면 pop하면 `/my-pets`로 가야 하는데, 맞는가? 아니면 사용자 의도는 홈으로 복귀하는 것 아닌가? `StatefulShellRoute`에서 탭 간 `go()`를 쓰면 내 개체 브랜치의 히스토리 스택에 들어가는 건데 -- 사용자가 "홈에서 등록하고 홈으로 돌아가기"를 기대한다면, 이건 사육장 아포리아가 아닌가?

**4. "이 종의 사육 위키 보기"는 정말로 "이 종"을 보여주는가?**

`pet_detail_screen.dart` 62행: `context.push('/wiki')`. 그런데 `selectedWikiSpeciesProvider`의 기본값은 `'leopard-gecko'`야. 내 펫테일 게코 상세에서 위키를 눌렀는데 레오파드 게코 정보가 뜬다면, 이건 "이 종의"라는 라벨이 거짓말을 하고 있는 건 아닌가? `push('/wiki')`가 아니라 `push`하기 전에 `selectedWikiSpeciesProvider`를 pet의 `speciesId`로 설정하거나, query parameter로 전달해야 하지 않는가?

**5. 검색에서 featured 종의 "상세 정보" 버튼도 같은 병이 아닌가?**

`search_screen.dart` 92행: `context.go('/wiki')`. 레오파드 게코를 검색해서 탭하든, 크레스티드를 검색해서 탭하든, 항상 위키 기본값(레오파드)으로 가는 거잖아. 검색 결과가 contextual하지 않다면, 검색 결과 옆의 "상세 정보" 버튼은 무엇을 약속하고 있는 건가?

---

### 사육장 아포리아 (막다른 길)

**A. 홈 → 사육 가이드 카드의 `onTap`이 `/wiki`로만 가는데**

`home_screen.dart` 53행: `onTap: () => context.go('/wiki')`. `featuredSpecies`를 순회하면서 각 종의 카드를 그려놓고, 어떤 종을 탭하든 같은 `/wiki`로 가버려. 레오파드 카드를 탭해도, 펫테일 카드를 탭해도 결과가 같다면 -- 카드를 3개 나눠 그린 의미가 뭐지?

**B. `context.go('/my-pets/add')` vs `context.push('/my-pets/add')`**

홈에서 `go`로 `/my-pets/add`를 호출하면 내 개체 탭의 브랜치로 전환되면서 add 화면이 뜨거든. 이때 bottom nav는 "내 개체" 탭이 선택될 거야. 등록 완료 후 `pop()`하면 `/my-pets` 목록이 보이겠지. 사용자는 홈에서 시작했는데 갑자기 "내 개체" 탭에 서 있게 되는 거야. 이건 의도된 건가 아니면 길을 잃은 건가?

**C. D-day 2026-06-13 하드코딩**

`home_screen.dart` 17행과 `guide_repository.dart` 42행, 둘 다 `DateTime(2026, 6, 13)`을 각각 하드코딩하고 있어. 날짜가 바뀌면 두 군데를 고쳐야 하는데, 하나만 고치면 홈과 가이드의 D-day가 다르게 표시되겠지. 이건 "진실의 원천"이 둘이 되어버린 거 아닌가?

---

### Phase 논파

**I. `easy_localization` -- P0에 필요한가?**

11개 파일이 `.tr()`을 쓰고 있는데, 전부 레거시 파일(`species_detail/`, `morph_calc/(old)`, `popular_searches`, `category_chips` 등)이야. 현재 라우터가 참조하는 화면들(`home_screen`, `wiki_screen`, `my_pets_screen`, `guide_screen`)은 `.tr()`을 안 쓰고 한글 하드코딩이거든. P0가 한국어 전용인데, 레거시가 다국어를 가정하고 있다면 -- 이 두 세계관 중 어느 쪽이 미래인가?

**II. `morph_calc` 이중 구현**

`features/morph_calc/` (old, `easy_localization` 사용)과 `features/wiki/presentation/morph_calc_screen.dart` (new, 라우터에 등록됨)가 공존하고 있어. old는 `MorphRepository`를 쓰고, new는 `CareInfoRepository.getMorphData()`를 쓰거든. 같은 기능의 두 구현이 서로 다른 데이터 소스를 쓰고 있다면, P1에서 모프 계산 로직을 고칠 때 어느 쪽을 손대야 하는지 혼란이 오지 않겠는가?

**III. `speciesId: 'custom'`의 미래**

`pet_add_screen.dart`에서 기타 종을 `speciesId: 'custom'`으로 저장하거든. 근데 `_hasCareInfo()`는 `featuredSpeciesIds.contains(speciesId)`로 체크하고 있어. P1에서 종을 추가 지원할 때, `custom`이라는 단일 ID에 여러 종이 뭉쳐있으면 -- 그때 어떻게 구분하지? `custom`은 "아직 모르겠다"의 의미인가 "영원히 미지원"의 의미인가?

---

### 판정 (질문 형태로)

라우터가 참조하지 않는 파일이 11개 이상 존재하고, 참조되는 화면들 사이의 데이터 흐름에 끊김이 최소 3곳 있는 앱을 -- "연결되어 있다"고 말할 수 있는가?

위키로 가는 모든 경로(`home_screen` 53행, `pet_detail_screen` 62행, `search_screen` 92행)가 종 정보 없이 `/wiki`만 호출하고, `selectedWikiSpeciesProvider`의 기본값에 의존하고 있는 구조에서 -- "맞춤 사육 가이드"라는 앱의 약속이 지켜지고 있는가?

홈 화면이 `petRepository`를 직접 watch하면서 `petListProvider`의 StateNotifier를 우회하고 있는데, 이 두 경로가 언제나 같은 결과를 보장한다고 확신할 수 있는가?

dead code가 codebase의 30% 가까이를 차지하는 상태에서, 다음 개발자(혹은 한 달 뒤의 너)가 "어느 `MorphCalcScreen`을 고쳐야 하지?"라고 묻지 않을 거라고 장담할 수 있는가?
