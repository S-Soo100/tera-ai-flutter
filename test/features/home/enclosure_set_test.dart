import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/device_mode.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';

Enclosure _enc() => Enclosure(
      id: 'enc-1',
      name: '1번 사육장',
      species: 'crested_gecko',
      createdAt: DateTime(2026, 1, 1),
    );

Device _dev() => const Device(
      id: 'dev-1',
      ownerId: 'u1',
      enclosureId: 'enc-1',
      name: '제어기',
      isOnline: true,
      lastSeenAt: null,
    );

TerraCamera _cam() => TerraCamera(
      id: 'cam-1',
      cameraId: 'p4cam-1',
      name: '캠',
      isOnline: true,
      enclosureId: 'enc-1',
      createdAt: DateTime(2026, 1, 1),
    );

Pet _pet() => Pet(
      id: 'pet-1',
      name: '젤리',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
    );

void main() {
  group('EnclosureSet.mode', () {
    test('캠 + 제어기 → integrated', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: _pet());
      expect(s.mode, DeviceMode.integrated);
    });

    test('제어기만 → cageOnly', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: null, pet: _pet());
      expect(s.mode, DeviceMode.cageOnly);
    });

    test('캠만 → camOnly', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: null, camera: _cam(), pet: _pet());
      expect(s.mode, DeviceMode.camOnly);
    });

    test('둘 다 없음 → none', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: null, camera: null, pet: null);
      expect(s.mode, DeviceMode.none);
    });
  });

  // 구 서브탭·상단 분기 게터(controlEnabled·defaultTab·showsLiveVideo)는
  // 2026-09-04 정리로 삭제 — 홈 단일 스크롤 개편(2026-09-02)으로 소비처가
  // 사라졌다. DeviceMode 분류 자체는 후속 화면 분기 근거로 존치.

  group('EnclosureSet 표시 라벨', () {
    test('개체가 있으면 "개체명 (사육장명)"', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: _pet());
      expect(s.displayLabel, '젤리 (1번 사육장)');
    });

    test('개체가 없으면 사육장명만', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: null);
      expect(s.displayLabel, '1번 사육장');
    });
  });
}
