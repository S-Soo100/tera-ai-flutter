import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/device_mode.dart';
import 'package:vivananunt/features/home/domain/enclosure_set.dart';
import 'package:vivananunt/features/my_cage/domain/device.dart';
import 'package:vivananunt/features/my_cage/domain/enclosure.dart';
import 'package:vivananunt/features/my_cage/domain/terra_camera.dart';
import 'package:vivananunt/features/my_pets/domain/pet.dart';

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

  group('DeviceMode 서브탭 가용성 (PRD §3.3)', () {
    test('integrated — 둘 다 활성, 기본은 제어', () {
      expect(DeviceMode.integrated.controlEnabled, isTrue);
      expect(DeviceMode.integrated.timelineEnabled, isTrue);
      expect(DeviceMode.integrated.defaultTab, HomeSubTab.control);
    });

    test('cageOnly — 타임라인 비활성, 기본은 제어', () {
      expect(DeviceMode.cageOnly.controlEnabled, isTrue);
      expect(DeviceMode.cageOnly.timelineEnabled, isFalse);
      expect(DeviceMode.cageOnly.defaultTab, HomeSubTab.control);
    });

    test('camOnly — 제어 비활성, 기본은 타임라인', () {
      expect(DeviceMode.camOnly.controlEnabled, isFalse);
      expect(DeviceMode.camOnly.timelineEnabled, isTrue);
      expect(DeviceMode.camOnly.defaultTab, HomeSubTab.timeline);
    });

    test('none — 둘 다 비활성', () {
      expect(DeviceMode.none.controlEnabled, isFalse);
      expect(DeviceMode.none.timelineEnabled, isFalse);
    });
  });

  group('showsLiveVideo (PRD §3.2)', () {
    test('캠이 있으면 라이브 영역, 없으면 프로필 카드', () {
      expect(DeviceMode.integrated.showsLiveVideo, isTrue);
      expect(DeviceMode.camOnly.showsLiveVideo, isTrue);
      expect(DeviceMode.cageOnly.showsLiveVideo, isFalse);
      expect(DeviceMode.none.showsLiveVideo, isFalse);
    });
  });

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
