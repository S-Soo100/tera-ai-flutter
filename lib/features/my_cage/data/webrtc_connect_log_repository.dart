import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/webrtc_connect_log.dart';

/// 라이브 연결 결과를 `webrtc_connect_logs`에 직접 INSERT한다(2026-09-23).
///
/// terra-server REST가 아니라 Supabase 직결인 이유(백엔드 회신 §1.1): 기록할
/// 순간은 대개 네트워크가 나쁜 순간이라 한 단계라도 덜 거쳐야 남는다.
/// RLS는 본인 INSERT만 허용, 읽기는 운영자(service_role) 전용이다.
///
/// **절대 던지지 않는다** — 기록 실패가 라이브 흐름을 건드리면 안 된다.
class WebRtcConnectLogRepository {
  WebRtcConnectLogRepository(this._supabase);

  final SupabaseClient _supabase;

  static Future<String?>? _version;

  Future<void> insert(WebRtcConnectLog log) async {
    try {
      final version = await (_version ??= _readVersion());
      // `.select()`를 붙이지 말 것 — SELECT 정책이 없어 RETURNING이 RLS
      // 위반(42501)으로 행 전체가 거부된다(2026-09-23 운영 DB로 확인).
      await _supabase.from('webrtc_connect_logs').insert(log.toRow(
            appVersion: version,
            platform: defaultTargetPlatform.name.toLowerCase(),
          ));
    } catch (e) {
      debugPrint('[webrtc-log] insert failed: $e');
    }
  }

  static Future<String?> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
