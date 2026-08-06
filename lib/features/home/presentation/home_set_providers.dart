import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../data/enclosure_set_repository.dart';
import '../domain/device_mode.dart';
import '../domain/enclosure_set.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// 사육장 세트 목록.
///
/// 계정 id만 select-watch 한다 — User 객체 전체를 watch하면 updatedAt 같은
/// 무관한 필드 변경에도 재조회가 돈다. 반대로 아예 watch하지 않으면 계정 전환
/// 시 이전 계정 세트가 캐시된 채 남는다.
///
/// **하위 소스를 repository로 직접 읽지 않고 provider로 watch한다.** 예전엔
/// repository를 read해서, 사육장을 새로 만들거나 기기를 배정해도 홈은 그대로였고
/// 앱을 껐다 켜야 반영됐다. 변경 지점마다 `invalidate(enclosureSetsProvider)`를
/// 기억하는 방식은 빠뜨리기 쉬우므로, 의존을 선언해 자동으로 다시 조립되게 한다.
final enclosureSetsProvider = FutureProvider<List<EnclosureSet>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));

  final enclosuresFuture = ref.watch(enclosuresProvider.future);
  final devicesFuture = ref.watch(deviceListProvider.future);
  final camerasAsync = ref.watch(camerasProvider);
  final pets = ref.watch(petListProvider);

  return EnclosureSetRepository(
    loadEnclosures: () => enclosuresFuture,
    loadDevices: () => devicesFuture,
    // 카메라는 Stream이라 첫 값 전에는 빈 목록으로 조립하고, 도착하면 다시 돈다.
    // 여기서 await로 막으면 캠 스트림이 늦을 때 홈 전체가 대기한다.
    loadCameras: () async => camerasAsync.valueOrNull ?? const [],
    loadPets: () => pets,
  ).listSets();
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
