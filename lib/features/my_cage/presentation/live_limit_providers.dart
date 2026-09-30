import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app_installation.dart';

import '../../../core/supabase/realtime_binding.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/live_limit.dart';

// 라이브 시청 제한(2026-09-30) provider 모음.

/// 이 설치(시청자) ID — 한 기기 판정용, 푸시 기기 등록과 같은 값. 기기 이름은
/// 보내지 않는다(2026-09-30 사용자 결정 — 다른 기기엔 "다른 기기"로만 보인다).
/// 못 구하면 이번 실행 동안만 쓰는 값으로 대신한다 — 라이브를 막을 이유는 아니다.
final liveViewerIdProvider = FutureProvider<String>((ref) async {
  try {
    return await appInstallationId();
  } catch (_) {
    return const Uuid().v4();
  }
});

/// 서버가 라이브를 끝낼 시각까지 남은 시간 — 마지막 [kLiveEndingSoon]만 센다.
///
/// 그 전엔 null이고 **타이머 하나만** 걸어 둔다(15분 내내 1초마다 다시 그리지
/// 않는다). 0이 되면 거기서 멈춘다 — 서버 만료 스윕이 15초 주기라 영상이 조금
/// 더 나올 수 있어, 알약은 영상이 실제로 끊길 때까지 "곧"으로 남는다.
final liveEndingSoonProvider = StreamProvider.autoDispose
    .family<Duration?, DateTime>((ref, until) {
  final controller = StreamController<Duration?>();
  Timer? timer;
  void tick() {
    if (controller.isClosed) return;
    final left = until.difference(DateTime.now());
    if (left > kLiveEndingSoon) {
      controller.add(null);
      timer = Timer(left - kLiveEndingSoon, tick);
    } else if (left > Duration.zero) {
      controller.add(left);
      timer = Timer(const Duration(seconds: 1), tick);
    } else {
      controller.add(Duration.zero);
    }
  }

  tick();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

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
