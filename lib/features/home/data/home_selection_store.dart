import 'package:hive/hive.dart';

/// 홈에서 보고 있던 사육장(기기 id) — 앱을 다시 켜도 그 사육장으로 연다
/// (2026-11-05 실기기 QA: 저장하지 않아 매번 기기 목록 첫 사육장이 떴다).
/// 계정마다 따로 기억한다. 이 폰의 설정이라 서버에는 올리지 않는다.
abstract class HomeSelectionStore {
  /// [userId] 계정이 마지막으로 본 사육장 기기 id. 없으면 null.
  String? load(String userId);

  /// null이면 지운다.
  Future<void> save(String userId, String? deviceId);
}

/// Hive `app_settings` 박스의 `home_selected_device_<계정 id>` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다. 안 열려 있으면(테스트 등) 기억 없이
/// 동작하고 저장은 건너뛴다 — 여기서 박스를 열지 않는다.
class HiveHomeSelectionStore implements HomeSelectionStore {
  const HiveHomeSelectionStore();

  static const boxName = 'app_settings';
  static String keyFor(String userId) => 'home_selected_device_$userId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  String? load(String userId) {
    final value = _box?.get(keyFor(userId));
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<void> save(String userId, String? deviceId) async {
    final box = _box;
    if (box == null) return;
    if (deviceId == null) {
      await box.delete(keyFor(userId));
    } else {
      await box.put(keyFor(userId), deviceId);
    }
  }
}
