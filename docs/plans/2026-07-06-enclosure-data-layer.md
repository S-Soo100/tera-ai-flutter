# Enclosure(사육장) 데이터 레이어 — S1 Implementation Plan

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. **Critical 트랙** → 승인 후 Implementer(flutter-dev) 에이전트에 task별 전달(GATE 4). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 크레캠 정공법(`docs/crecam-video-env-fix-plan.md`)의 S1 — 앱에 없던 "사육장(enclosure)" 개념의 **데이터 레이어**(도메인 모델 + Repository + Provider)를 도입한다. UI(S2)·클립/온습도 정합(S3/S4)의 기반.

**Architecture:** 기존 `CameraRepository`/`camerasProvider` 패턴을 그대로 복제한다. 조회는 Supabase 직결(`from('enclosures')`, RLS가 본인 것만 반환), 생성은 직결 `insert`(owner_id=현재 로그인 유저, `commands` insert와 동일 패턴). 목록 Provider는 Realtime 없이 `FutureProvider` + 계정격리 watch(생성 후 `invalidate`로 갱신) — 사육장은 앱에서만/드물게 변경되므로 Stream 구독은 YAGNI.

**Tech Stack:** Flutter · Riverpod(`flutter_riverpod`) · `supabase_flutter` · `flutter_test`

**범위 밖 (다음 단계):** 사육장 생성/배정 UI·라우트(S2), 기기 배정(cameras/devices `enclosure_id` UPDATE, S2), 수정/삭제(update/delete, S2에서 필요 시), 비디오 기록·온습도 배선(S3/S4).

---

## File Structure

| 파일 | 역할 | 책임 |
|------|------|------|
| **Create** `lib/features/my_cage/domain/enclosure.dart` | 도메인 모델 | `enclosures` 행 ↔ `Enclosure` 불변 객체 매핑(`fromJson`) |
| **Create** `test/features/my_cage/enclosure_test.dart` | 단위테스트 | `Enclosure.fromJson` 3케이스(완전/nullable누락/방어) |
| **Create** `lib/features/my_cage/data/enclosure_repository.dart` | Repository | `listAll` / `getById` / `create` — Supabase 직결 |
| **Modify** `lib/features/my_cage/presentation/my_cage_providers.dart` | Provider 배선 | `enclosureRepositoryProvider` + `enclosuresProvider` + `enclosureProvider` 추가 |

**테스트 전략 근거:** 목킹 라이브러리(mocktail/mockito)가 pubspec에 없고, 기존 `CameraRepository`도 무테스트다. Supabase 직결 코드는 목킹 인프라 없이 단위테스트가 불가하므로, **순수 로직인 `fromJson`만 TDD**로 검증하고 Repository/Provider는 기존 관례(무테스트 + `flutter analyze`)를 따른다. 실제 DB 왕복 검증은 S5(통합 검증)에서 수행한다.

**참조 스키마 (`enclosures` 테이블, 실 DB 확인):** `id`(uuid) · `owner_id`(uuid) · `name`(text) · `species`(text, null) · `note`(text, null) · `created_at`(timestamptz) · `updated_at`(timestamptz). RLS: `auth.uid() = owner_id`(본인 것만 SELECT/수정).

---

## Task 1: Enclosure 도메인 모델 (TDD)

**Files:**
- Create: `test/features/my_cage/enclosure_test.dart`
- Create: `lib/features/my_cage/domain/enclosure.dart`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/my_cage/enclosure_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';

void main() {
  group('Enclosure.fromJson', () {
    test('완전한 JSON → 모든 필드 매핑', () {
      final e = Enclosure.fromJson({
        'id': 'enc-1',
        'owner_id': 'user-1',
        'name': '테스트 사육장',
        'species': 'crested_gecko',
        'note': '거실 창가',
        'created_at': '2026-07-06T00:00:00Z',
        'updated_at': '2026-07-06T00:00:00Z',
      });
      expect(e.id, 'enc-1');
      expect(e.name, '테스트 사육장');
      expect(e.species, 'crested_gecko');
      expect(e.note, '거실 창가');
      expect(e.createdAt.isAtSameMomentAs(DateTime.utc(2026, 7, 6)), isTrue);
    });

    test('nullable 필드(species, note) 누락 → null', () {
      final e = Enclosure.fromJson({
        'id': 'enc-2',
        'name': '사육장2',
        'created_at': '2026-07-06T00:00:00Z',
      });
      expect(e.species, isNull);
      expect(e.note, isNull);
    });

    test('필수 필드 누락 → 방어적 기본값', () {
      final e = Enclosure.fromJson(<String, dynamic>{});
      expect(e.id, '');
      expect(e.name, '');
      expect(e.createdAt, isA<DateTime>());
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/my_cage/enclosure_test.dart`
Expected: 컴파일 실패 — `Error: Couldn't resolve the package 'enclosure.dart'` / `Enclosure` 정의 없음.

- [ ] **Step 3: 최소 구현**

`lib/features/my_cage/domain/enclosure.dart`:
```dart
/// Supabase `enclosures` 테이블 매핑 (terra-server 스키마 기준).
///
/// 컬럼: id, owner_id, name, species, note, created_at, updated_at
/// owner_id는 RLS로 본인 것만 조회되므로 모델에 담지 않는다
/// (TerraCamera와 동일한 관례).
class Enclosure {
  final String id;
  final String name;
  final String? species;
  final String? note;
  final DateTime createdAt;

  const Enclosure({
    required this.id,
    required this.name,
    this.species,
    this.note,
    required this.createdAt,
  });

  factory Enclosure.fromJson(Map<String, dynamic> j) {
    return Enclosure(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      species: j['species'] as String?,
      note: j['note'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/my_cage/enclosure_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/domain/enclosure.dart test/features/my_cage/enclosure_test.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/domain/enclosure.dart test/features/my_cage/enclosure_test.dart
git commit -m "feat(my_cage): Enclosure 도메인 모델 + fromJson 테스트 (S1)"
```

---

## Task 2: EnclosureRepository (Supabase 직결)

**Files:**
- Create: `lib/features/my_cage/data/enclosure_repository.dart`

> 무테스트: Supabase 직결이라 목킹 없이 단위테스트 불가 — `CameraRepository`와 동일 관례. `flutter analyze`로 정합성만 검증하고 실 DB 왕복은 S5에서.

- [ ] **Step 1: Repository 구현**

`lib/features/my_cage/data/enclosure_repository.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/enclosure.dart';

/// `enclosures` 테이블 접근. 조회는 RLS로 본인 소유만 반환된다.
class EnclosureRepository {
  final SupabaseClient _supabase;

  EnclosureRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Supabase 직결 ──────────────────────────────────────────────────────────

  /// 현재 유저의 사육장 전체 목록 (최신순).
  Future<List<Enclosure>> listAll() async {
    final rows = await _supabase
        .from('enclosures')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Enclosure.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 단일 사육장 조회. 없으면 null.
  Future<Enclosure?> getById(String id) async {
    final rows =
        await _supabase.from('enclosures').select().eq('id', id).limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Enclosure.fromJson(list.first as Map<String, dynamic>);
  }

  /// 사육장 생성. owner_id는 현재 로그인 유저로 세팅(RLS가 본인 것만 허용).
  /// 생성된 행을 Enclosure로 반환. 세션이 없으면 StateError.
  Future<Enclosure> create({
    required String name,
    String? species,
    String? note,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('사육장 생성 실패: 로그인 세션이 없습니다.');
    }
    final row = await _supabase.from('enclosures').insert({
      'owner_id': userId,
      'name': name,
      if (species != null) 'species': species,
      if (note != null) 'note': note,
    }).select().single();
    return Enclosure.fromJson(row);
  }
}
```

- [ ] **Step 2: analyze 검증**

Run: `flutter analyze lib/features/my_cage/data/enclosure_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/my_cage/data/enclosure_repository.dart
git commit -m "feat(my_cage): EnclosureRepository (listAll/getById/create) (S1)"
```

---

## Task 3: Provider 배선

**Files:**
- Modify: `lib/features/my_cage/presentation/my_cage_providers.dart`

- [ ] **Step 1: import 추가**

`my_cage_providers.dart`의 data import 블록(현재 line 8 `import '../data/camera_repository.dart';` 아래)에 추가:
```dart
import '../data/enclosure_repository.dart';
```
그리고 domain import 블록(현재 line 16 `import '../domain/terra_camera.dart';` 아래)에 추가:
```dart
import '../domain/enclosure.dart';
```
> `currentUserProvider`는 line 7 `auth_providers.dart` import로 이미 사용 가능(camerasProvider가 이미 사용 중).

- [ ] **Step 2: Repository Provider 추가**

`cameraRepositoryProvider` 정의 블록(현재 line 33-37) **바로 아래**에 추가:
```dart
final enclosureRepositoryProvider = Provider<EnclosureRepository>((ref) {
  return EnclosureRepository(
    supabase: ref.watch(_supabaseClientProvider),
  );
});
```

- [ ] **Step 3: 공개 Provider 추가**

`cameraProvider` 정의 블록(현재 line 101-105, `// ── 시간대별 클립 조회 Provider` 주석 위)  **아래**에 추가:
```dart
// ── 사육장(enclosure) Provider ─────────────────────────────────────────────────

/// 현재 유저의 사육장 목록 (최신순). 계정 전환 시 재조회(이전 계정 노출 방지 —
/// project_auth_provider_stale_pattern). 생성/수정 후 ref.invalidate로 갱신한다.
final enclosuresProvider = FutureProvider<List<Enclosure>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(enclosureRepositoryProvider).listAll();
});

/// 단일 사육장 조회. 존재하지 않으면 null.
final enclosureProvider =
    FutureProvider.family<Enclosure?, String>((ref, id) async {
  return ref.watch(enclosureRepositoryProvider).getById(id);
});
```

- [ ] **Step 4: analyze 검증 (전체)**

Run: `flutter analyze`
Expected: `No issues found!` (에러 0 — CLAUDE.md 필수 규칙)

- [ ] **Step 5: 전체 테스트 회귀 확인**

Run: `flutter test`
Expected: 기존 테스트 + enclosure_test 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/my_cage/presentation/my_cage_providers.dart
git commit -m "feat(my_cage): enclosure Provider 배선 (repo/list/byId) (S1)"
```

---

## 완료 후 (push 전)

- **버전 bump** (`project_release_versioning`): S1은 feature 추가 → `pubspec.yaml`의 `version` **minor +1, build +1**. pre-push 훅(`tools/git-hooks`)이 lib 변경 무버전업 push를 차단하므로 push 전 필수.
- **다음 단계**: S2(사육장 관리 UI + 기기 배정) 계획서 작성. 본 S1의 `enclosuresProvider`·`EnclosureRepository.create`를 소비.

---

## Self-Review

**1. Spec 커버리지 (기획서 S1 = "Enclosure 도메인 + Repository + Provider"):**
- ✅ 도메인 `Enclosure` → Task 1
- ✅ `EnclosureRepository`(조회+생성) → Task 2
- ✅ `enclosuresProvider`(+ repo/byId) → Task 3
- 배정/수정/삭제·UI는 의도적으로 S2로 분리(범위 밖 명시) — gap 아님.

**2. Placeholder 스캔:** TBD/TODO/"적절히 처리" 없음. 모든 code step에 실제 코드 존재. 테스트 3케이스 실제 값 명시.

**3. 타입 일관성:**
- `Enclosure({id, name, species?, note?, createdAt})` — Task 1 정의 = Task 2 `fromJson` 소비 = Task 3 Provider 반환 타입 일치.
- `EnclosureRepository({required supabase})` 생성자 = Task 3 provider의 `EnclosureRepository(supabase: ...)` 호출 일치.
- 메서드명 `listAll`/`getById`/`create` — Task 2 정의 = Task 3 `enclosuresProvider`(listAll)·`enclosureProvider`(getById) 호출 일치.
- `_supabaseClientProvider`·`currentUserProvider` — 기존 파일에 이미 존재(신규 정의 아님) 확인함.

**주의 사항 (구현자 유의):**
- `Enclosure.fromJson`의 `created_at` 파싱은 `DateTime.tryParse` 결과(UTC)를 그대로 담는다(`TerraCamera`와 동일). 테스트는 `isAtSameMomentAs`로 비교해 타임존 함정을 피한다.
- `insert(...).select().single()`은 생성 행을 반환한다 — RLS INSERT 정책이 없으면 실패할 수 있으나, `enclosures`는 owner 기반 정책이 있고 owner_id를 본인으로 넣으므로 통과한다. 실패 시 S5에서 RLS 정책 점검.
