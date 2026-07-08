# 즐겨찾기 클라우드 동기화 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. flutter-dev가 task별 구현. Steps use checkbox.
> 작성일: 2026-07-08 · 선행: 어젯밤 리포트(별도 계획) 커밋 후 착수(공유 파일 `my_cage_providers.dart` 충돌 회피).

**Goal:** 즐겨찾기를 로컬 전용 → **클라우드 동기화**로. 재설치·기기변경에도 즐겨찾기가 유지되고, 계정별로 격리된다.

**Architecture:** 백엔드가 만든 **Supabase `clip_favorites(owner_id, clip_id, created_at)` + RLS**(terra-api 불필요, Supabase 직결)를 **durable 플래그**로 쓴다. 로컬 Hive `FavoriteClip`은 그대로 **오프라인 영상 캐시**. add/remove 시 로컬 처리 후 클라우드에 즉시 push. 즐겨찾기 탭 진입 시 cloud→local **pull**(신규기기/로그인 후 복원 — 누락 클립을 metadata+mp4 다운로드). 계정 격리는 `FavoriteClip.ownerId`로 자체 처리(로그아웃 캐시clear 코드 미변경). 읽기 모델은 로컬 Hive 유지(UI 무변경).

**Tech Stack:** Flutter · Riverpod · Hive · supabase_flutter · http (신규 패키지 없음)

**clip_favorites 계약:** `insert/delete/select` Supabase 직결. RLS `owner_id = auth.uid()`. 컬럼 `owner_id uuid`, `clip_id uuid`, `created_at`. R2 자동삭제 없음(보존 불필요) — pull 시 motion_clips에서 항상 재조회 가능.

**범위 밖(후속):** 오프라인 상태에서의 add(클라우드 push 실패는 best-effort 무시, 다음 sync에서 재push) · 대량 즐겨찾기 pull 최적화(현재 탭 진입 시 누락분 순차 다운로드).

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `lib/features/my_cage/domain/favorite_clip.dart` (+`.g.dart`) | Modify | `ownerId` 필드 추가(계정 격리) |
| `lib/features/my_cage/data/favorite_clip_repository.dart` | Modify | Supabase push/pull/sync + uid 필터 |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | repo에 Supabase 주입 + `favoritesSyncProvider` |
| `lib/features/my_cage/presentation/camera_detail_screen.dart` | Modify | `_FavoritesGrid`에서 sync 트리거 |

**테스트 전략:** Supabase·Hive·IO 직결이라 무테스트 + `flutter analyze` 0 + `flutter build apk --debug` + 통합검증(런타임은 사용자 실기기 — Supabase RLS·크로스기기).

---

## Task 1: FavoriteClip에 ownerId (계정 격리)

**Files:** Modify `domain/favorite_clip.dart` (+ regen `.g.dart`)

- [ ] **Step 1: 필드 추가**

`favorite_clip.dart`에 `@HiveField(7) final String ownerId;` 추가(생성자 required, 마지막 필드로). 클래스 doc에 "ownerId=소유 계정(auth.uid) — 계정 격리" 한 줄 주석.
```dart
  @HiveField(7)
  final String ownerId;
```
생성자에 `required this.ownerId,` 추가.

- [ ] **Step 2: 어댑터 재생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `favorite_clip.g.dart`에 field 7 반영. (기존 로컬 즐겨찾기 레코드는 ownerId 없이 저장돼 있으면 로드 시 예외 가능 → 이 기능은 신규라 실기기 미배포 가정. 만약 기존 레코드 이슈 시 box clear로 해결 — 구현자 판단.)

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/my_cage/domain/favorite_clip.dart`
Expected: `No issues found!` (커밋은 Task 2와 함께 — 생성자 변경이 repo에 영향)

---

## Task 2: FavoriteClipRepository 클라우드화

**Files:** Modify `data/favorite_clip_repository.dart`

- [ ] **Step 1: Supabase 주입 + uid 헬퍼**

import 추가: `import 'package:supabase_flutter/supabase_flutter.dart';`
클래스에 필드/생성자 추가(기존 무인자 생성자를 교체):
```dart
class FavoriteClipRepository {
  FavoriteClipRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;
  static const _boxName = 'favorite_clips';
  static const _subdir = 'favorite_clips';
  static const _table = 'clip_favorites';

  Box<FavoriteClip> get _box => Hive.box<FavoriteClip>(_boxName);

  String? get _uid => _supabase.auth.currentUser?.id;
  // ... 기존 init/_favDir 유지
```
> 기존 `init()`(static, adapter+box)·`_favDir()`는 그대로 둔다.

- [ ] **Step 2: 읽기 메서드에 계정 필터**

`isFavorite`·`listByCamera`·`getLocalFile`·`getMeta`가 **현재 uid 소유분만** 반환하도록 필터. 예:
```dart
  bool isFavorite(String clipId) {
    final m = _box.get(clipId);
    return m != null && m.ownerId == _uid;
  }

  List<FavoriteClip> listByCamera(String cameraId) {
    final uid = _uid;
    return _box.values
        .where((f) => f.ownerId == uid && f.cameraId == cameraId)
        .toList()
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
  }

  File? getLocalFile(String clipId) {
    final m = _box.get(clipId);
    if (m == null || m.ownerId != _uid) return null;
    final f = File(m.filePath);
    return f.existsSync() ? f : null;
  }

  FavoriteClip? getMeta(String clipId) {
    final m = _box.get(clipId);
    return (m != null && m.ownerId == _uid) ? m : null;
  }
```

- [ ] **Step 3: add/remove에 ownerId + 클라우드 push**

`add(MotionClip clip, String presignedUrl)`:
- FavoriteClip 생성 시 `ownerId: _uid ?? ''` 추가.
- 로컬 저장(mp4+box.put) 후 클라우드 upsert(best-effort):
```dart
    await _box.put(clip.id, FavoriteClip(
      clipId: clip.id, cameraId: clip.cameraId, startedAt: clip.startedAt,
      durationSec: clip.durationSec, filePath: path, sizeBytes: bytes.length,
      favoritedAt: DateTime.now(), ownerId: _uid ?? '',
    ));
    final uid = _uid;
    if (uid != null) {
      try {
        await _supabase.from(_table).upsert({'owner_id': uid, 'clip_id': clip.id});
      } catch (_) {/* 오프라인 등 — 다음 sync에서 재push */}
    }
```
`remove(String clipId)`: 로컬 삭제 후:
```dart
    final uid = _uid;
    if (uid != null) {
      try {
        await _supabase.from(_table).delete()
            .eq('owner_id', uid).eq('clip_id', clipId);
      } catch (_) {}
    }
```
> `remove`는 기존처럼 cameraId(String?) 반환 유지(호출부 invalidate용).

- [ ] **Step 4: cloud 조회 + sync**

메서드 추가:
```dart
  /// 클라우드 즐겨찾기 clip_id 집합(현재 계정). 실패 시 빈 집합.
  Future<Set<String>> _cloudClipIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _supabase.from(_table).select('clip_id').eq('owner_id', uid);
      return {for (final r in rows as List) (r as Map)['clip_id'] as String};
    } catch (_) {
      return {};
    }
  }

  /// cloud↔local 동기화. push: 로컬만 있는 것 → 클라우드. pull: 클라우드만 있는 것
  /// → metadata+mp4 다운로드해 로컬 보관. best-effort(개별 실패 skip).
  /// [motionRepo]로 getById/getPlaybackUrl 수행.
  Future<void> syncFromCloud(MotionClipRepository motionRepo) async {
    final uid = _uid;
    if (uid == null) return;
    final cloud = await _cloudClipIds();
    final localIds = _box.values
        .where((f) => f.ownerId == uid)
        .map((f) => f.clipId)
        .toSet();

    // push: 로컬에만 있는 것
    for (final id in localIds.difference(cloud)) {
      try {
        await _supabase.from(_table).upsert({'owner_id': uid, 'clip_id': id});
      } catch (_) {}
    }
    // pull: 클라우드에만 있는 것 → 다운로드
    for (final id in cloud.difference(localIds)) {
      try {
        final clip = await motionRepo.getById(id);
        if (clip == null) continue;
        final url = await motionRepo.getPlaybackUrl(id);
        await add(clip, url); // add가 다시 upsert하지만 idempotent
      } catch (_) {/* 개별 실패 skip */}
    }
  }
```
> `MotionClipRepository`는 `getById(String)→Future<MotionClip?>`·`getPlaybackUrl(String)→Future<String>` 보유(확인됨). import 추가: `import '../domain/motion_clip.dart';`가 이미 있으면 재사용, `motion_clip_repository.dart` import 추가.

- [ ] **Step 5: analyze + 커밋 (Task 1+2)**

Run: `flutter analyze lib/features/my_cage/domain/favorite_clip.dart lib/features/my_cage/data/favorite_clip_repository.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/domain/favorite_clip.dart \
        lib/features/my_cage/domain/favorite_clip.g.dart \
        lib/features/my_cage/data/favorite_clip_repository.dart
git commit -m "feat(my_cage): 즐겨찾기 클라우드 동기화 저장소(clip_favorites push/pull + 계정격리)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Provider 주입 + sync 트리거

**Files:** Modify `my_cage_providers.dart`, `camera_detail_screen.dart`

- [ ] **Step 1: repo Provider에 Supabase 주입**

`my_cage_providers.dart`에서 `favoriteClipRepositoryProvider`를 교체:
```dart
final favoriteClipRepositoryProvider =
    Provider<FavoriteClipRepository>((ref) {
  return FavoriteClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
  );
});
```
> `_supabaseClientProvider`는 이 파일 상단에 이미 정의됨.

- [ ] **Step 2: sync Provider 추가**

`isFavoriteProvider` 아래에 추가:
```dart
/// 즐겨찾기 클라우드→로컬 동기화(탭 진입 시 1회). 완료 후 목록 invalidate로 갱신.
final favoritesSyncProvider =
    FutureProvider.autoDispose.family<void, String>((ref, cameraId) async {
  ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 전환 시 재동기화
  final favRepo = ref.watch(favoriteClipRepositoryProvider);
  final motionRepo = ref.watch(motionClipRepositoryProvider);
  await favRepo.syncFromCloud(motionRepo);
  // pull로 로컬이 늘었을 수 있으니 목록 갱신
  ref.invalidate(favoriteClipsProvider(cameraId));
});
```

- [ ] **Step 3: 즐겨찾기 그리드에서 sync 트리거**

`camera_detail_screen.dart`의 `_FavoritesGrid.build`에서, 목록 표시 전에 sync를 watch(진입 시 1회 실행, 결과는 무시하고 진행):
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(favoritesSyncProvider(cameraId)); // cloud→local 동기화 트리거
    final favs = ref.watch(favoriteClipsProvider(cameraId));
    // ... 기존 그대로 (favs.isEmpty 처리 → 그리드)
```
> sync 진행 중에도 기존 로컬 favs를 즉시 보여주고, pull 완료되면 invalidate로 카드가 추가된다. sync 실패는 조용히 무시(로컬만 표시).

- [ ] **Step 4: 전체 analyze + build + 커밋**

Run: `flutter analyze`
Expected: 신규/수정 에러 0.
Run: `flutter build apk --debug`
Expected: 성공.
버전 minor bump(현재값 minor+1, build+1).
```bash
git add lib/features/my_cage/presentation/my_cage_providers.dart \
        lib/features/my_cage/presentation/camera_detail_screen.dart pubspec.yaml
git commit -m "feat(my_cage): 즐겨찾기 탭 진입 시 클라우드 동기화 + repo Supabase 주입 + vX

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (통합검증, 실기기 — 사용자)

- 기기A: 클립 즐겨찾기 → Supabase `clip_favorites`에 행 생성 확인.
- 기기B(또는 재설치/재로그인): 즐겨찾기 탭 진입 → cloud pull로 클립이 다운로드돼 나타남 + 오프라인 재생.
- 즐겨찾기 해제 → 로컬+클라우드 행 삭제.
- 계정 전환: 이전 계정 즐겨찾기 안 보임(ownerId 격리) + 새 계정 것 pull.

---

## Self-Review

**1. Spec 커버리지:** 클라우드 동기화(push=add/remove, pull=syncFromCloud) · 계정격리(ownerId 필터) · 재설치/기기변경 유지(pull) · UI 무변경(로컬 읽기 모델). R2 보존 불필요(백엔드 확인). gap 없음.

**2. Placeholder 스캔:** 실제 코드/명령만. best-effort try/catch는 의도(오프라인 graceful), TODO 아님.

**3. 타입 일관성:**
- `FavoriteClip`에 `ownerId:String`(field 7, required) 추가 — Task1 정의 = Task2 add() 생성 = 읽기 필터 일치. 어댑터 재생성 필요.
- `FavoriteClipRepository({required SupabaseClient supabase})` — Task2 정의 = Task3 provider 주입 일치. `syncFromCloud(MotionClipRepository)` — motionRepo.getById/getPlaybackUrl 시그니처 확인됨.
- `favoritesSyncProvider`(FutureProvider.autoDispose.family<void,String>) — Task2 정의 = Task3 `_FavoritesGrid` watch 일치.
- `remove()` 반환 `String?`(cameraId) 유지 — 기존 호출부(플레이어 invalidate) 무변경.

**주의(구현자):**
- 선행: 어젯밤 리포트 커밋 후 착수(my_cage_providers.dart 충돌 회피). 현재 파일 Read 후 content 기준 편집.
- add()가 sync의 pull에서 재호출되며 클라우드 upsert도 하지만 idempotent(PK owner_id,clip_id).
- 기존 로컬 FavoriteClip 레코드(ownerId 이전)는 이 기능 신규라 실기기 미배포 가정 — 이슈 시 box clear.
- Supabase RLS가 owner_id=auth.uid() 강제하므로 owner_id를 명시 insert해도 타 계정 위조 불가.
