import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 화면 꺼짐 방지 잠금. 여러 화면이 동시에 잡을 수 있어(탭 전환·화면 전환 중
/// 겹침) 잡은 수를 세고, 처음 잡을 때 켜고 마지막이 놓을 때 끈다.
///
/// 켜기가 실패하면(Android 액티비티가 아직 없을 때 등) 다음 잡기·앱 복귀 때
/// 다시 켠다. 액티비티가 다시 만들어지면 창의 FLAG_KEEP_SCREEN_ON이 사라지므로
/// 앱 복귀(resumed)마다 잡고 있으면 다시 건다.
class ScreenWakeLock {
  ScreenWakeLock({Future<void> Function(bool enable)? toggle})
      : _toggle = toggle ?? ((enable) => WakelockPlus.toggle(enable: enable));

  final Future<void> Function(bool enable) _toggle;
  int _holds = 0;
  bool _enableFailed = false;

  void acquire() {
    if (_holds++ == 0 || _enableFailed) _apply(true);
  }

  void release() {
    if (_holds == 0) return;
    if (--_holds == 0) _apply(false);
  }

  /// 앱 복귀 때 호출 — 잡고 있으면 다시 건다.
  void reapply() {
    if (_holds > 0) _apply(true);
  }

  void _apply(bool enable) {
    if (enable) _enableFailed = false;
    unawaited(_toggle(enable).catchError((Object e) {
      // 플랫폼 실패로 화면이 깨지지 않게 삼키되, 켜기 실패는 다음 기회에 다시.
      if (enable && _holds > 0) _enableFailed = true;
      debugPrint('[keep-screen-on] toggle($enable) 실패: $e');
    }));
  }
}

final screenWakeLockProvider = Provider<ScreenWakeLock>((ref) {
  final lock = ScreenWakeLock();
  final listener = AppLifecycleListener(onResume: lock.reapply);
  ref.onDispose(listener.dispose);
  return lock;
});
