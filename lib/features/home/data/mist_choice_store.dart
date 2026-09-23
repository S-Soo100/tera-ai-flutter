import 'package:hive/hive.dart';

import '../domain/mist_duration.dart';

/// 분무 "직전 분사 시간" 저장소 — 시트를 다시 열면 마지막으로 고른 칩이
/// 선택돼 있다. [FanChoiceStore]와 같은 Widget → Provider → Repository 체인.
///
/// **미저장 기본은 5초**(2026-09-23 사용자 결정) — load가 기본값까지 책임진다.
abstract class MistChoiceStore {
  /// [deviceId] 기기의 직전 선택. 저장된 적 없으면 [MistDuration.defaultValue].
  MistDuration load(String deviceId);

  Future<void> save(String deviceId, MistDuration duration);
}

/// Hive `app_settings` 박스의 `home_mist_last_choice_<deviceId>` 키(밀리초).
///
/// 박스는 `main.dart`가 앱 기동 시 연다. 안 열려 있으면(테스트 등) 기본값으로
/// 동작하고 저장은 건너뛴다 — 여기서 박스를 열지 않는다.
class HiveMistChoiceStore implements MistChoiceStore {
  const HiveMistChoiceStore();

  static const boxName = 'app_settings';

  static String keyFor(String deviceId) => 'home_mist_last_choice_$deviceId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  MistDuration load(String deviceId) {
    final raw = _box?.get(keyFor(deviceId));
    return MistDuration.tryFromMilliseconds(raw is int ? raw : null) ??
        MistDuration.defaultValue;
  }

  @override
  Future<void> save(String deviceId, MistDuration duration) async {
    final box = _box;
    if (box == null) return;
    await box.put(keyFor(deviceId), duration.milliseconds);
  }
}
