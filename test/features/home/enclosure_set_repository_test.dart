import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/data/enclosure_set_repository.dart';
import 'package:vivananunt/features/home/domain/device_mode.dart';
import 'package:vivananunt/features/my_cage/domain/device.dart';
import 'package:vivananunt/features/my_cage/domain/enclosure.dart';
import 'package:vivananunt/features/my_cage/domain/terra_camera.dart';
import 'package:vivananunt/features/my_pets/domain/pet.dart';

Enclosure _enc(String id, String name) =>
    Enclosure(id: id, name: name, createdAt: DateTime(2026, 1, 1));

Device _dev(String id, String? encId) => Device(
      id: id,
      ownerId: 'u1',
      enclosureId: encId,
      name: 'dev',
      isOnline: true,
      lastSeenAt: null,
    );

TerraCamera _cam(String id, String? encId) => TerraCamera(
      id: id,
      cameraId: 'p4cam-$id',
      name: 'cam',
      isOnline: true,
      enclosureId: encId,
      createdAt: DateTime(2026, 1, 1),
    );

Pet _pet(String id, String name, String? encId) => Pet(
      id: id,
      name: name,
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
      enclosureId: encId,
    );

EnclosureSetRepository _repo({
  List<Enclosure> enclosures = const [],
  List<Device> devices = const [],
  List<TerraCamera> cameras = const [],
  List<Pet> pets = const [],
}) =>
    EnclosureSetRepository(
      loadEnclosures: () async => enclosures,
      loadDevices: () async => devices,
      loadCameras: () async => cameras,
      loadPets: () => pets,
    );

void main() {
  group('EnclosureSetRepository.listSets', () {
    test('사육장 없음 → 빈 목록', () async {
      expect(await _repo().listSets(), isEmpty);
    });

    test('캠·제어기·개체가 enclosure_id로 결합된다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', '1번 사육장')],
        devices: [_dev('d1', 'e1')],
        cameras: [_cam('c1', 'e1')],
        pets: [_pet('p1', '젤리', 'e1')],
      ).listSets();

      expect(sets, hasLength(1));
      expect(sets.single.mode, DeviceMode.integrated);
      expect(sets.single.displayLabel, '젤리 (1번 사육장)');
    });

    test('다른 사육장 소속 기기는 섞이지 않는다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A'), _enc('e2', 'B')],
        devices: [_dev('d1', 'e1')],
        cameras: [_cam('c1', 'e2')],
        pets: const [],
      ).listSets();

      expect(sets, hasLength(2));
      expect(sets[0].mode, DeviceMode.cageOnly);
      expect(sets[1].mode, DeviceMode.camOnly);
    });

    test('enclosure_id가 null인 기기는 버린다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A')],
        devices: [_dev('d1', null)],
        cameras: [_cam('c1', null)],
      ).listSets();

      expect(sets.single.mode, DeviceMode.none);
    });

    test('같은 사육장에 기기가 둘이면 첫 번째만 (PRD 1:1 전제)', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A')],
        cameras: [_cam('c1', 'e1'), _cam('c2', 'e1')],
      ).listSets();

      expect(sets.single.camera!.id, 'c1');
    });

    test('정렬은 사육장 생성순 — 세트 순서가 세션마다 흔들리면 안 된다', () async {
      final sets = await _repo(
        enclosures: [
          Enclosure(id: 'e2', name: 'B', createdAt: DateTime(2026, 3, 1)),
          Enclosure(id: 'e1', name: 'A', createdAt: DateTime(2026, 1, 1)),
        ],
      ).listSets();

      expect(sets.map((s) => s.id).toList(), ['e1', 'e2']);
    });

    test('원격 호출 하나가 실패해도 나머지로 조립한다', () async {
      final repo = EnclosureSetRepository(
        loadEnclosures: () async => [_enc('e1', 'A')],
        loadDevices: () async => throw StateError('devices down'),
        loadCameras: () async => [_cam('c1', 'e1')],
        loadPets: () => const [],
      );

      final sets = await repo.listSets();
      expect(sets.single.mode, DeviceMode.camOnly);
    });

    test('사육장 조회 자체가 실패하면 throw — 빈 화면으로 위장하지 않는다', () async {
      final repo = EnclosureSetRepository(
        loadEnclosures: () async => throw StateError('enclosures down'),
        loadDevices: () async => const [],
        loadCameras: () async => const [],
        loadPets: () => const [],
      );

      expect(repo.listSets(), throwsStateError);
    });
  });
}
