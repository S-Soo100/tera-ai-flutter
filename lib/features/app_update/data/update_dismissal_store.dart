import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 권장 업데이트 창에서 [나중에]를 직접 누른 빌드 번호. 같은 `latest_build`에는
/// 권장 창을 다시 띄우지 않는다. **기기 단위**라 로그아웃 때 지우지 않는다
/// (계정 데이터가 아니라 이 폰의 앱 버전에 대한 기억).
abstract class UpdateDismissalStore {
  int? load();
  Future<void> save(int build);
}

/// Hive `app_settings` 박스의 `update_dismissed_build` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다. 안 열려 있으면(테스트 등) 기억 없이
/// 동작하고 저장은 건너뛴다 — 여기서 박스를 열지 않는다.
class HiveUpdateDismissalStore implements UpdateDismissalStore {
  const HiveUpdateDismissalStore();

  static const boxName = 'app_settings';
  static const key = 'update_dismissed_build';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  int? load() {
    final value = _box?.get(key);
    return value is int ? value : null;
  }

  @override
  Future<void> save(int build) async {
    final box = _box;
    if (box == null) return;
    await box.put(key, build);
  }
}

final updateDismissalStoreProvider =
    Provider<UpdateDismissalStore>((ref) => const HiveUpdateDismissalStore());
