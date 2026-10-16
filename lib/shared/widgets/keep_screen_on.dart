import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/screen_wake_lock_provider.dart';

/// [active]이고 [child]가 실제로 보이는 동안 화면이 꺼지지 않게 한다
/// (2026-10-16 — 라이브를 오래 보면 절전모드로 꺼진다는 문의). 보이는지는
/// TickerMode로 판단한다: 다른 탭(indexedStack)이거나 불투명한 화면이 위를
/// 덮으면 꺼진다. 라이브는 [WebRtcLiveView]가, 영상은
/// [KeepScreenOnWhilePlaying]이 재생 중일 때만 건다.
class KeepScreenOn extends ConsumerStatefulWidget {
  const KeepScreenOn({super.key, this.active = true, required this.child});

  final bool active;
  final Widget child;

  @override
  ConsumerState<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends ConsumerState<KeepScreenOn> {
  ScreenWakeLock? _lock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KeepScreenOn old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    final want = widget.active && TickerMode.of(context);
    if (want && _lock == null) {
      final lock = ref.read(screenWakeLockProvider)..acquire();
      _lock = lock;
    } else if (!want) {
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

/// [controller]가 재생 중인 동안만 화면을 켜 둔다. 일시정지·끝나면 놓는다.
class KeepScreenOnWhilePlaying extends StatelessWidget {
  const KeepScreenOnWhilePlaying(
      {super.key, required this.controller, required this.child});

  final VideoPlayerController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: _IsPlaying(controller),
        child: child,
        builder: (context, playing, child) =>
            KeepScreenOn(active: playing, child: child!),
      );
}

/// 컨트롤러 값 중 재생 여부만 — 위치가 바뀔 때마다 다시 그리지 않는다.
class _IsPlaying extends ValueNotifier<bool> {
  _IsPlaying(this._controller) : super(_controller.value.isPlaying);
  final VideoPlayerController _controller;
  // ValueListenableBuilder가 붙였다 뗄 때만 컨트롤러를 구독한다.
  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) _controller.addListener(_onChange);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _controller.removeListener(_onChange);
  }

  void _onChange() => value = _controller.value.isPlaying;
}
