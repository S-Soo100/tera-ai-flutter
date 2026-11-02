import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/env_alert.dart';

/// `alerts` 실시간 구독을 연다. [onRow]는 INSERT/UPDATE의 새 행, [onRejoined]는
/// 끊겼다 다시 붙었을 때. 돌려준 함수로 닫는다.
///
/// 저장소가 채널을 직접 만들지 않는 이유: 망 복귀·앱 복귀 재구독
/// (`bindResilientChannel`)은 **구독하는 provider의 Ref** 수명에 묶여야 한다.
/// 운영은 `openEnvAlertsProvider`가, 테스트는 가짜 구독이 넘긴다.
typedef EnvAlertSubscribe = VoidCallback Function(
  String deviceId, {
  required void Function(Map<String, dynamic> row) onRow,
  required VoidCallback onRejoined,
});

/// 서버 v4 실시간 판정(`alerts` env_*)의 열린 행 — 읽기 전용.
///
/// RLS `own alerts select`로 자기 기기 행만 보인다(G1). 판정·종료는 서버가 한다.
class EnvAlertRepository {
  EnvAlertRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'alerts';

  /// 기기의 열린 env_* 행. v4가 아닌 행은 [EnvAlert.fromRow]가 다시 거른다.
  Future<List<EnvAlert>> fetchOpen(String deviceId) async {
    final rows = await _client
        .from(_table)
        .select('*')
        .eq('device_id', deviceId)
        .isFilter('resolved_at', null)
        .like('kind', r'env\_%');
    return [
      for (final row in (rows as List).whereType<Map<String, dynamic>>())
        if (EnvAlert.fromRow(row) case final EnvAlert a when a.isOpen) a,
    ];
  }

  /// 열린 행 목록 스트림 — 지표별 최신 1개, 경고 먼저([EnvAlert.openLatestPerMetric]).
  ///
  /// 처음 조회 → 이후 실시간 INSERT/UPDATE를 반영한다. **재합류하면 처음
  /// 조회를 다시 해 목록을 통째로 바꾼다** — 끊긴 사이 종료된 행이 남지 않게
  /// (Review Focus 1). 조회가 진행 중에 온 실시간 행은 조회 결과 위에 다시
  /// 얹어 잃지 않는다. 처음 조회가 실패하면 오류를 내보내고, 다음 재합류에서
  /// 다시 맞춘다. 같은 목록은 다시 내보내지 않는다.
  Stream<List<EnvAlert>> watchOpen(
    String deviceId, {
    required EnvAlertSubscribe subscribe,
  }) {
    final controller = StreamController<List<EnvAlert>>();
    final open = <String, EnvAlert>{};
    // 진행 중인 조회 이후 실시간으로 받은 행(id → 행, 종료면 resolvedAt 있음).
    final sinceFetch = <String, EnvAlert>{};
    var loaded = false;
    var gen = 0;
    var closed = false;
    List<EnvAlert>? last;

    void emit() {
      if (closed || !loaded) return;
      final list = EnvAlert.openLatestPerMetric(open.values);
      if (last != null && listEquals(last, list)) return;
      last = list;
      controller.add(list);
    }

    void apply(EnvAlert a) {
      if (a.isOpen) {
        open[a.id] = a;
      } else {
        open.remove(a.id);
      }
    }

    Future<void> refetch() async {
      final mine = ++gen;
      sinceFetch.clear();
      try {
        final rows = await fetchOpen(deviceId);
        if (closed || mine != gen) return;
        open
          ..clear()
          ..addEntries(rows.map((a) => MapEntry(a.id, a)));
        sinceFetch.values.forEach(apply);
        sinceFetch.clear();
        loaded = true;
        emit();
      } catch (e, st) {
        if (closed || mine != gen) return;
        if (!loaded) controller.addError(e, st);
      }
    }

    void onRow(Map<String, dynamic> row) {
      if (closed) return;
      final device = row['device_id'];
      if (device != null && device.toString() != deviceId) return;
      final a = EnvAlert.fromRow(row);
      if (a == null) return;
      sinceFetch[a.id] = a;
      apply(a);
      emit();
    }

    // 구독을 먼저 열고 조회한다 — 조회와 구독 사이에 생긴 행을 놓치지 않게.
    final close = subscribe(
      deviceId,
      onRow: onRow,
      onRejoined: () => unawaited(refetch()),
    );
    unawaited(refetch());

    controller.onCancel = () {
      closed = true;
      close();
    };
    return controller.stream;
  }
}

final envAlertRepositoryProvider = Provider.autoDispose<EnvAlertRepository>(
    (ref) => EnvAlertRepository(ref.watch(supabaseClientProvider)));
