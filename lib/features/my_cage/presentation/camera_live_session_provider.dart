import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/live_limit.dart';

/// 보고 있는 카메라 한 대의 라이브 세션 컬럼 변화(2026-09-30).
///
/// 다른 기기가 가져가거나 15분이 끝나면 서버가 cameras 행을 고친다 — 라이브
/// 컨트롤러가 이걸 듣고 **자동 재연결 없이** 안내로 바꾼다. `camerasProvider`에
/// 넣지 않는다: 시청을 시작·종료할 때마다 목록이 다시 흘러 홈 전체가 다시
/// 그려진다(`sysHealthProvider`와 같은 이유). 첫 값은 필요 없다 — 판정은
/// 내 세션이 생긴 **뒤의** 변화만 본다. 컬럼이 없는 구 DB면 모두 null이라
/// 아무 일도 없다.
final cameraLiveSessionProvider = StreamProvider.autoDispose
    .family<CameraLiveSession, String>((ref, cameraUuid) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final supabase = ref.watch(supabaseClientProvider);
  final controller = StreamController<CameraLiveSession>();
  bindResilientChannel(
    ref,
    supabase: supabase,
    name: 'camera-live-$cameraUuid',
    configure: (c) => c.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'cameras',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: cameraUuid),
      callback: (payload) {
        if (controller.isClosed) return;
        controller.add(CameraLiveSession.fromRow(payload.newRecord));
      },
    ),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});
