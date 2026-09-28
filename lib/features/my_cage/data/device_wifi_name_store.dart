import 'package:hive/hive.dart';

import '../domain/pair_target_kind.dart';

/// 기기별로 마지막에 붙인 Wi-Fi 이름 — 기기 상세 "Wi-Fi 바꾸기" 줄 오른쪽에
/// 보인다(2026-09-28).
///
/// 서버는 기기가 어느 Wi-Fi에 붙었는지 모른다(`devices`·`cameras`에 SSID가 없고
/// 펌웨어도 보고하지 않는다). 그래서 이 폰이 등록·Wi-Fi 변경에 성공했을 때
/// 보낸 이름을 기억한다 — 다른 폰에서 붙였거나 이 기능 전에 붙인 기기는 모른다.
/// 비밀번호는 여기 두지 않는다(`WifiCredentialsStore`가 보안 저장소에 둔다).
abstract class DeviceWifiNameStore {
  String? load(String account, PairTargetKind kind, String id);
  Future<void> save(
      String account, PairTargetKind kind, String id, String ssid);

  /// 지금 값부터 흘리고, 바뀔 때마다 다시 흘린다.
  Stream<String?> watch(String account, PairTargetKind kind, String id);
}

/// Hive `app_settings` 박스의 `device_wifi_<계정>_<종류>_<행 id>` 키.
/// 박스는 `main.dart`가 연다 — 안 열려 있으면 모른다고 답한다.
class HiveDeviceWifiNameStore implements DeviceWifiNameStore {
  const HiveDeviceWifiNameStore();

  static const boxName = 'app_settings';

  static String keyFor(String account, PairTargetKind kind, String id) =>
      'device_wifi_${account}_${kind.name}_$id';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  String? load(String account, PairTargetKind kind, String id) {
    final raw = _box?.get(keyFor(account, kind, id));
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  @override
  Future<void> save(
      String account, PairTargetKind kind, String id, String ssid) async {
    await _box?.put(keyFor(account, kind, id), ssid);
  }

  @override
  Stream<String?> watch(String account, PairTargetKind kind, String id) async* {
    yield load(account, kind, id);
    final box = _box;
    if (box == null) return;
    yield* box.watch(key: keyFor(account, kind, id)).map((event) {
      final value = event.value;
      return value is String && value.isNotEmpty ? value : null;
    });
  }
}
