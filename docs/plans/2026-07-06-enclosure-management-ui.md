# 사육장(Enclosure) 관리 UI + 기기 배정 — S2 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 승인 후 flutter-dev가 task별 구현(GATE 4). Steps use checkbox (`- [ ]`).

**Goal:** 크레캠 정공법 S2 — 앱에서 **사육장을 만들고, 카메라·센서 모듈을 사육장에 배정**하는 UI를 추가한다. S1의 `enclosuresProvider`/`EnclosureRepository`를 소비하고, 카메라·디바이스의 `enclosure_id`를 채워 S3(비디오)/S4(온습도) 정합의 데이터 조건을 만든다.

**Architecture:** 기존 화면 패턴(`SmartCageScreen`) 복제. 사육장 목록/생성 = `EnclosureListScreen`, 배정 = `EnclosureDetailScreen`. 배정은 `cameras`/`devices`의 `enclosure_id` UPDATE(각 Repository에 `assignEnclosure` 추가). 목록 소비는 기존 `camerasProvider`(StreamProvider — 배정 후 자동 갱신)·`deviceListProvider`(FutureProvider — 배정 후 `invalidate`)를 `enclosure_id`로 필터. 진입점은 `SmartCageScreen` AppBar.

**Tech Stack:** Flutter · Riverpod · go_router · supabase_flutter · easy_localization

**범위 밖(다음):** 사육장 수정/삭제(update name/delete) · 종(species) 입력 · 비디오 기록 배선(S3) · 온습도 정합(S4) · 사육장별 대시보드.

---

## 유저 체험 설계서 (프레임 단위)

```
[화면] 사육장 탭(SmartCageScreen) 우상단에 "🏘 사육장 관리" 아이콘이 보인다
  [조작] 아이콘 탭
  [반응] EnclosureListScreen 진입. 사육장이 없으면 빈 상태:
         "아직 사육장이 없어요 / 사육장을 만들어 카메라·센서를 묶어보세요"
  [감정] "여기서 사육장 단위로 기기를 묶는구나"

[화면] EnclosureListScreen 우상단 "+" 버튼
  [조작] 탭
  [반응] 다이얼로그 "사육장 만들기" + 이름 입력창(hint: "예: 크레 사육장 A")
  [조작] 이름 입력 후 "만들기"
  [반응] 다이얼로그 닫힘 → 목록에 새 카드 등장 "크레 사육장 A / 카메라 0 · 센서 0"
  [감정] "만들어졌다"

[화면] 사육장 카드
  [조작] 탭
  [반응] EnclosureDetailScreen. 상단 = 사육장 이름. "카메라" 섹션(비어있음),
         "센서 모듈" 섹션(비어있음). 각 섹션 헤더에 "배정" 버튼.
  [조작] 카메라 섹션의 "카메라 배정" 탭
  [반응] 바텀시트에 미배정 카메라 목록(P4 Cam, P4 Cam 2)이 뜬다. 하나 탭.
  [반응] 시트 닫힘 → 카메라 섹션에 그 카메라가 등장(옆에 연결해제 아이콘)
  [감정] "이 사육장에 이 카메라가 묶였다"

[조작] 배정된 카메라 옆 연결해제(🔗✕) 아이콘 탭
  [반응] 즉시 목록에서 사라짐(enclosure_id=null 로 해제)
  [감정] "언제든 뺄 수 있다"

[결과] 이 배정으로 camera.enclosure_id / device.enclosure_id 가 채워져
       S3/S4에서 "이 카메라가 속한 사육장"을 특정할 수 있게 된다.
```

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `lib/features/my_cage/data/camera_repository.dart` | Modify | `assignEnclosure(cameraId, enclosureId?)` 추가 |
| `lib/features/my_cage/data/supabase_module_control_repository.dart` | Modify | `assignEnclosure(deviceId, enclosureId?)` 추가 |
| `assets/l10n/ko.json` | Modify | `enclosure_*` 키 + `common_cancel`(없으면) |
| `lib/features/my_cage/presentation/enclosure_list_screen.dart` | Create | 목록 + 생성 다이얼로그 |
| `lib/features/my_cage/presentation/enclosure_detail_screen.dart` | Create | 배정된 기기 표시 + 배정/해제 바텀시트 |
| `lib/core/router/app_router.dart` | Modify | `/smart-cage/enclosures`(+`:enclosureId`) 라우트 |
| `lib/features/my_cage/presentation/smart_cage_screen.dart` | Modify | AppBar에 사육장 관리 진입 아이콘 |

**테스트 전략:** S1과 동일 — 배정은 Supabase 직결 UPDATE(무테스트, `CameraRepository` 관례), 화면은 위젯테스트 인프라 부재로 `flutter analyze` + S5 통합검증. 이번 S2엔 순수 로직이 없어 신규 단위테스트는 없다(기존 `flutter test` 회귀만 확인).

**디자인 규칙(엄수):** 로딩=`SkeletonCard`(CircularProgressIndicator 금지) · 색상=`Theme.of(context)`/`AppStyles`(하드코딩 금지) · 문자열=`ko.json`+`.tr()`(하드코딩 금지) · 상태관리=Riverpod.

---

## Task 1: Repository 배정 메서드

**Files:** Modify `camera_repository.dart` · Modify `supabase_module_control_repository.dart`

- [ ] **Step 1: CameraRepository.assignEnclosure 추가**

`camera_repository.dart`의 `delete` 메서드(현재 line 30-32) **아래**에 추가:
```dart
  /// 카메라를 사육장에 배정. enclosureId=null 이면 배정 해제.
  /// RLS(owner_id=auth.uid)로 본인 카메라만 UPDATE 가능.
  Future<void> assignEnclosure(String cameraId, String? enclosureId) async {
    await _supabase
        .from('cameras')
        .update({'enclosure_id': enclosureId})
        .eq('id', cameraId);
  }
```

- [ ] **Step 2: SupabaseModuleControlRepository.assignEnclosure 추가**

먼저 `supabase_module_control_repository.dart`의 `listDevices()`(현재 line 60 부근)를 Read로 확인해 클래스 내부 위치를 잡은 뒤, `listDevices` 메서드 **아래**에 추가:
```dart
  /// 디바이스를 사육장에 배정. enclosureId=null 이면 배정 해제.
  /// RLS(owner_id=auth.uid)로 본인 디바이스만 UPDATE 가능.
  Future<void> assignEnclosure(String deviceId, String? enclosureId) async {
    await _supabase
        .from('devices')
        .update({'enclosure_id': enclosureId})
        .eq('id', deviceId);
  }
```
> 필드명은 실제 파일의 SupabaseClient 필드(`_supabase`)를 확인해 맞춘다(camera_repository와 동일 관례).

- [ ] **Step 3: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/data/camera_repository.dart lib/features/my_cage/data/supabase_module_control_repository.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/data/camera_repository.dart lib/features/my_cage/data/supabase_module_control_repository.dart
git commit -m "feat(my_cage): 카메라/디바이스 사육장 배정 메서드 assignEnclosure (S2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: ko.json 문자열 키

**Files:** Modify `assets/l10n/ko.json`

- [ ] **Step 1: enclosure 키 블록 추가**

`camera_detail_clips_empty` 키(현재 line 287 부근) **아래**에 추가(끝 콤마 유의). `common_cancel`은 파일에 이미 있으면 중복 추가하지 말 것(먼저 `grep '"common_cancel"' assets/l10n/ko.json` 확인):
```json
  "enclosure_manage_title": "사육장 관리",
  "enclosure_list_empty": "아직 사육장이 없어요",
  "enclosure_list_empty_sub": "사육장을 만들어 카메라·센서를 묶어보세요",
  "enclosure_create_title": "사육장 만들기",
  "enclosure_name_hint": "예: 크레 사육장 A",
  "enclosure_create_button": "만들기",
  "enclosure_device_count": "카메라 {cams} · 센서 {devs}",
  "enclosure_section_cameras": "카메라",
  "enclosure_section_devices": "센서 모듈",
  "enclosure_assign_camera": "카메라 배정",
  "enclosure_assign_device": "센서 배정",
  "enclosure_section_empty": "아직 배정된 기기가 없어요",
  "enclosure_no_unassigned": "배정할 수 있는 기기가 없어요",
  "enclosure_pick_title": "배정할 기기 선택",
  "common_cancel": "취소",
```

- [ ] **Step 2: JSON 유효성 확인**

Run: `python3 -c "import json; json.load(open('assets/l10n/ko.json')); print('OK')"`
Expected: `OK`

- [ ] **Step 3: 커밋**

```bash
git add assets/l10n/ko.json
git commit -m "feat(my_cage): 사육장 관리 ko.json 문자열 키 (S2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: EnclosureListScreen + 라우트 + 진입점

**Files:** Create `enclosure_list_screen.dart` · Modify `app_router.dart` · Modify `smart_cage_screen.dart`

- [ ] **Step 1: EnclosureListScreen 생성**

`lib/features/my_cage/presentation/enclosure_list_screen.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/enclosure.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';

/// 사육장 목록 + 생성. 카드 탭 시 상세(배정) 화면으로.
class EnclosureListScreen extends ConsumerWidget {
  const EnclosureListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enclosuresAsync = ref.watch(enclosuresProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('enclosure_manage_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'enclosure_create_title'.tr(),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: enclosuresAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonCard(lineCount: 2),
            SizedBox(height: 12),
            SkeletonCard(lineCount: 2),
          ],
        ),
        error: (e, _) => Center(child: Text('error_generic'.tr())),
        data: (list) {
          if (list.isEmpty) return const _EmptyEnclosures();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _EnclosureCard(enclosure: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('enclosure_create_title'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'enclosure_name_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('enclosure_create_button'.tr()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(enclosureRepositoryProvider).create(name: name);
    ref.invalidate(enclosuresProvider);
  }
}

class _EnclosureCard extends ConsumerWidget {
  const _EnclosureCard({required this.enclosure});
  final Enclosure enclosure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camCount = ref
            .watch(camerasProvider)
            .valueOrNull
            ?.where((c) => c.enclosureId == enclosure.id)
            .length ??
        0;
    final devCount = ref
            .watch(deviceListProvider)
            .valueOrNull
            ?.where((d) => d.enclosureId == enclosure.id)
            .length ??
        0;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(enclosure.name),
        subtitle: Text('enclosure_device_count'.tr(
          namedArgs: {'cams': '$camCount', 'devs': '$devCount'},
        )),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('/smart-cage/enclosures/${enclosure.id}'),
      ),
    );
  }
}

class _EmptyEnclosures extends StatelessWidget {
  const _EmptyEnclosures();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.holiday_village_outlined,
                size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            Text('enclosure_list_empty'.tr(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('enclosure_list_empty_sub'.tr(),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 라우트 등록 (list)**

`app_router.dart` 상단 import 블록(다른 my_cage import 근처, 현재 line 21 부근)에 추가:
```dart
import '../../features/my_cage/presentation/enclosure_list_screen.dart';
import '../../features/my_cage/presentation/enclosure_detail_screen.dart';
```
그리고 `/smart-cage` GoRoute의 `routes:` 배열(현재 `devices/pair` 항목이 있는 곳, line 169-174)에 형제로 추가:
```dart
                  GoRoute(
                    path: 'enclosures',
                    builder: (context, state) => const EnclosureListScreen(),
                    routes: [
                      GoRoute(
                        path: ':enclosureId',
                        builder: (context, state) {
                          final id = state.pathParameters['enclosureId']!;
                          return EnclosureDetailScreen(enclosureId: id);
                        },
                      ),
                    ],
                  ),
```
> `enclosure_detail_screen.dart`는 Task 4에서 생성한다. import를 먼저 추가하므로 Task 3 단계에서 analyze가 "미존재" 오류를 낼 수 있다 — **Task 3와 Task 4는 한 커밋 경계로 묶어** Task 4 완료 후 analyze/커밋한다(아래 Step 4 참고).

- [ ] **Step 3: SmartCageScreen 진입점 추가**

`smart_cage_screen.dart`의 AppBar `actions:` 배열(현재 line 30) 맨 앞(WifiReconfigureMenu 위)에 추가:
```dart
          IconButton(
            icon: const Icon(Icons.holiday_village_outlined),
            tooltip: 'enclosure_manage_title'.tr(),
            onPressed: () => context.push('/smart-cage/enclosures'),
          ),
```
> `context`, `.tr()`는 이미 이 파일에서 사용 중(go_router·easy_localization import 존재).

- [ ] **Step 4:** Task 4로 이어서 진행(중간 커밋 없음 — detail 화면 생성 후 통합 analyze/커밋).

---

## Task 4: EnclosureDetailScreen (배정/해제)

**Files:** Create `enclosure_detail_screen.dart`

- [ ] **Step 1: EnclosureDetailScreen 생성**

`lib/features/my_cage/presentation/enclosure_detail_screen.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_header.dart';
import '../domain/device.dart';
import '../domain/terra_camera.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';

/// 사육장 상세 — 배정된 카메라/디바이스 표시 + 배정/해제.
class EnclosureDetailScreen extends ConsumerWidget {
  const EnclosureDetailScreen({super.key, required this.enclosureId});
  final String enclosureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enclosureAsync = ref.watch(enclosureProvider(enclosureId));
    final cameras = ref.watch(camerasProvider).valueOrNull ?? const [];
    final devices = ref.watch(deviceListProvider).valueOrNull ?? const [];
    final myCams =
        cameras.where((c) => c.enclosureId == enclosureId).toList();
    final myDevs =
        devices.where((d) => d.enclosureId == enclosureId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(enclosureAsync.valueOrNull?.name ??
            'enclosure_manage_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            title: 'enclosure_section_cameras'.tr(),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('enclosure_assign_camera'.tr()),
              onPressed: () => _pickCamera(context, ref, cameras),
            ),
          ),
          if (myCams.isEmpty)
            _emptyHint(context)
          else
            ...myCams.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(c.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      await ref
                          .read(cameraRepositoryProvider)
                          .assignEnclosure(c.id, null);
                    },
                  ),
                )),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'enclosure_section_devices'.tr(),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('enclosure_assign_device'.tr()),
              onPressed: () => _pickDevice(context, ref, devices),
            ),
          ),
          if (myDevs.isEmpty)
            _emptyHint(context)
          else
            ...myDevs.map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors),
                  title: Text(d.name ?? d.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      await ref
                          .read(supabaseModuleControlRepositoryProvider)
                          .assignEnclosure(d.id, null);
                      ref.invalidate(deviceListProvider);
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _emptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'enclosure_section_empty'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }

  Future<void> _pickCamera(
      BuildContext context, WidgetRef ref, List<TerraCamera> all) async {
    final unassigned = all.where((c) => c.enclosureId == null).toList();
    final picked = await _showPicker<TerraCamera>(
      context,
      unassigned,
      (c) => c.name,
      Icons.videocam_outlined,
    );
    if (picked == null) return;
    await ref
        .read(cameraRepositoryProvider)
        .assignEnclosure(picked.id, enclosureId);
    // camerasProvider(Stream)는 자동 갱신.
  }

  Future<void> _pickDevice(
      BuildContext context, WidgetRef ref, List<Device> all) async {
    final unassigned = all.where((d) => d.enclosureId == null).toList();
    final picked = await _showPicker<Device>(
      context,
      unassigned,
      (d) => d.name ?? d.id,
      Icons.sensors,
    );
    if (picked == null) return;
    await ref
        .read(supabaseModuleControlRepositoryProvider)
        .assignEnclosure(picked.id, enclosureId);
    ref.invalidate(deviceListProvider);
  }

  Future<T?> _showPicker<T>(
    BuildContext context,
    List<T> items,
    String Function(T) label,
    IconData icon,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) {
        if (items.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('enclosure_no_unassigned'.tr(),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('enclosure_pick_title'.tr(),
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ...items.map((it) => ListTile(
                    leading: Icon(icon),
                    title: Text(label(it)),
                    onTap: () => Navigator.pop(ctx, it),
                  )),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 전체 analyze**

Run: `flutter analyze`
Expected: 신규 4파일 관련 이슈 0 (에러 0 필수). 기존 info 경고(morph_calc 등)는 무관·범위 밖.

- [ ] **Step 3: 회귀 테스트**

Run: `flutter test`
Expected: 기존 + enclosure_test 전부 PASS(신규 테스트 없음, 회귀 확인).

- [ ] **Step 4: 커밋 (Task 3+4 통합)**

```bash
git add lib/features/my_cage/presentation/enclosure_list_screen.dart \
        lib/features/my_cage/presentation/enclosure_detail_screen.dart \
        lib/core/router/app_router.dart \
        lib/features/my_cage/presentation/smart_cage_screen.dart
git commit -m "feat(my_cage): 사육장 관리 UI(목록/생성/배정) + 라우트 + 진입점 (S2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (push 전)

- **버전 bump**: S2도 feature → `pubspec.yaml` minor +1, build +1 (`0.5.0+12` → `0.6.0+13`).
- **다음**: S3(비디오 기록 → motion_clips via enclosure) 계획.

---

## Self-Review

**1. Spec 커버리지 (기획서 S2 = "사육장 CRUD + 기기 배정/해제 UI"):**
- ✅ 생성(create) → Task 3 다이얼로그 · 목록(read) → Task 3 · 배정/해제 → Task 1 repo + Task 4 화면.
- 수정/삭제는 범위 밖 명시(다음). MVP로 생성+배정에 집중 — gap 아님.

**2. Placeholder 스캔:** TBD/TODO 없음. 모든 화면·repo·라우트·ko.json 코드가 실제 코드로 박힘. 배정 로직(assign/unassign) 구체 구현 포함.

**3. 타입 일관성:**
- `assignEnclosure(String, String?)` — Task 1 정의 = Task 4 호출(`assignEnclosure(picked.id, enclosureId)` / `(c.id, null)`) 일치.
- `enclosuresProvider`/`enclosureProvider`/`enclosureRepositoryProvider` — S1 정의(커밋됨) = Task 3/4 소비 일치.
- `camerasProvider`(StreamProvider<List<TerraCamera>>)·`deviceListProvider`(FutureProvider<List<Device>>) — 기존 정의 = `.valueOrNull?.where(...)` 소비 타입 일치. `TerraCamera.enclosureId`/`Device.enclosureId`(둘 다 `String?`) 필터 필드 존재 확인함.
- `EnclosureDetailScreen({required enclosureId})` — Task 4 정의 = Task 3 라우트 `EnclosureDetailScreen(enclosureId: id)` 호출 일치.
- `SkeletonCard(lineCount:)`·`SectionHeader(title:, trailing:)`·`AppTag(label:)` — 실제 시그니처 확인함.

**갱신 정합성 주의(구현자):**
- 카메라 배정/해제 후 `camerasProvider`는 StreamProvider(cameras realtime 구독)라 **자동 갱신**된다 → invalidate 불필요.
- 디바이스 배정/해제 후 `deviceListProvider`는 FutureProvider(autoDispose)라 **반드시 `ref.invalidate(deviceListProvider)`** 호출(코드에 포함됨).
- 배정 실패(RLS/네트워크) 시 예외는 현재 상위로 전파 — MVP는 별도 스낵바 없음(S5에서 UX 보강 여지). 크래시는 아님(async 콜백).
