import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/media_repository.dart';
import '../data/pet_event_repository.dart';
import '../data/pet_repository.dart';
import '../data/supabase_pet_repository.dart';
import '../domain/media_item.dart';
import '../domain/pet.dart';
import '../domain/pet_event.dart';
import '../domain/weight_log.dart';

/// 마이 크레 선택 탭: 0=개체목록, 1=리포트. 홈 배지가 1로 세팅 후 이동.
final myPetsTabProvider = StateProvider<int>((ref) => 0);

/// 개체 목록 조회 상태(UX-02, 2026-10-01). 목록이 비어 있을 때 "아직 모름"
/// ([loading])·"못 가져옴"([failed])·"정말 0마리"([ready])를 가른다 — 전엔
/// 조회 실패·로딩 중에도 "개체를 추가하세요"가 떠 기존 개체가 지워진 줄 알았다.
enum PetListLoad { loading, ready, failed }

/// [petListProvider]의 조회 상태. 계정이 바뀌면 다시 [PetListLoad.loading]
/// (클라우드)부터. 로컬 모드는 동기 조회라 바로 [PetListLoad.ready].
final petListLoadProvider = StateProvider<PetListLoad>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(supabasePetRepositoryProvider) == null
      ? PetListLoad.ready
      : PetListLoad.loading;
});

/// Pet 목록 — 인증 시 Supabase, 미인증 시 Hive
final petListProvider =
    StateNotifierProvider<PetListNotifier, List<Pet>>((ref) {
  final localRepo = ref.watch(petRepositoryProvider);
  final supabaseRepo = ref.watch(supabasePetRepositoryProvider);
  return PetListNotifier(localRepo, supabaseRepo,
      onLoad: (load) => ref.read(petListLoadProvider.notifier).state = load);
});

class PetListNotifier extends StateNotifier<List<Pet>> {
  final PetRepository _localRepo;
  final SupabasePetRepository? _supabaseRepo;

  /// 조회 상태 알림([petListLoadProvider]). 테스트 등 직접 만든 인스턴스는 없음.
  final void Function(PetListLoad)? _onLoad;

  PetListNotifier(this._localRepo, this._supabaseRepo,
      {void Function(PetListLoad)? onLoad})
      : _onLoad = onLoad,
        super([]) {
    _init();
  }

  void _report(PetListLoad load) {
    if (mounted) _onLoad?.call(load); // dispose 뒤엔 다른 계정 상태를 건드리지 않는다
  }

  Future<void> _init() async {
    try {
      if (_useCloud) {
        // 클라우드 모드: Supabase에서 동기화하여 로컬 캐시 갱신. 첫 조회는
        // 초기 상태가 이미 loading이고, 생성 중(provider build 중)에 다른
        // provider를 바꾸면 Riverpod이 막아 loading 알림을 생략한다.
        await _sync(announceLoading: false);
      } else {
        // 미인증: 이전 계정 클라우드 캐시가 'pets' 박스에 잔존 → 비우고 빈 목록 (프라이버시)
        await _localRepo.clearPets();
        refresh();
      }
    } catch (_) {
      // 실패는 syncFromRemote가 [PetListLoad.failed]로 알렸다 — 여기선 uncaught
      // async 예외만 막는다. 캐시('pets' 박스)엔 소유자 표시가 없어 실패했다고
      // 캐시를 대신 보이지 않는다(계정 격리).
    }
  }

  bool get _useCloud => _supabaseRepo != null;

  void refresh() {
    if (!mounted) return; // dispose 후 state 세팅 방지 (계정 전환 중 in-flight 콜백)
    if (_useCloud) {
      state = _supabaseRepo!.getAllPets();
    } else {
      state = _localRepo.getAllPets();
    }
  }

  Future<void> add(Pet pet) async {
    if (_useCloud) {
      await _supabaseRepo!.addPet(pet);
    } else {
      await _localRepo.addPet(pet);
    }
    refresh();
  }

  Future<void> update(Pet pet) async {
    if (_useCloud) {
      await _supabaseRepo!.updatePet(pet);
    } else {
      await _localRepo.updatePet(pet);
    }
    refresh();
  }

  Future<void> delete(String id) async {
    if (_useCloud) {
      await _supabaseRepo!.deletePet(id);
    } else {
      await _localRepo.deletePet(id);
    }
    refresh();
  }

  /// 로그인 후 Supabase에서 데이터 동기화. 화면의 "다시 시도"도 이것을 부른다.
  /// 성공하면 [PetListLoad.ready], 실패하면 목록은 그대로 두고
  /// [PetListLoad.failed]를 알린 뒤 예외를 다시 던진다.
  Future<void> syncFromRemote() => _sync(announceLoading: true);

  Future<void> _sync({required bool announceLoading}) async {
    if (_useCloud) {
      if (announceLoading) _report(PetListLoad.loading);
      try {
        await _supabaseRepo!.syncFromRemote();
      } catch (_) {
        _report(PetListLoad.failed);
        rethrow;
      }
      refresh();
      _report(PetListLoad.ready);
    }
  }

  /// 개체를 사육장에 배정 / 해제([enclosureId] = null).
  ///
  /// 서버 RPC 1회로 처리하며, 성공 시 repo가 재동기화까지 끝낸 뒤 목록을
  /// 갱신한다. 실패는 그대로 던져 화면이 사용자에게 사유를 보여주게 한다 —
  /// 로컬만 성공한 것처럼 저장하지 않는다.
  ///
  /// 사육장·배정은 클라우드 전용이라 미인증 상태에서는 지원하지 않는다.
  Future<void> assignToEnclosure({
    required String petId,
    required String? enclosureId,
  }) async {
    if (!_useCloud) {
      throw StateError('로그인이 필요합니다');
    }
    await _supabaseRepo!
        .assignPetToEnclosure(petId: petId, enclosureId: enclosureId);
    refresh();
  }
}

/// 단일 Pet 조회 (family provider)
final petDetailProvider = Provider.family<Pet?, String>((ref, petId) {
  ref.watch(currentUserProvider
      .select((u) => u?.id)); // 계정 전환 시 재평가 (detail/edit stale 방지)
  return ref.watch(petListProvider).where((pet) => pet.id == petId).firstOrNull;
});

/// 체중 기록 조회 (family provider)
final weightLogsProvider =
    StateNotifierProvider.family<WeightLogsNotifier, List<WeightLog>, String>(
  (ref, petId) {
    final repo = ref.watch(petRepositoryProvider);
    return WeightLogsNotifier(repo, petId);
  },
);

class WeightLogsNotifier extends StateNotifier<List<WeightLog>> {
  final PetRepository _repo;
  final String _petId;

  WeightLogsNotifier(this._repo, this._petId) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repo.getWeightLogs(_petId);
  }

  Future<void> add(WeightLog log) async {
    await _repo.addWeightLog(log);
    refresh();
  }

  Future<void> delete(String id) async {
    await _repo.deleteWeightLog(id);
    refresh();
  }
}

/// 펫 이벤트 (전체) — family provider
final petEventsProvider =
    StateNotifierProvider.family<PetEventsNotifier, List<PetEvent>, String>(
  (ref, petId) {
    final repo = ref.watch(petEventRepositoryProvider);
    return PetEventsNotifier(repo, petId);
  },
);

class PetEventsNotifier extends StateNotifier<List<PetEvent>> {
  final PetEventRepository _repo;
  final String _petId;

  PetEventsNotifier(this._repo, this._petId) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repo.getEvents(_petId);
  }

  Future<void> add(PetEvent event) async {
    await _repo.addEvent(event);
    refresh();
  }

  Future<void> delete(String id) async {
    await _repo.deleteEvent(id);
    refresh();
  }
}

/// 펫 미디어 — family provider
final petMediaProvider =
    AsyncNotifierProvider.family<PetMediaNotifier, List<MediaItem>, String>(
  PetMediaNotifier.new,
);

class PetMediaNotifier extends FamilyAsyncNotifier<List<MediaItem>, String> {
  @override
  Future<List<MediaItem>> build(String arg) async {
    ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 전환 시에만 재build
    final repo = ref.watch(mediaRepositoryProvider);
    return repo.getMedia(arg);
  }

  Future<void> delete(String mediaId) async {
    final repo = ref.read(mediaRepositoryProvider);
    await repo.deleteMedia(mediaId);
    ref.invalidateSelf();
  }
}
