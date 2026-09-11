import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// BLE WiFi 프로비저닝에서 성공한 SSID→비밀번호를 기기 보안 저장소에 보관한다.
///
/// - 저장 시점은 WIFI_OK(연결 성공) 수신 후뿐이다 — 실패한(틀린) 비밀번호를
///   남겨 다음 자동채움을 오염시키지 않는다.
/// - 값은 Keychain(iOS)/Keystore(Android) 암호화 저장. 공유기 비밀번호는
///   계정이 아니라 장소(집 공유기)에 속하므로 계정 격리 대상이 아니다.
class WifiCredentialsStore {
  WifiCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'wifi_saved_credentials';

  final FlutterSecureStorage _storage;

  /// 저장된 전체 SSID→비밀번호 맵. 손상·플랫폼 오류 시 빈 맵을 돌려
  /// 자동채움만 포기하고 페어링 흐름은 막지 않는다.
  Future<Map<String, String>> readAll() async {
    try {
      return decode(await _storage.read(key: storageKey));
    } catch (_) {
      return {};
    }
  }

  /// [ssid]의 비밀번호를 저장(같은 SSID는 최신 값으로 덮어쓴다).
  /// 실패해도 조용히 넘어간다 — 저장은 편의 기능이지 페어링 요건이 아니다.
  Future<void> save(String ssid, String password) async {
    final trimmed = ssid.trim();
    if (trimmed.isEmpty || password.isEmpty) return;
    try {
      final all = await readAll();
      all[trimmed] = password;
      await _storage.write(key: storageKey, value: jsonEncode(all));
    } catch (_) {}
  }

  /// 저장 원문(JSON) → SSID→비밀번호 맵. 형식이 어긋나면 빈 맵.
  static Map<String, String> decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return {};
      return {
        for (final entry in parsed.entries)
          if (entry.value is String) entry.key.toString(): entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }
}
