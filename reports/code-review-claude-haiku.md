# Claude Haiku 직감 검수

## 동작 판정: Yes — Riverpod 상태 관리와 라우팅이 정상 구성되어 있고, 화면 단계별 흐름이 의도대로 동작할 것으로 보임

## 가장 약한 부분: lib/features/my_pets/presentation/pet_edit_screen.dart:213
**문제**: `_initFromPet(pet)` 메서드를 매 build 마다 호출하면서 `_initialized` 플래그로 방어하는 방식이 위험함.
- `ref.watch(petDetailProvider)` → `pet` 가져오기 → `_initFromPet(pet)` 호출
- 만약 `pet` 객체가 UI 갱신 후 다시 변경되어 전달되면, 이미 사용자가 입력한 controller 값을 덮어쓸 수 있음
- 더 안전한 방식: initState에서 한 번만 호출하거나, `didUpdateWidget` 사용

## 누락된 방어 코드
1. **pet_detail_screen.dart:27-31** — `pet == null` 체크 후 앱바 생성만 함. 스캐폴드 없이 appBar 반환 가능성 (애매한 에러 상황)
2. **home_screen.dart:14** — `petRepo.getAllPets()` 호출 시 반환값 null 체크 없음. pets가 빈 리스트면 문제없지만, 리포지토리 예외 발생 시 미처리
3. **guide_screen.dart:35-36** — 에러 화면에서 `err` 객체 그대로 문자열로 표시. 사용자 관점에서 이해 불가능한 오류 메시지
4. **pet_detail_screen.dart:106** — `context.mounted` 확인만 하는데, 앞의 `showDialog` 후 미세한 시간차에서 context 변경 가능성 (극히 드물지만)
5. **pet_add_screen.dart:145** — `context.push('/my-pets/add')` 성공 후 `context.pop()`할 때, 라우팅 스택 상태 미확인

## 최우선 수정: pet_edit_screen.dart의 `_initFromPet()` 호출 위치 변경
- **현재**: `build()` 내에서 매번 호출 (플래그로만 방어)
- **권장**: initState에서 한 번만 호출, 또는 `pet` 객체 변경 감지 시에만 갱신하도록 수정
```dart
@override
void initState() {
  super.initState();
  _nameController = TextEditingController();
  // ... 다른 controller 초기화
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final pet = ref.watch(petDetailProvider(widget.petId));
    if (pet != null && !_initialized) {
      _initFromPet(pet);
    }
  });
}
```

## "왜 있지?" 코드
1. **home_screen.dart:52** — `'사육 가이드'` 카드들을 탭하면 `context.go('/wiki')`로 이동. 
   - 현재 동작: 위키 탭으로 가기만 함 (특정 종을 선택하지 않음)
   - 의도 추측: 홈의 featured species 카드를 클릭하면 그 종의 위키로 바로 가는 게 자연스러울 것 같은데, 현재는 일반 위키로만 이동
   - 개선 제안: `context.go('/wiki')`가 아니라 `context.go('/wiki?species=$speciesId')` 또는 WikiScreen에서 featured species 중 하나를 기본 선택

2. **pet_add_screen.dart & pet_edit_screen.dart** — 동일한 모프 목록 하드코딩 (2곳에 중복)
   - 모프 데이터를 별도 파일로 분리하면 DRY 원칙 위반 제거 가능
   - 예: `lib/shared/constants/morph_data.dart`

3. **guide_screen.dart:21** — `final Set<int> _checkedDocuments = {};`로 체크 상태 관리하지만, 화면 닫으면 초기화됨
   - 체크 상태를 Hive/SharedPreferences에 저장하는 게 낫지 않을까? (사용자 편의)

4. **wiki_detail_screen.dart:23-25** — 정적 매핑 `_categoryNames`와 실제 카테고리 id 간 미스매치 가능성
   - default 경우 `category` 그대로 반환하는데, 유효하지 않은 카테고리면 UI 어색함

5. **app_router.dart:143** — NavigationBar에서 같은 탭 두 번 탭할 때 `initialLocation: index == navigationShell.currentIndex`
   - 의도가 "현재 탭이면 스택을 초기화하지 말자"인 것 같은데, 로직이 역직관적 (주석 추가 권장)

---

## 종합 평가
- **아키텍처**: Riverpod + GoRouter 조합이 깔끔하고, feature별 폴더 구조가 잘 됨
- **상태 관리**: PetListNotifier, WeightLogsNotifier가 단순하고 명확함
- **UI/UX**: 4탭 네비게이션이 직관적, 입력 폼 검증 충분
- **위험 지점**: pet_edit_screen의 late init 패턴과 null 안전성 몇 곳. 모프 데이터 중복도 개선 여지 있음
