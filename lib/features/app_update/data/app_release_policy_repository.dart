import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/update_policy.dart';

/// 업데이트 기준(`app_release_policy`) 조회.
abstract class AppReleasePolicyRepository {
  /// [platform](`android`/`ios`) 한 줄. 실패·없음·형식 오류는 모두 null —
  /// 던지지 않는다(호출부는 이전 상태를 유지한다).
  Future<UpdatePolicy?> fetch(String platform);
}

/// Supabase 직결 읽기. 표는 anon·authenticated SELECT만 열려 있어 로그인
/// 전에도 읽힌다(`supabase/migrations/20261116000000_app_release_policy.sql`).
class SupabaseAppReleasePolicyRepository implements AppReleasePolicyRepository {
  const SupabaseAppReleasePolicyRepository(this._client,
      {this.timeout = const Duration(seconds: 5)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<UpdatePolicy?> fetch(String platform) async {
    try {
      final row = await _client
          .from('app_release_policy')
          .select('min_build, latest_build, latest_version, store_url')
          .eq('platform', platform)
          .maybeSingle()
          .timeout(timeout);
      if (row == null) return null;
      return UpdatePolicy.fromJson(row);
    } catch (e) {
      debugPrint('[app-update] policy fetch failed: ${e.runtimeType}');
      return null;
    }
  }
}

final appReleasePolicyRepositoryProvider =
    Provider<AppReleasePolicyRepository>((ref) =>
        SupabaseAppReleasePolicyRepository(ref.watch(supabaseClientProvider)));
