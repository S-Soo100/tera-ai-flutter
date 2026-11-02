import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

/// 온습도 이탈 알림 푸시 수신 설정(v4 1-5, 2026-11-02 D2 — **계정 단위**).
///
/// 꺼도 기록은 남는다 — 서버가 `app_notifications`는 쌓고 outbox(푸시 발송)만
/// 건너뛴다. 끈 뒤 새로 생기는 알림부터 적용된다. 화면 카드·알림함은 그대로.
class EnvAlertPrefs {
  const EnvAlertPrefs({required this.temp, required this.humid});

  /// 행이 없으면 모두 켬(서버 기본값과 같다).
  static const EnvAlertPrefs allOn = EnvAlertPrefs(temp: true, humid: true);

  /// 온도 이탈 알림(`env_temp`).
  final bool temp;

  /// 습도 이탈 알림(`env_humid`).
  final bool humid;

  EnvAlertPrefs copyWith({bool? temp, bool? humid}) =>
      EnvAlertPrefs(temp: temp ?? this.temp, humid: humid ?? this.humid);

  @override
  bool operator ==(Object other) =>
      other is EnvAlertPrefs && other.temp == temp && other.humid == humid;

  @override
  int get hashCode => Object.hash(temp, humid);

  @override
  String toString() => 'EnvAlertPrefs(temp: $temp, humid: $humid)';
}

/// 앱 Supabase `public.notification_preferences`
/// (`supabase/migrations/20261102000000_env_alert_preferences.sql`).
///
/// 한 저장소 = 한 계정([userId] 고정). 계정이 바뀌면 provider가 새 저장소를
/// 만든다 — 호출 시점에 현재 계정을 다시 읽지 않는 이유는, 전환 직전에 시작한
/// 토글이 새 계정 행에 쓰이는 일을 막기 위해서다(RLS도 막지만 앞에서 막는다).
class EnvAlertPrefsRepository {
  EnvAlertPrefsRepository(this._client,
      {required this.userId, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final String userId;
  final DateTime Function() _now;

  static const String _table = 'notification_preferences';

  /// 행이 없으면 [EnvAlertPrefs.allOn]. 값이 bool이 아니면 켬으로 본다
  /// (NOT NULL 열이라 정상 경로에선 없다 — 안전 알림이라 끄는 쪽으로 추정하지 않는다).
  Future<EnvAlertPrefs> load() async {
    final rows = await _client
        .from(_table)
        .select('env_temp,env_humid')
        .eq('user_id', userId)
        .limit(1);
    final list = (rows as List).whereType<Map<String, dynamic>>().toList();
    if (list.isEmpty) return EnvAlertPrefs.allOn;
    final row = list.first;
    final temp = row['env_temp'];
    final humid = row['env_humid'];
    return EnvAlertPrefs(
      temp: temp is bool ? temp : true,
      humid: humid is bool ? humid : true,
    );
  }

  Future<void> setTemp(bool on) => _upsert('env_temp', on);

  Future<void> setHumid(bool on) => _upsert('env_humid', on);

  /// **필드 하나씩** upsert — 두 값을 통째로 보내면 빠른 연속 토글이 서로를
  /// 덮어쓴다. 행이 없으면 INSERT(보내지 않은 열은 DEFAULT true), 있으면 보낸
  /// 열만 UPDATE. `.select()` 금지(return=minimal — 결과 행이 필요 없다).
  Future<void> _upsert(String column, bool on) async {
    await _client.from(_table).upsert({
      'user_id': userId,
      column: on,
      'updated_at': _now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}

/// 계정별 저장소. 계정 id는 호출부(`envAlertPrefsProvider`)가 select-watch로 넘긴다.
final envAlertPrefsRepositoryProvider = Provider.autoDispose
    .family<EnvAlertPrefsRepository, String>((ref, userId) =>
        EnvAlertPrefsRepository(ref.watch(supabaseClientProvider),
            userId: userId));
