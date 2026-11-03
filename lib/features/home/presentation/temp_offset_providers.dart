import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/domain/env_thresholds.dart';
import '../../my_cage/data/device_health_repository.dart'
    show RebootCommandState;
import '../../my_cage/data/temp_offset_repository.dart';
import '../../my_cage/domain/device.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/sys_health_controllers.dart'
    show commandRowProvider;

/// 기기가 지금 적용 중인 온도 보정(`devices.temp_offset_c`, 기기 값 ℃). null =
/// 구 펌웨어(보고하지 않음) 또는 없는 기기.
///
/// 먼저 한 번 읽고, 그 기기 행 UPDATE를 구독한다 — 보정 명령을 보내면 기기가 다음
/// telemetry(3초 주기)에 새 값을 보고하고 서버가 이 열을 고친다(서버 회신
/// 2026-11-02 §2, 보통 5초 안). 같은 값 재방출은 걸러 낸다(행은 생존 신호로도
/// 자주 바뀐다).
final deviceOffsetProvider =
    StreamProvider.autoDispose.family<double?, String>((ref, deviceId) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(supabaseModuleControlRepositoryProvider);
  final controller = StreamController<double?>();
  var emitted = false;
  double? last;

  void emit(double? v) {
    if (controller.isClosed || (emitted && v == last)) return;
    emitted = true;
    last = v;
    controller.add(v);
  }

  Future<void> reload() async {
    try {
      emit(await repo.fetchTempOffset(deviceId));
    } catch (e, st) {
      if (!emitted && !controller.isClosed) controller.addError(e, st);
    }
  }

  unawaited(reload());
  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'device-offset-$deviceId',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'devices',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: deviceId),
      callback: (payload) =>
          emit(Device.parseTempOffset(payload.newRecord['temp_offset_c'])),
    ),
    onRejoined: () => unawaited(reload()),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});

/// 보정 토글을 켰지만 아직 저장하지 않은 상태(Figma S45 — 켜도 저장 전엔 보정이
/// 들어가지 않는다). 온습도 설정 화면이 보는 동안만 산다. 보정값 설정에서 첫 진입
/// 취소면 false로 되돌린다(S46).
final tempOffsetToggleDraftProvider =
    StateProvider.autoDispose.family<bool, String>((ref, deviceId) => false);

/// 보정값 설정 화면의 편집값(방향 + 0.1 단위 크기). null = 아직 손대지 않음
/// (저장값 또는 첫 진입 기본 "빼기 0.1"을 보여 준다).
typedef TempOffsetSelection = ({bool subtract, int tenths});

final tempOffsetSelectionProvider = StateProvider.autoDispose
    .family<TempOffsetSelection?, String>((ref, deviceId) => null);

/// 저장 확인을 기다리는 최대 시간 — 서버 명령 유효시간 10초 + 여유
/// (서버 회신 §2 "15초 대기면 충분").
const kTempOffsetConfirmTimeout = Duration(seconds: 15);

enum TempOffsetSaveResult {
  /// 기기가 새 값을 보고했다(또는 명령을 받았다고 답했다).
  saved,

  /// 이미 그 값이다 — 보내지 않았다.
  unchanged,

  /// 기기가 응답하지 않았다(`no_ack`·`expired`·`lost`·15초 무소식).
  noResponse,

  /// 기기가 거절했다(`result`가 ok가 아님).
  rejected,

  /// 요청 자체가 실패했다(네트워크·REST 오류).
  failed,
}

/// 온도 보정 저장 — state는 **지금 보내는 중인 값**(null = 쉬는 중). 온습도 설정
/// 토글이 이 값으로 그려서, 끄는 중엔 꺼진 모양으로 잠근다.
final tempOffsetSaveProvider = NotifierProvider.autoDispose
    .family<TempOffsetSaver, TempOffset?, String>(TempOffsetSaver.new);

class TempOffsetSaver extends AutoDisposeFamilyNotifier<TempOffset?, String> {
  bool _disposed = false;

  @override
  TempOffset? build(String deviceId) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return null;
  }

  /// [offset]을 기기에 보내고 확인될 때까지 기다린다. 이미 저장 중이면 보내지
  /// 않는다(화면이 버튼을 막는다 — 여기선 [TempOffsetSaveResult.failed]).
  ///
  /// 성공 판정(서버 회신 §2): ① `devices.temp_offset_c`가 보낸 값과 같아짐(1차)
  /// ② 명령 `acked`·`result == ok`. ②만 오면 ①을 15초까지 더 기다린다 — 바로
  /// 끝내면 이전 화면이 옛 값을 잠깐 그린다. 15초가 지나도 ②가 있었으면 성공.
  Future<TempOffsetSaveResult> save(TempOffset offset) async {
    if (state != null) return TempOffsetSaveResult.failed;
    final current = ref.read(deviceOffsetProvider(arg)).valueOrNull;
    final target = offset.toDeviceValue();
    bool same(double v) => (v * 10).round() == (target * 10).round();
    if (current != null && same(current)) return TempOffsetSaveResult.unchanged;

    state = offset;
    final done = Completer<TempOffsetSaveResult>();
    var acked = false;
    ProviderSubscription<AsyncValue<double?>>? offsetSub;
    ProviderSubscription<AsyncValue<RebootCommandState?>>? commandSub;
    Timer? timer;

    void finish(TempOffsetSaveResult r) {
      if (done.isCompleted) return;
      done.complete(r);
    }

    try {
      // 보내기 전에 구독한다 — 빠른 기기는 REST 응답보다 먼저 보고할 수 있다.
      offsetSub = ref.listen(deviceOffsetProvider(arg), (_, next) {
        final v = next.valueOrNull;
        if (v != null && same(v)) finish(TempOffsetSaveResult.saved);
      });
      final commandId =
          await ref.read(tempOffsetRepositoryProvider).send(arg, offset);
      timer = Timer(
          kTempOffsetConfirmTimeout,
          () => finish(acked
              ? TempOffsetSaveResult.saved
              : TempOffsetSaveResult.noResponse));
      if (commandId != null) {
        commandSub = ref.listen(commandRowProvider(commandId), (_, next) {
          final command = next.valueOrNull;
          if (command == null) return;
          switch (command.status) {
            case 'no_ack' || 'expired' || 'lost':
              finish(TempOffsetSaveResult.noResponse);
            case 'acked' || 'rejected':
              final result = command.result;
              if (result == null) return; // 결과가 아직 없다
              if (command.status == 'acked' && result == 'ok') {
                acked = true;
                return;
              }
              finish(TempOffsetSaveResult.rejected);
            default:
              return; // pending·sent — 기다린다
          }
        }, fireImmediately: true);
      }
      return await done.future;
    } catch (_) {
      return TempOffsetSaveResult.failed;
    } finally {
      timer?.cancel();
      offsetSub?.close();
      commandSub?.close();
      if (!_disposed) state = null;
    }
  }
}
