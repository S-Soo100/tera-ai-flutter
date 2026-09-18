import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

abstract interface class PushPreferences {
  /// 맥락 프리팝업(하이라이트·커뮤니티)을 이미 물었나 — 주제별 1회.
  bool promptAsked(String topic);
  Future<void> markPromptAsked(String topic);
  Future<String> installationId();
}

class HivePushPreferences implements PushPreferences {
  Future<String>? _installation;
  /// 박스가 안 열려 있으면(위젯 테스트) "이미 물음"으로 본다 — 팝업을 띄우지
  /// 않는 쪽이 안전하다. 앱은 main에서 `app_settings`를 항상 연다.
  Box<dynamic>? get _settings =>
      Hive.isBoxOpen('app_settings') ? Hive.box('app_settings') : null;

  @override
  bool promptAsked(String topic) {
    final box = _settings;
    return box == null || box.get('push_prompt_asked_$topic') == true;
  }

  @override
  Future<void> markPromptAsked(String topic) async =>
      _settings?.put('push_prompt_asked_$topic', true);

  @override
  Future<String> installationId() =>
      _installation ??= _loadInstallation().catchError((Object error) {
        _installation = null;
        throw error;
      });

  Future<String> _loadInstallation() async {
    final box = Hive.box('app_settings');
    final existing = box.get('push_installation_id');
    if (existing is String && Uuid.isValidUUID(fromString: existing)) {
      return existing;
    }
    final id = const Uuid().v4();
    await box.put('push_installation_id', id);
    return id;
  }
}
