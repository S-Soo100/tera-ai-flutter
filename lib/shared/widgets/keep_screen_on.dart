import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 화면 꺼짐 방지 잠금. 여러 화면이 동시에 잡을 수 있어(탭 전환·화면 전환 중
/// 겹침) 잡은 수를 세고, 처음 잡을 때 켜고 마지막이 놓을 때 끈다.
class ScreenWakeLock {
  ScreenWakeLock({Future<void> Function(bool enable)? toggle})
      : _toggle = toggle ?? ((enable) => WakelockPlus.toggle(enable: enable));

  final Future<void> Function(bool enable) _toggle;
  int _holds = 0;

  bool get isHeld => _holds > 0;

  void acquire() {
    if (_holds++ == 0) _apply(true);
  }

  void release() {
    if (_holds == 0) return;
    if (--_holds == 0) _apply(false);
  }

  void _apply(bool enable) {
    // 플랫폼 채널 실패(미지원 기기 등)로 화면이 깨지지 않게 삼킨다.
    unawaited(_toggle(enable).catchError((Object e) {
      debugPrint('[keep-screen-on] toggle($enable) 실패: $e');
    }));
  }
}

final screenWakeLockProvider =
    Provider<ScreenWakeLock>((ref) => ScreenWakeLock());

/// [child]가 실제로 보이는 동안 화면이 꺼지지 않게 한다(2026-10-16 — 라이브를
/// 오래 보면 절전모드로 꺼진다는 문의). 보이는지는 TickerMode로 판단한다:
/// 다른 탭(indexedStack)이거나 불투명한 화면이 위를 덮으면 꺼진다. 앱이
/// 백그라운드로 가면 OS가 잠금을 무시하므로 따로 놓지 않는다.
class KeepScreenOn extends ConsumerStatefulWidget {
  const KeepScreenOn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends ConsumerState<KeepScreenOn> {
  ScreenWakeLock? _lock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && _lock == null) {
      final lock = ref.read(screenWakeLockProvider)..acquire();
      _lock = lock;
    } else if (!visible) {
      _drop();
    }
  }

  void _drop() {
    _lock?.release();
    _lock = null;
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
