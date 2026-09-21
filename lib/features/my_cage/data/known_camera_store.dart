import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/device_add_flow.dart';

/// 이 폰이 등록한 카메라 기억 — BLE 주소 → `cameras.id` (2026-09-21).
///
/// 카메라 펌웨어는 JWT를 받으면 매번 새 camera_id로 등록한다. 그래서 이미
/// 등록된 카메라인지 앱이 기억해 두고, 맞으면 JWT 없이 Wi-Fi만 보낸다.
/// 카메라에 등록 상태를 물어볼 BLE 명령은 없다.
///
/// - Android의 BLE 주소는 칩 MAC이라 고정이다. iOS는 폰마다 다른 UUID라 같은
///   폰에서만 알아본다 — 다른 폰·재설치면 한 번 더 등록된다(서버 hw_id 전까지).
/// - 광고 이름(`FB2_P4_CAM_<MAC 하위 2바이트>`)도 같아야 같은 카메라로 본다.
/// - 로그아웃해도 지우지 않는다. 계정별 키라 다른 계정에 새지 않는다.
abstract class KnownCameraStore {
  String? load(String account, DeviceAddCandidate candidate);
  Future<void> save(String account, DeviceAddCandidate candidate, String id);
  Future<void> forget(String account, DeviceAddCandidate candidate);
}

/// Hive `app_settings` 박스의 `known_camera_<계정>_<BLE 주소>` 키.
/// 박스는 `main.dart`가 연다 — 안 열려 있으면 모른다고 답한다.
class HiveKnownCameraStore implements KnownCameraStore {
  const HiveKnownCameraStore();

  static const boxName = 'app_settings';

  static String keyFor(String account, String physicalId) =>
      'known_camera_${account}_$physicalId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  String? load(String account, DeviceAddCandidate candidate) {
    final raw = _box?.get(keyFor(account, candidate.physicalId));
    if (raw is! String) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final id = map['id'];
      if (map['name'] != candidate.name || id is! String || id.isEmpty) {
        return null;
      }
      return id;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(
      String account, DeviceAddCandidate candidate, String id) async {
    await _box?.put(keyFor(account, candidate.physicalId),
        jsonEncode({'id': id, 'name': candidate.name}));
  }

  @override
  Future<void> forget(String account, DeviceAddCandidate candidate) async {
    await _box?.delete(keyFor(account, candidate.physicalId));
  }
}
