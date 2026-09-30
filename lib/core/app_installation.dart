import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// 이 앱 설치의 고정 ID(Hive `app_settings`). 푸시 기기 등록과 라이브 시청자
/// 판정(2026-09-30)이 같은 값을 쓴다 — 설치 하나에 ID 하나.
///
/// 키가 `push_installation_id`인 건 푸시가 먼저 쓰던 역사적 이름이다(바꾸면
/// 기존 설치의 푸시 등록이 새 기기로 보인다). 박스가 안 열려 있으면 던지고,
/// 실패는 기억하지 않아 다음 호출이 다시 시도한다.
Future<String> appInstallationId() =>
    _installation ??= _load().catchError((Object error) {
      _installation = null;
      throw error;
    });

Future<String>? _installation;

const _kInstallationKey = 'push_installation_id';

Future<String> _load() async {
  final box = Hive.box('app_settings');
  final existing = box.get(_kInstallationKey);
  if (existing is String && Uuid.isValidUUID(fromString: existing)) {
    return existing;
  }
  final id = const Uuid().v4();
  await box.put(_kInstallationKey, id);
  return id;
}
