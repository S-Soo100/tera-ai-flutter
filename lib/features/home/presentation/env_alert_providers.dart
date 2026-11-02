import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/env_alert_repository.dart';
import '../domain/env_alert.dart';
import 'home_control_providers.dart';

/// 홈 세트 기기의 열린 v4 실시간 이탈(온습도 상세 카드 전용).
///
/// `deviceListProvider`·`camerasProvider` 같은 공용 목록에 넣지 않는다 — 그
/// 목록이 재조회될 때마다 이 구독이 흔들리고, 반대로 알림 행 변화가 목록
/// 화면을 다시 그리게 된다(2026-09-19 재조회 깜빡임 교훈). 화면이 보는 동안만
/// 산다(autoDispose).
final openEnvAlertsProvider =
    StreamProvider.autoDispose<List<EnvAlert>>((ref) {
  // 기기 id만 본다 — 같은 기기의 재조회(로딩↔데이터)로 채널을 다시 열지 않는다.
  final device = ref.watch(currentDeviceIdProvider
      .select((a) => (hasValue: a.hasValue, id: a.valueOrNull)));
  // 기기를 아직 모르면 로딩으로 둔다(값을 내보내지 않는 스트림).
  if (!device.hasValue) return const Stream<List<EnvAlert>>.empty();
  final deviceId = device.id;
  if (deviceId == null) return Stream.value(const <EnvAlert>[]);
  // 계정 id만 select-watch — 계정이 바뀌면 다시 구독한다(stale 방지).
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const <EnvAlert>[]);

  final supabase = ref.watch(supabaseClientProvider);
  return ref.watch(envAlertRepositoryProvider).watchOpen(
    deviceId,
    subscribe: (id, {required onRow, required onRejoined}) {
      final channel = bindResilientChannel(
        ref,
        supabase: supabase,
        name: 'env-alerts-$id',
        configure: (c) {
          final filter = PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: id,
          );
          return c
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'alerts',
                filter: filter,
                callback: (payload) => onRow(payload.newRecord),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'alerts',
                filter: filter,
                callback: (payload) => onRow(payload.newRecord),
              );
        },
        // 끊긴 사이 종료·생성된 행을 놓쳤을 수 있다 — 처음 조회를 다시 한다.
        onRejoined: onRejoined,
      );
      return channel.dispose;
    },
  );
});
