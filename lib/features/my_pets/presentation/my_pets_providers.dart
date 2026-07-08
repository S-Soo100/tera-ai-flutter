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

/// Pet 목록 — 인증 시 Supabase, 미인증 시 Hive
final petListProvider = StateNotifierProvider<PetListNotifier, List<Pet>>((ref) {
  final localRepo = ref.watch(petRepositoryProvider);
  final supabaseRepo = ref.watch(supabasePetRepositoryProvider);
  return PetListNotifier(localRepo, supabaseRepo);
});

class PetListNotifier extends StateNotifier<List<Pet>> {
  final PetRepository _localRepo;
  final SupabasePetRepository? _supabaseRepo;

  PetListNotifier(this._localRepo, this._supabaseRepo) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      if (_useCloud) {
        // 클라우드 모드: Supabase에서 동기화하여 로컬 캐시 갱신
        await syncFromRemote();
      } else {
        // 미인증: 이전 계정 클라우드 캐시가 'pets' 박스에 잔존 → 비우고 빈 목록 (프라이버시)
        await _localRepo.clearPets();
        refresh();
      }
    } catch (_) {
      // sync 실패 시 uncaught async 예외 방지 (완전한 로딩/에러 UI는 후속 — AsyncNotifier 전환 필요)
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

  /// 로그인 후 Supabase에서 데이터 동기화
  Future<void> syncFromRemote() async {
    if (_useCloud) {
      await _supabaseRepo!.syncFromRemote();
      refresh();
    }
  }
}

/// 단일 Pet 조회 (family provider)
final petDetailProvider = Provider.family<Pet?, String>((ref, petId) {
  ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 전환 시 재평가 (detail/edit stale 방지)
  final repo = ref.watch(petRepositoryProvider);
  return repo.getPet(petId);
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
