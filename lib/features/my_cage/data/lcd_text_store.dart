import 'package:hive/hive.dart';

/// 기기별로 이 폰이 마지막에 **성공 전송한** LCD 문구 — 홈 "LCD 표시" 줄
/// 오른쪽과 LCD 입력 화면의 처음 값에 쓴다(2026-10-06).
///
/// 서버는 LCD 문구 원문을 남기지 않는다(`commands.lcd_bitmap`엔 비트맵만,
/// `devices`·`device_settings`에도 컬럼 없음 — 요청서
/// `docs/handoffs/2026-10-06-lcd-text-server-request.md`). 전엔 세션 메모리라
/// 앱을 다시 켜면 기기 ID로 돌아가 "LCD엔 바꾼 이름, 앱엔 다른 이름"이
/// 됐다(고객 문의). 다른 폰·웹에서 바꿨으면 옛 문구일 수 있다.
abstract class LcdTextStore {
  String? load(String account, String deviceId);
  Future<void> save(String account, String deviceId, String text);

  /// 지금 값부터 흘리고, 바뀔 때마다 다시 흘린다.
  Stream<String?> watch(String account, String deviceId);

  /// 로그아웃 때 모든 계정의 문구를 지운다(CLAUDE.md 3층 계정 격리 ③).
  Future<void> clearAll();
}

/// Hive `app_settings` 박스의 `device_lcd_<계정>_<기기 행 id>` 키.
/// 박스는 `main.dart`가 연다 — 안 열려 있으면 모른다고 답한다.
class HiveLcdTextStore implements LcdTextStore {
  const HiveLcdTextStore();

  static const boxName = 'app_settings';
  static const _prefix = 'device_lcd_';

  static String keyFor(String account, String deviceId) =>
      '$_prefix${account}_$deviceId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  static String? _parse(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  @override
  String? load(String account, String deviceId) =>
      _parse(_box?.get(keyFor(account, deviceId)));

  @override
  Future<void> save(String account, String deviceId, String text) async {
    await _box?.put(keyFor(account, deviceId), text);
  }

  @override
  Future<void> clearAll() async {
    final box = _box;
    if (box == null) return;
    await box.deleteAll(box.keys
        .where((k) => k is String && k.startsWith(_prefix))
        .toList());
  }

  @override
  Stream<String?> watch(String account, String deviceId) async* {
    yield load(account, deviceId);
    final box = _box;
    if (box == null) return;
    yield* box
        .watch(key: keyFor(account, deviceId))
        .map((event) => _parse(event.value));
  }
}
