import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_pets/data/pet_repository.dart';
import '../data/enclosure_set_repository.dart';
import '../domain/device_mode.dart';
import '../domain/enclosure_set.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final enclosureSetRepositoryProvider = Provider<EnclosureSetRepository>((ref) {
  return EnclosureSetRepository(
    loadEnclosures: () => ref.read(enclosureRepositoryProvider).listAll(),
    loadDevices: () =>
        ref.read(supabaseModuleControlRepositoryProvider).listDevices(),
    loadCameras: () => ref.read(cameraRepositoryProvider).listAll(),
    loadPets: () => ref.read(petRepositoryProvider).getAllPets(),
  );
});

// ── 세트 목록 ──────────────────────────────────────────────────────────────────

/// 사육장 세트 목록.
///
/// 계정 id만 select-watch 한다 — User 객체 전체를 watch하면 updatedAt 같은
/// 무관한 필드 변경에도 재조회가 돈다. 반대로 아예 watch하지 않으면 계정 전환
/// 시 이전 계정 세트가 캐시된 채 남는다.
final enclosureSetsProvider = FutureProvider<List<EnclosureSet>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(enclosureSetRepositoryProvider).listSets();
});

// ── 선택 상태 ──────────────────────────────────────────────────────────────────

/// 헤더 드롭다운 / 상단 스와이프로 갱신되는 선택 인덱스.
/// 범위 검증은 여기서 하지 않고 [currentSetProvider]가 clamp 한다.
final selectedSetIndexProvider = StateProvider<int>((ref) => 0);

/// 현재 서브탭. 세트가 바뀌면 [DeviceMode.defaultTab]으로 되돌린다.
final homeSubTabProvider = StateProvider<HomeSubTab>(
  (ref) => HomeSubTab.control,
);

// ── 현재 세트 ──────────────────────────────────────────────────────────────────

/// 선택된 세트. 세트가 없으면 null.
///
/// 인덱스는 clamp 한다: 캠 해제·사육장 삭제로 목록이 줄면 저장된 인덱스가
/// 범위를 넘어 RangeError가 난다.
final currentSetProvider = FutureProvider<EnclosureSet?>((ref) async {
  // watch는 반드시 await **앞에서** 한다. await 뒤의 ref.watch는 의존이
  // 등록되지 않거나 늦게 등록돼 인덱스 변경이 반영되지 않는다.
  final raw = ref.watch(selectedSetIndexProvider);
  final sets = await ref.watch(enclosureSetsProvider.future);
  if (sets.isEmpty) return null;
  return sets[raw.clamp(0, sets.length - 1)];
});

/// 현재 세트의 기기 연동 모드. 세트가 없으면 [DeviceMode.none].
final currentDeviceModeProvider = FutureProvider<DeviceMode>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.mode ?? DeviceMode.none;
});
