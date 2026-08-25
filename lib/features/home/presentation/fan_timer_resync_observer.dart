/// 앱 수명주기 훅 — 콜드 스타트·백그라운드 복귀 때 팬 타이머 알림을
/// `commands` 이력과 재동기화한다. 배경은 `fan_timer_notification_resync.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/services/fan_timer_notification_service.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../data/fan_timer_notification_resync.dart';

final fanTimerNotificationResyncProvider =
    Provider<FanTimerNotificationResync>((ref) => FanTimerNotificationResync(
          ref.watch(supabaseClientProvider),
          ref.watch(fanTimerNotificationServiceProvider),
        ));

/// 앱 루트에 한 번 감싼다(`app.dart` builder). 화면을 그리지 않고 수명주기만
/// 듣는다.
class FanTimerResyncObserver extends ConsumerStatefulWidget {
  const FanTimerResyncObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FanTimerResyncObserver> createState() =>
      _FanTimerResyncObserverState();
}

class _FanTimerResyncObserverState
    extends ConsumerState<FanTimerResyncObserver> {
  AppLifecycleListener? _lifecycle;
  DateTime? _lastRun;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _maybeRun);
    // 콜드 스타트도 한 번 — resumed 이벤트는 백그라운드 복귀에만 온다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _maybeRun() async {
    // 앱 전환만 해도 resumed가 오므로 1분 스로틀 — 재동기화는 기기 수만큼
    // 쿼리를 돌린다.
    final now = DateTime.now();
    if (_lastRun != null &&
        now.difference(_lastRun!) < const Duration(minutes: 1)) {
      return;
    }
    _lastRun = now;
    try {
      // 게스트/미로그인은 RLS가 빈 목록을 주므로 자연히 아무 일도 안 한다.
      final devices = await ref.read(deviceListProvider.future);
      if (!mounted) return;
      await ref
          .read(fanTimerNotificationResyncProvider)
          .run(devices.map((d) => d.id));
    } catch (e) {
      // 알림 정합은 부가 기능 — 네트워크 오류로 앱 기동을 방해하지 않는다.
      debugPrint('[fan-timer-notif] resync skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
