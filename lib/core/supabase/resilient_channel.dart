import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ChannelBuilder = RealtimeChannel Function();
typedef ChannelRemover = Future<void> Function(RealtimeChannel channel);

/// 스스로 다시 붙는 Realtime 구독(2026-09-24).
///
/// S21+ 실기기에서 폰 Wi-Fi를 껐다 켠 뒤 온습도 구독이 40분 넘게 되살아나지
/// 않았다 — 기기는 3초마다 DB에 쓰고 있었는데 앱만 못 받았다. `.subscribe()`
/// 한 번에 라이브러리 자동 재접속만 믿던 구조라 복구 수단이 없었다.
///
/// - 오류·시간 초과·닫힘이면 채널을 **지우고 새로** 구독한다(3·6·12…60초).
/// - [restart]로 즉시 다시 만든다(망 복귀·앱 복귀·무소식 자가진단).
/// - 첫 구독 이후의 재합류마다 [onRejoined] — 끊긴 사이 빠진 값을 다시 읽는다.
/// - 같은 topic을 두 번 join하지 않도록 이전 채널을 먼저 지우고, 재시작이 겹치면
///   하나로 합친다.
class ResilientChannel {
  ResilientChannel({
    required this.name,
    required ChannelBuilder build,
    required ChannelRemover remove,
    this.onRejoined,
  })  : _build = build,
        _remove = remove;

  final String name;
  final ChannelBuilder _build;
  final ChannelRemover _remove;
  final VoidCallback? onRejoined;

  RealtimeChannel? _channel;

  /// 채널 세대 — 지운 채널이 늦게 알리는 상태(closed 등)를 무시한다.
  int _gen = 0;
  int _attempt = 0;
  bool _joinedOnce = false;
  bool _restarting = false;
  bool _disposed = false;
  Timer? _retry;

  void start() => _open();

  void _open() {
    final gen = ++_gen;
    final channel = _build();
    _channel = channel;
    channel.subscribe((status, error) {
      if (_disposed || gen != _gen) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _log('subscribed', rejoin: _joinedOnce);
          _attempt = 0;
          if (_joinedOnce) onRejoined?.call();
          _joinedOnce = true;
        case RealtimeSubscribeStatus.channelError ||
              RealtimeSubscribeStatus.timedOut ||
              RealtimeSubscribeStatus.closed:
          _log('lost ${status.name}${error == null ? '' : ' $error'}');
          _scheduleRestart();
      }
    });
  }

  void _scheduleRestart() {
    if (_retry?.isActive ?? false) return;
    final delay =
        Duration(seconds: math.min(60, 3 * (1 << math.min(5, _attempt))));
    _attempt++;
    _retry = Timer(delay, () => unawaited(restart('retry')));
  }

  /// 채널을 즉시 새로 만든다. 진행 중인 재시작이 있으면 합친다.
  Future<void> restart(String reason) async {
    if (_disposed || _restarting) return;
    _restarting = true;
    _retry?.cancel();
    _log('restart $reason');
    final old = _channel;
    _channel = null;
    _gen++; // 지우는 채널의 closed 알림을 무시
    try {
      if (old != null) await _remove(old);
    } catch (_) {
      // 지우기 실패는 무시 — 새 채널은 어쨌든 만든다.
    } finally {
      _restarting = false;
    }
    if (_disposed) return;
    _open();
  }

  void dispose() {
    _disposed = true;
    _gen++;
    _retry?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_remove(channel).catchError((_) {}));
    }
  }

  void _log(String event, {bool? rejoin}) => debugPrint(
      '[realtime] $name $event${rejoin == true ? ' (rejoin)' : ''}');
}

/// 주기 동안 이벤트가 한 번도 없으면 [onSilent]를 부른다(시계 대신 주기 단위 —
/// 테스트 가짜 시계와 맞는다). Realtime이 조용히 죽었는지 REST로 확인하는 데 쓴다.
class SilenceProbe {
  SilenceProbe({required this.interval, required this.onSilent});

  final Duration interval;
  final VoidCallback onSilent;

  Timer? _timer;
  bool _heard = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_heard) {
        _heard = false;
        return;
      }
      onSilent();
    });
  }

  void onEvent() => _heard = true;

  void dispose() => _timer?.cancel();
}
