import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/supabase_module_control_repository.dart';
import '../domain/device.dart';
import '../domain/device_command.dart';
import '../domain/telemetry_reading.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

final supabaseModuleControlRepositoryProvider =
    Provider<SupabaseModuleControlRepository>((ref) {
  return SupabaseModuleControlRepository(
    supabase: ref.watch(supabaseClientProvider),
  );
});

// ── 디바이스 목록 ───────────────────────────────────────────────────────────────

final deviceListProvider =
    FutureProvider.autoDispose<List<Device>>((ref) async {
  return ref.watch(supabaseModuleControlRepositoryProvider).listDevices();
});

// ── 선택된 디바이스 ID (PR4: device 선택 UI에서 갱신) ─────────────────────────

/// null = 선택 없음(자동). 복수 device 선택 칩 탭 시 갱신.
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// ── 현재 디바이스 (selectedDeviceIdProvider 우선, fallback = list.first) ────────

final currentDeviceProvider =
    FutureProvider.autoDispose<Device?>((ref) async {
  final list = await ref.watch(deviceListProvider.future);
  if (list.isEmpty) return null;
  final selectedId = ref.watch(selectedDeviceIdProvider);
  if (selectedId != null) {
    final matched = list.where((d) => d.id == selectedId).firstOrNull;
    if (matched != null) return matched;
  }
  return list.first;
});

// ── 텔레메트리 Realtime 스트림 ──────────────────────────────────────────────────

/// `deviceId` family: 해당 디바이스의 telemetry INSERT를 실시간으로 수신.
/// 진입 시 latestTelemetry()로 시드하고, 이후 INSERT 이벤트로 갱신.
final telemetryStreamProvider = StreamProvider.autoDispose
    .family<TelemetryReading?, String>((ref, deviceId) {
  final supabase = ref.watch(supabaseClientProvider);
  final repo = ref.watch(supabaseModuleControlRepositoryProvider);

  final controller = StreamController<TelemetryReading?>();

  // 최신값 seed (에러는 무시 — 스트림은 Realtime으로만 유지)
  repo.latestTelemetry(deviceId).then((t) {
    if (!controller.isClosed && t != null) controller.add(t);
  }).catchError((_) {});

  final channel = supabase.channel('telemetry-$deviceId');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'telemetry',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'device_id',
          value: deviceId,
        ),
        callback: (payload) {
          if (!controller.isClosed) {
            controller.add(TelemetryReading.fromJson(payload.newRecord));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    // ignore: discarded_futures
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── 명령 상태 업데이트 Realtime 스트림 ─────────────────────────────────────────

/// commands 테이블 UPDATE를 수신. RLS가 본인 발행 명령만 노출.
final commandUpdatesProvider =
    StreamProvider.autoDispose<DeviceCommand>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<DeviceCommand>();

  final channel = supabase.channel('commands-rt');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'commands',
        callback: (payload) {
          if (!controller.isClosed) {
            controller.add(DeviceCommand.fromJson(payload.newRecord));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    // ignore: discarded_futures
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── 명령 발행 Notifier ─────────────────────────────────────────────────────────

class ModuleCommandSender extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  Future<DeviceCommand> send(
    String deviceId,
    CommandAction action, {
    Map<String, dynamic>? payload,
    int? ttlSec,
  }) {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다');
    return ref.read(supabaseModuleControlRepositoryProvider).sendCommand(
          deviceId: deviceId,
          action: action,
          payload: payload,
          ttlSec: ttlSec,
        );
  }
}

final moduleCommandSenderProvider =
    AutoDisposeNotifierProvider<ModuleCommandSender, void>(
  ModuleCommandSender.new,
);
