import '../../my_cage/domain/device.dart';
import '../../my_cage/domain/enclosure.dart';
import '../../my_cage/domain/terra_camera.dart';
import '../../my_pets/domain/pet.dart';
import '../domain/enclosure_set.dart';

/// 사육장 세트를 네 저장소에서 조립한다.
///
/// enclosures/devices/cameras는 Supabase(RLS로 본인 것만), pets는 Hive 로컬이라
/// 소스가 이질적이다. 그래서 loader를 주입받아 네트워크 없이 테스트 가능하게 둔다
/// (`MotionClipRepository`의 ActivityRowsLoader와 같은 관례).
///
/// 기기 조회는 **부분 실패를 허용**한다 — 캠 서비스가 죽어도 사육장 제어는 계속
/// 보여야 하기 때문. 반면 사육장 목록 조회 실패는 그대로 throw한다: 세트가 정말
/// 없는 것과 조회가 실패한 것을 빈 화면으로 뭉개면 사용자가 오해한다.
class EnclosureSetRepository {
  final Future<List<Enclosure>> Function() _loadEnclosures;
  final Future<List<Device>> Function() _loadDevices;
  final Future<List<TerraCamera>> Function() _loadCameras;
  final List<Pet> Function() _loadPets;

  EnclosureSetRepository({
    required Future<List<Enclosure>> Function() loadEnclosures,
    required Future<List<Device>> Function() loadDevices,
    required Future<List<TerraCamera>> Function() loadCameras,
    required List<Pet> Function() loadPets,
  })  : _loadEnclosures = loadEnclosures,
        _loadDevices = loadDevices,
        _loadCameras = loadCameras,
        _loadPets = loadPets;

  /// 사육장 생성순으로 정렬된 세트 목록.
  Future<List<EnclosureSet>> listSets() async {
    // 사육장은 앵커라 실패를 삼키지 않는다.
    final enclosures = await _loadEnclosures();
    if (enclosures.isEmpty) return const [];

    // 기기 조회는 병렬 + 부분 실패 허용. 레코드 `.wait`로 받아 캐스팅을 없앤다
    // (List<Object> 캐스팅은 타입 실수를 런타임까지 숨긴다).
    final (devices, cameras) = await (
      _safe(_loadDevices, const <Device>[]),
      _safe(_loadCameras, const <TerraCamera>[]),
    ).wait;
    final pets = _loadPets();

    final byEnclosure = [...enclosures]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return [
      for (final e in byEnclosure)
        EnclosureSet(
          enclosure: e,
          device: _firstWhereOrNull(devices, (d) => d.enclosureId == e.id),
          camera: _firstWhereOrNull(cameras, (c) => c.enclosureId == e.id),
          pet: _firstWhereOrNull(pets, (p) => p.enclosureId == e.id),
        ),
    ];
  }

  /// 기기 조회 1건의 실패를 [fallback]으로 흡수한다.
  static Future<List<T>> _safe<T>(
    Future<List<T>> Function() load,
    List<T> fallback,
  ) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  static T? _firstWhereOrNull<T>(List<T> items, bool Function(T) test) {
    for (final it in items) {
      if (test(it)) return it;
    }
    return null;
  }
}
