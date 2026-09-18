import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Explicit opt-in callers store only after WIFI_OK. Legacy global data is
/// deliberately never read: credentials are isolated by account and SSID.
class WifiCredentialsStore {
  WifiCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  final Map<String, Future<void>> _writes = {};
  static String accountKey(String accountId) =>
      'wifi_credentials_v2_${base64Url.encode(utf8.encode(accountId))}';

  Future<Map<String, String>> readAll({required String accountId}) async {
    if (accountId.isEmpty) return {};
    try {
      return decode(await _storage.read(key: accountKey(accountId)));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String ssid, String password, {required String accountId}) {
    if (accountId.isEmpty || ssid.isEmpty) return Future.value();
    final next = (_writes[accountId] ?? Future<void>.value()).then((_) async {
      try {
        final all = await readAll(accountId: accountId);
        all[ssid] = password;
        await _storage.write(
            key: accountKey(accountId), value: jsonEncode(all));
      } catch (_) {
        /* Optional convenience must not turn WIFI_OK into failure. */
      }
    });
    _writes[accountId] = next;
    return next;
  }

  static Map<String, String> decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map<String, Object?>) return {};
      return {
        for (final entry in parsed.entries)
          if (entry.value case final String value) entry.key: value
      };
    } catch (_) {
      return {};
    }
  }
}
