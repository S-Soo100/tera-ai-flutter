import 'package:hive/hive.dart';

import '../domain/player_speed.dart';

/// 영상 재생 배속 저장소 — 한 번 바꾸면 다른 영상과 앱 재시작에도 이어진다
/// (2026-10-30 사용자 결정). 계정이 아니라 이 폰의 설정이라 로그아웃해도 남는다.
abstract class PlayerSpeedStore {
  /// 저장된 배속. 저장된 적 없거나 [kPlayerSpeeds]에 없는 값이면
  /// [kDefaultPlayerSpeed].
  double load();

  Future<void> save(double speed);
}

/// Hive `app_settings` 박스의 `player_speed` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다. 안 열려 있으면(테스트 등) 기본 배속으로
/// 동작하고 저장은 건너뛴다 — 여기서 박스를 열지 않는다.
class HivePlayerSpeedStore implements PlayerSpeedStore {
  const HivePlayerSpeedStore();

  static const boxName = 'app_settings';
  static const key = 'player_speed';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  double load() => normalizePlayerSpeed(_box?.get(key));

  @override
  Future<void> save(double speed) async {
    final box = _box;
    if (box == null) return;
    await box.put(key, speed);
  }
}
