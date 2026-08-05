# 개체↔사육장 배정 — Flutter 구현 계획 (2026-08-06)

> **구현 방식 (CAOF):** Standard 트랙. 메인이 분석 → 합의 → 직접 구현. Steps use checkbox (`- [ ]`).

**Goal:** 사용자가 개체를 사육장 세트에 배정/해제할 수 있게 하고, 그 배정이 서버에 영속되어 동기화 후에도 보존되게 한다.

**Architecture:** 배정 쓰기는 **`assign_pet_to_enclosure` RPC 1회**가 유일한 경로다. 앱은 `pets` 테이블을 직접 UPDATE하지 않고, 1:1 보정 로직도 갖지 않는다(둘 다 DB가 강제). 읽기는 `syncFromRemote()`가 `enclosure_id`를 Hive로 복원한다.

**Tech Stack:** Flutter · Riverpod 2 · Supabase(RPC) · Hive

---

## 0. 선행 조건 (착수 게이트)

**아래가 전부 충족되기 전에는 F1을 시작하지 않는다.**

- [ ] 백엔드 핸드오프 [`docs/backend-handoff-pet-enclosure-link.md`](../backend-handoff-pet-enclosure-link.md) §3 마이그레이션이 **petcam-lab에서** 적용 완료
- [ ] 같은 문서 §4 검증 전부 합격 + §8 회신 항목 수령
- [ ] `assign_pet_to_enclosure`에 `authenticated` EXECUTE 권한 확인

> **이 세션(tera-ai-flutter)은 DB/Supabase를 직접 수정하거나 마이그레이션을 적용하지 않는다.** 스키마 조회(read-only)만 한다. 컬럼이 없으면 F1~F4를 구현하되 **flag off로 비활성 상태 유지**한다.

### 현재 Git 상태 (2026-08-06 실측)

| 항목 | 값 |
|---|---|
| 브랜치 | `feat/prd-redesign` (upstream **없음**, 미푸시) |
| HEAD | `8d5d75a` |
| `Pet.enclosureId`(`@HiveField(13)`) | 커밋 `31420444` — **로컬 브랜치에만 존재** |
| `origin/main` 포함 여부 | **NO** |

→ 앱 필드는 이미 있지만 **공유되지 않은 상태**다. 이 계획은 그 위에 이어서 쌓는다.

---

## 1. 설계 결정과 근거

### 1-1. `updatePet()`과 배정을 분리한다

`updatePet()`의 payload에 `enclosure_id`를 넣으면 **개체 이름만 고쳐도 배정이 함께 덮어써진다.** 화면 A(개체 편집)의 stale 값이 화면 B(배정)의 결과를 지우는 전형적인 사고다.

| 메서드 | `enclosure_id` 취급 |
|---|---|
| `addPet()` | **보내지 않음.** 신규 개체는 항상 미배정으로 시작 |
| `updatePet()` | **보내지 않음.** 일반 편집은 배정을 건드리지 않는다 |
| `assignPetToEnclosure()` | **유일한 쓰기 경로.** RPC 호출 |
| `syncFromRemote()` | **읽어서 Hive로 복원** (현재 누락 — 소실의 근본 원인) |

### 1-2. 실패 전에 Hive를 먼저 바꾸지 않는다

낙관적 갱신(먼저 로컬 반영 → 실패 시 되돌리기)을 쓰지 않는다. 되돌리기 자체가 실패하면 로컬과 서버가 영구히 어긋나고, 사용자는 "배정됐다"고 믿는다.

**순서 고정: RPC 성공 → `syncFromRemote()` → Hive 갱신.** RPC가 던지면 Hive는 손대지 않은 채 예외가 UI까지 올라간다.

### 1-3. 1:1 보정을 앱에서 하지 않는다

DB가 부분 UNIQUE로 강제하고 RPC가 원자적으로 교체한다. 앱이 "기존 해제 후 배정" 같은 다단계 보정을 하면 DB 제약과 이중으로 싸우고, 중간 실패 시 상태가 갈린다.

### 1-4. Feature flag

`kPetEnclosureAssignmentEnabled` 상수로 UI 노출을 제어한다. 배포 순서상 **DB 검증 완료 후 별도 단계**에서 켠다(핸드오프 §6-4).

---

## 2. 파일 구조

```
lib/features/my_pets/data/supabase_pet_repository.dart   # F1,F2 — sync 복원 + RPC seam
lib/features/my_pets/presentation/pet_assignment_providers.dart  # F3 — 배정 notifier
lib/features/my_cage/presentation/enclosure_settings_screen.dart # F4 — 배정 섹션
assets/l10n/ko.json                                      # F4 — 문자열
test/features/my_pets/pet_assignment_test.dart           # F1,F2 테스트
```

---

## Task F1: `syncFromRemote()`가 `enclosure_id`를 복원

**Context:**
- Depends on: 선행 조건 §0 (DB 컬럼 존재)
- Inputs: `SupabasePetRepository`(`lib/features/my_pets/data/supabase_pet_repository.dart:74-107`)
- Outputs: sync 왕복 후에도 `Pet.enclosureId`가 보존됨
- Must know: `syncFromRemote()`는 `_cacheBox.clear()` 후 서버 행으로 **재구성**한다. 여기서 `enclosureId`를 빼먹으면 배정이 조용히 사라진다 — 이게 이 작업 전체의 근본 원인이다. `addPet`/`updatePet`의 payload에는 **넣지 않는다**(§1-1).
- Acceptance: `flutter test test/features/my_pets/pet_assignment_test.dart` 통과

**Files:**
- Modify: `lib/features/my_pets/data/supabase_pet_repository.dart`
- Test: `test/features/my_pets/pet_assignment_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/features/my_pets/pet_assignment_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_pets/data/supabase_pet_repository.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

void main() {
  group('petFromRow — 서버 행 → Pet 매핑', () {
    test('enclosure_id를 복원한다 (sync 왕복 보존의 핵심)', () {
      final p = petFromRow({
        'id': 'pet-1',
        'name': '젤리',
        'species_id': 'crested_gecko',
        'species_name': '크레스티드 게코',
        'sex': 'unknown',
        'enclosure_id': 'enc-1',
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-05T00:00:00Z',
      });
      expect(p.enclosureId, 'enc-1');
    });

    test('enclosure_id가 null이면 미배정', () {
      final p = petFromRow({
        'id': 'pet-1',
        'name': '젤리',
        'species_id': 'crested_gecko',
        'species_name': '크레스티드 게코',
        'enclosure_id': null,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-05T00:00:00Z',
      });
      expect(p.enclosureId, isNull);
    });

    test('컬럼 자체가 없어도 죽지 않는다 (마이그레이션 전 구버전 서버)', () {
      final p = petFromRow({
        'id': 'pet-1',
        'name': '젤리',
        'species_id': 'crested_gecko',
        'species_name': '크레스티드 게코',
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-05T00:00:00Z',
      });
      expect(p.enclosureId, isNull);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

```bash
flutter test test/features/my_pets/pet_assignment_test.dart
```

Expected: FAIL — `petFromRow` 미정의

- [ ] **Step 3: 매핑 함수를 추출하고 `enclosure_id` 복원 추가**

`supabase_pet_repository.dart`의 `syncFromRemote()` 안 인라인 `Pet(...)` 생성을 최상위 함수로 뽑는다 (테스트 가능하게 + 재사용):

```dart
/// 서버 `pets` 행 → [Pet].
///
/// `enclosure_id` 복원이 핵심이다. [SupabasePetRepository.syncFromRemote]는
/// Hive box를 clear한 뒤 서버 행으로 재구성하므로, 여기서 빠뜨리면 배정이
/// 동기화 한 번에 조용히 사라진다.
/// 마이그레이션 전 서버(컬럼 없음)에서도 죽지 않도록 없으면 null로 둔다.
Pet petFromRow(Map<String, dynamic> row) {
  return Pet(
    id: row['id'] as String,
    name: row['name'] as String,
    speciesId: (row['species_id'] as String?) ?? 'custom',
    speciesName: row['species_name'] as String,
    morph: row['morph'] as String?,
    sex: (row['sex'] as String?) ?? 'unknown',
    birthDate: row['birth_date'] != null
        ? DateTime.tryParse(row['birth_date'] as String)
        : null,
    adoptionDate: row['adoption_date'] != null
        ? DateTime.tryParse(row['adoption_date'] as String)
        : null,
    weight: (row['weight'] as num?)?.toDouble(),
    photoPath: row['avatar_url'] as String?,
    memo: row['memo'] as String?,
    enclosureId: row['enclosure_id'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
```

그리고 `syncFromRemote()` 루프를 교체:

```dart
    await _cacheBox.clear();
    for (final row in data) {
      final pet = petFromRow(Map<String, dynamic>.from(row as Map));
      await _cacheBox.put(pet.id, pet);
    }
```

`addPet`/`updatePet`의 payload는 **건드리지 않는다** — 배정은 RPC 전용(§1-1).

- [ ] **Step 4: 통과 확인**

```bash
flutter test test/features/my_pets/pet_assignment_test.dart && flutter analyze
```

Expected: `All tests passed!` (3 tests) + 에러 0

---

## Task F2: `assignPetToEnclosure()` — RPC 1회 + 성공 후 재동기화

**Context:**
- Depends on: F1
- Inputs: `assign_pet_to_enclosure(p_pet_id uuid, p_enclosure_id uuid)` RPC
- Outputs: `SupabasePetRepository.assignPetToEnclosure(petId, enclosureId)` + 주입 가능한 RPC seam
- Must know: **실패 시 Hive를 건드리면 안 된다**(§1-2). RPC가 던지면 그대로 전파하고 로컬은 이전 상태를 유지한다. 성공 시에만 `syncFromRemote()`로 서버 진실을 다시 내려받는다 — RPC가 다른 개체의 배정도 해제했을 수 있어(1:1 교체) 대상 1건만 로컬 수정하면 **다른 개체가 배정된 채로 남는다**. 테스트를 위해 RPC 호출은 함수 주입 seam으로 분리한다(`MotionClipRepository.ActivityRowsLoader`와 동일 관례).
- Acceptance: 아래 테스트 4종 통과

**Files:**
- Modify: `lib/features/my_pets/data/supabase_pet_repository.dart`
- Test: `test/features/my_pets/pet_assignment_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

```dart
// test/features/my_pets/pet_assignment_test.dart 에 추가
import 'package:tera_ai/features/my_pets/data/pet_assignment_service.dart';

class _FakeSync {
  int calls = 0;
  Future<void> call() async => calls++;
}

void main() {
  // …F1 그룹 아래에 추가
  group('PetAssignmentService.assign', () {
    test('RPC를 정확히 1번 호출한다 (UPDATE 다단계 금지)', () async {
      final calls = <Map<String, String?>>[];
      final sync = _FakeSync();
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          calls.add({'pet': petId, 'enc': enclosureId});
        },
        resync: sync.call,
      );

      await svc.assign(petId: 'pet-1', enclosureId: 'enc-1');

      expect(calls, [
        {'pet': 'pet-1', 'enc': 'enc-1'}
      ]);
    });

    test('성공하면 서버에서 재동기화한다', () async {
      final sync = _FakeSync();
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {},
        resync: sync.call,
      );

      await svc.assign(petId: 'pet-1', enclosureId: 'enc-1');

      expect(sync.calls, 1);
    });

    test('RPC가 실패하면 재동기화하지 않고 예외를 전파한다 — 로컬 선반영 금지',
        () async {
      final sync = _FakeSync();
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          throw StateError('ownership mismatch');
        },
        resync: sync.call,
      );

      await expectLater(
        svc.assign(petId: 'pet-1', enclosureId: 'enc-1'),
        throwsStateError,
      );
      expect(sync.calls, 0);
    });

    test('해제는 enclosureId=null 로 같은 RPC를 쓴다', () async {
      final calls = <String?>[];
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          calls.add(enclosureId);
        },
        resync: () async {},
      );

      await svc.assign(petId: 'pet-1', enclosureId: null);

      expect(calls, [null]);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

```bash
flutter test test/features/my_pets/pet_assignment_test.dart
```

Expected: FAIL — `pet_assignment_service.dart` 미존재

- [ ] **Step 3: 서비스 작성**

```dart
// lib/features/my_pets/data/pet_assignment_service.dart

/// 배정 RPC 호출 seam. 테스트가 네트워크 없이 주입할 수 있게 분리한다
/// (`MotionClipRepository`의 ActivityRowsLoader와 같은 관례).
typedef AssignPetRpc = Future<void> Function({
  required String petId,
  required String? enclosureId,
});

/// 개체↔사육장 배정.
///
/// **쓰기 경로는 RPC 하나뿐이다.** 앱이 `pets`를 직접 UPDATE하거나 1:1 보정을
/// 다단계로 흉내내지 않는다 — 1:1은 부분 UNIQUE 인덱스가, 원자적 교체는 RPC가
/// 보장한다.
///
/// **실패 전에 로컬을 먼저 바꾸지 않는다.** 낙관적 갱신 후 되돌리기는 되돌리기
/// 자체가 실패하면 로컬·서버가 영구히 어긋난다. RPC 성공 → 재동기화 순서를
/// 고정한다.
class PetAssignmentService {
  final AssignPetRpc _rpc;
  final Future<void> Function() _resync;

  PetAssignmentService({
    required AssignPetRpc rpc,
    required Future<void> Function() resync,
  })  : _rpc = rpc,
        _resync = resync;

  /// [enclosureId]가 null이면 배정 해제.
  ///
  /// 성공 후 전체 재동기화하는 이유: RPC가 1:1 유지를 위해 **다른 개체의
  /// 배정도 해제**했을 수 있다. 대상 1건만 로컬 반영하면 이전 점유 개체가
  /// 배정된 채로 남아 화면에 두 개체가 같은 사육장에 보인다.
  Future<void> assign({
    required String petId,
    required String? enclosureId,
  }) async {
    await _rpc(petId: petId, enclosureId: enclosureId);
    await _resync();
  }
}
```

`SupabasePetRepository`에 기본 배선을 추가한다:

```dart
  /// 기본 RPC 배선. 서버 예외(소유권 불일치·1:1 위반 등)는 그대로 전파한다.
  Future<void> assignPetToEnclosure({
    required String petId,
    required String? enclosureId,
  }) {
    return PetAssignmentService(
      rpc: ({required petId, required enclosureId}) async {
        await _client.rpc('assign_pet_to_enclosure', params: {
          'p_pet_id': petId,
          'p_enclosure_id': enclosureId,
        });
      },
      resync: syncFromRemote,
    ).assign(petId: petId, enclosureId: enclosureId);
  }
```

- [ ] **Step 4: 통과 확인**

```bash
flutter test test/features/my_pets/pet_assignment_test.dart && flutter analyze
```

Expected: `All tests passed!` (7 tests) + 에러 0

---

## Task F3: providers — 배정 후 세트 목록 갱신

**Context:**
- Depends on: F2
- Inputs: `enclosureSetsProvider`(`lib/features/home/presentation/home_set_providers.dart`)
- Outputs: `petAssignmentControllerProvider` — 배정 실행 + 관련 provider invalidate
- Must know: 배정이 끝나면 `enclosureSetsProvider`를 invalidate해야 홈 헤더가 `테스트` → `젤리 (테스트)`로 즉시 바뀐다. `petListProvider`도 같이 무효화한다(마이 크레 탭의 개체 목록이 배정 상태를 보여줄 경우 대비). **`ref.read`는 콜백에서, `ref.watch`는 build에서**(프로젝트 규칙).
- Acceptance: `flutter analyze` 에러 0 + F4 실기기 확인

**Files:**
- Create: `lib/features/my_pets/presentation/pet_assignment_providers.dart`

- [ ] **Step 1: provider 작성**

```dart
// lib/features/my_pets/presentation/pet_assignment_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/home_set_providers.dart';
import 'my_pets_providers.dart';

/// 배정 UI 노출 스위치.
///
/// DB 마이그레이션 + 검증이 끝난 뒤 별도 단계에서 켠다
/// (`docs/backend-handoff-pet-enclosure-link.md` §6-4).
/// 컬럼이 없는 서버에 RPC를 호출하면 예외만 나므로 기본은 off.
const bool kPetEnclosureAssignmentEnabled = false;

class PetAssignmentController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [enclosureId]가 null이면 해제.
  /// 서버 예외는 그대로 올려보내 화면이 사용자에게 사유를 보여주게 한다.
  Future<void> assign({
    required String petId,
    required String? enclosureId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabasePetRepositoryProvider)
          .assignPetToEnclosure(petId: petId, enclosureId: enclosureId);
      // 세트 조합이 바뀌었으니 홈 헤더·상단 영역이 다시 계산돼야 한다.
      ref.invalidate(enclosureSetsProvider);
      ref.invalidate(petListProvider);
    });
    if (state.hasError) {
      throw state.error!;
    }
  }
}

final petAssignmentControllerProvider =
    AutoDisposeAsyncNotifierProvider<PetAssignmentController, void>(
  PetAssignmentController.new,
);
```

> **확인 필요:** `supabasePetRepositoryProvider` / `petListProvider`의 실제 이름을 `lib/features/my_pets/presentation/my_pets_providers.dart`에서 확인하고 맞춘다. 다르면 이 파일의 참조만 교체한다(로직 동일).

- [ ] **Step 2: 분석 통과 확인**

```bash
flutter analyze
```

Expected: 에러 0

---

## Task F4: 배정 UI — 사육장 설정 화면

**Context:**
- Depends on: F3
- Inputs: `enclosure_settings_screen.dart`, `enclosureSetsProvider`, `petListProvider`
- Outputs: 사육장별 현재 개체 표시 + 개체 선택/해제 시트
- Must know: `kPetEnclosureAssignmentEnabled`가 false면 섹션 자체를 렌더하지 않는다. 서버가 던지는 예외 메시지(소유권 불일치, 1:1 위반)는 **그대로 노출하지 말고** 사용자 언어로 매핑한다 — Postgres 에러 문자열은 사용자에게 의미가 없다. 이미 다른 사육장에 배정된 개체를 고르면 "교체됩니다" 확인을 받는다(RPC가 조용히 교체하므로 사용자가 모르면 안 된다).
- Acceptance: 실기기에서 배정 → 홈 헤더가 `젤리 (테스트)`로 변경 확인

**Files:**
- Modify: `lib/features/my_cage/presentation/enclosure_settings_screen.dart`
- Modify: `assets/l10n/ko.json`

- [ ] **Step 1: i18n 키 추가**

```json
  "enclosure_settings_assignment": "개체 배정",
  "enclosure_settings_no_pet": "배정된 개체 없음",
  "enclosure_settings_pick_pet": "개체 선택",
  "enclosure_settings_unassign": "배정 해제",
  "enclosure_settings_swap_title": "개체를 교체할까요?",
  "enclosure_settings_swap_body": "{}은(는) 현재 {}에 배정돼 있어요. 이 사육장으로 옮기면 기존 배정은 해제됩니다.",
  "enclosure_settings_assign_failed": "배정에 실패했어요. 잠시 후 다시 시도해주세요.",
  "enclosure_settings_assign_denied": "본인 소유의 사육장·개체만 배정할 수 있어요.",
```

- [ ] **Step 2: 배정 섹션 추가**

`EnclosureSettingsScreen`의 `ListView` 상단에 삽입:

```dart
        if (kPetEnclosureAssignmentEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppStyles.spacing16, AppStyles.spacing16, AppStyles.spacing16, 0),
            child: SectionHeader(title: 'enclosure_settings_assignment'.tr()),
          ),
          const _AssignmentSection(),
          const Divider(),
        ],
```

`_AssignmentSection`은 `enclosureSetsProvider`를 watch해 사육장별로 한 줄씩 그리고, 탭하면 개체 선택 시트를 연다. 선택 결과를 `petAssignmentControllerProvider.assign()`에 넘긴다. 이미 다른 사육장에 배정된 개체를 고르면 `enclosure_settings_swap_*` 확인 다이얼로그를 먼저 띄운다.

> 위젯 상세 코드는 F3에서 provider 실제 이름을 확정한 뒤 작성한다. 이 Task는 **DB 검증 완료 후**에 착수하므로, 그 시점에 이 문단을 실제 코드로 교체한다.

- [ ] **Step 3: flag on + 실기기 확인**

```bash
flutter analyze && flutter test && flutter build ios --simulator --debug
```

확인 항목:
- 배정 → 홈 헤더 `테스트` → `젤리 (테스트)`
- 다른 사육장에 배정된 개체 선택 → 교체 확인 다이얼로그
- 해제 → 헤더가 사육장명만으로 복귀
- 앱 재시작(콜드 스타트) 후에도 배정 유지 ← **sync 왕복 보존 검증**

---

## 3. 테스트 가능성 자체 검토

각 계약이 **실제로 검증 가능한지** 점검했다.

| 계약 | 검증 방법 | 자동화 |
|---|---|---|
| sync 왕복에서 `enclosure_id` 보존 | `petFromRow` 단위 테스트 3종 | ✅ F1 |
| 컬럼 없는 서버에서도 안 죽음 | `enclosure_id` 키 누락 케이스 | ✅ F1 |
| RPC 정확히 1회 호출 | fake rpc가 호출 인자 기록 | ✅ F2 |
| 성공 시에만 재동기화 | fake sync 호출 횟수 | ✅ F2 |
| **실패 시 로컬 미변경** | rpc throw → resync 0회 + 예외 전파 | ✅ F2 |
| 해제가 같은 RPC 경로 | `enclosureId: null` 인자 확인 | ✅ F2 |
| 배정 후 홈 헤더 갱신 | provider invalidate → 위젯 | ⚠️ 실기기 (F4) |
| 콜드 스타트 후 배정 유지 | 앱 재시작 후 헤더 확인 | ⚠️ 실기기 (F4) |
| 1:1 강제 | **DB 책임** — 앱 테스트 대상 아님 | 백엔드 §4-4(B) |
| 소유권 검증 | **DB 책임** — 앱은 예외 표시만 | 백엔드 §4-4(C) |

**자동화 못 하는 2건**(실기기 확인)은 위젯 테스트로 대체하지 않았다. `enclosureSetsProvider`가 Supabase 3-테이블 조합에 의존해 목킹 비용이 실익을 넘고, 콜드 스타트 보존은 정의상 프로세스 재시작이 필요하다. F4 체크리스트로 명시해 누락을 막는다.

---

## 4. 이 계획이 다루지 않는 것

- **DB 마이그레이션 적용** — petcam-lab 전담. 이 세션은 조회만.
- 미배정 기기(캠·제어기) 관리 UI — 별건.
- `pets` 다중 소유/공유 시나리오 — PRD 전제가 1:1이라 범위 밖.
- 백엔드 선행과제 BE1~BE5(`telemetry_5m`, `relay_pulse`, LED brightness, `device_timers`, `behavior_logs` RLS) — 사용자 지시로 이번 라운드 제외.
