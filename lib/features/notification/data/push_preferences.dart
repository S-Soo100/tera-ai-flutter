import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

abstract interface class PushPreferences {
  bool get explanationSeen;
  Future<void> markExplanationSeen();
  Future<String> installationId();
}

class HivePushPreferences implements PushPreferences {
  Future<String>? _installation;
  @override
  bool get explanationSeen =>
      Hive.box('app_settings').get('push_explanation_seen') == true;

  @override
  Future<void> markExplanationSeen() =>
      Hive.box('app_settings').put('push_explanation_seen', true);

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
