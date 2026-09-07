import '../../my_cage/domain/device.dart';
import '../../my_cage/domain/enclosure.dart';
import '../../my_cage/domain/terra_camera.dart';
import '../../my_pets/domain/pet.dart';
import 'device_mode.dart';

/// PRD의 최소 단위 "사육장 세트".
///
/// 앵커는 [enclosure]. 캠([camera])·IoT 제어기([device])·개체([pet])가 여기에
/// 0~1개씩 붙는다 (PRD §2 전제: 사육장 1 : 캠 1 : 개체 1).
///
/// 주의: [device]는 사육장 IoT 제어기이고 [camera]가 펫캠이다. terra-server
/// 스키마의 `devices` / `cameras`가 각각 대응한다.
class EnclosureSet {
  final Enclosure enclosure;
  final Device? device;
  final TerraCamera? camera;
  final Pet? pet;

  const EnclosureSet({
    required this.enclosure,
    required this.device,
    required this.camera,
    required this.pet,
  });

  String get id => enclosure.id;

  DeviceMode get mode {
    final hasCam = camera != null;
    final hasDev = device != null;
    if (hasCam && hasDev) return DeviceMode.integrated;
    if (hasDev) return DeviceMode.cageOnly;
    if (hasCam) return DeviceMode.camOnly;
    return DeviceMode.none;
  }

  /// 헤더 드롭다운 라벨. PRD 목업 문구 `젤리 (1번 사육장)` 형식.
  String get displayLabel =>
      pet == null ? enclosure.name : '${pet!.name} (${enclosure.name})';
}
