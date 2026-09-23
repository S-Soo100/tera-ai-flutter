// Realtime 구독 자가 복구(2026-09-24). S21+ 실기기에서 폰 Wi-Fi를 껐다 켠 뒤
// 온습도 구독이 40분 넘게 되살아나지 않았다 — 라이브러리 자동 재접속에만 기대지
// 않고 앱이 채널을 다시 만든다.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/supabase/resilient_channel.dart';

class _FakeChannel extends Fake implements RealtimeChannel {
  _FakeChannel(this.index);
  final int index;
  void Function(RealtimeSubscribeStatus, Object?)? cb;
  bool removed = false;

  @override
  RealtimeChannel subscribe(
      [void Function(RealtimeSubscribeStatus status, Object? error)? callback,
      Duration? timeout]) {
    cb = callback;
    return this;
  }

  void emit(RealtimeSubscribeStatus s) => cb?.call(s, null);
}

class _Rig {
  final channels = <_FakeChannel>[];
  var rejoined = 0;
  late final ResilientChannel rc = ResilientChannel(
    name: 'telemetry-d1',
    build: () {
      final c = _FakeChannel(channels.length + 1);
      channels.add(c);
      return c;
    },
    remove: (c) async {
      (c as _FakeChannel).removed = true;
      // 실제 removeChannel도 닫힘 상태를 알린다 — 재구독 루프가 돌면 안 된다.
      c.emit(RealtimeSubscribeStatus.closed);
    },
    onRejoined: () => rejoined++,
  );
  _FakeChannel get last => channels.last;
}

void main() {
  test('구독 오류면 백오프(3초) 뒤 채널을 지우고 새로 구독, 다시 붙으면 onRejoined', () {
    fakeAsync((async) {
      final r = _Rig()..rc.start();
      r.last.emit(RealtimeSubscribeStatus.subscribed);
      expect(r.rejoined, 0, reason: '첫 구독은 재합류가 아니다');

      r.last.emit(RealtimeSubscribeStatus.channelError);
      async.elapse(const Duration(seconds: 2));
      expect(r.channels, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(r.channels, hasLength(2));
      expect(r.channels.first.removed, isTrue);

      r.last.emit(RealtimeSubscribeStatus.subscribed);
      expect(r.rejoined, 1);
      r.rc.dispose();
    });
  });

  test('시간 초과가 반복되면 간격이 3→6초로 늘고, 성공하면 처음으로', () {
    fakeAsync((async) {
      final r = _Rig()..rc.start();
      r.last.emit(RealtimeSubscribeStatus.timedOut);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(r.channels, hasLength(2));
      r.last.emit(RealtimeSubscribeStatus.timedOut);
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(r.channels, hasLength(2), reason: '두 번째는 6초 뒤');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(r.channels, hasLength(3));
      r.last.emit(RealtimeSubscribeStatus.subscribed);
      r.last.emit(RealtimeSubscribeStatus.closed);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(r.channels, hasLength(4), reason: '성공 뒤엔 다시 3초부터');
      r.rc.dispose();
    });
  });

  test('restart가 겹쳐도 채널은 하나만 새로 만든다(같은 topic 중복 join 방지)', () {
    fakeAsync((async) {
      final r = _Rig()..rc.start();
      r.last.emit(RealtimeSubscribeStatus.subscribed);
      r.rc.restart('network-back');
      r.rc.restart('resume');
      async.flushMicrotasks();
      expect(r.channels, hasLength(2));
      // 지운 채널이 알린 closed는 무시된다 — 추가 재구독 없음.
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(r.channels, hasLength(2));
      r.rc.dispose();
    });
  });

  test('dispose 뒤에는 아무것도 다시 만들지 않는다', () {
    fakeAsync((async) {
      final r = _Rig()..rc.start();
      r.last.emit(RealtimeSubscribeStatus.channelError);
      r.rc.dispose();
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(r.channels, hasLength(1));
      expect(r.channels.first.removed, isTrue);
    });
  });

  group('SilenceProbe', () {
    test('주기 동안 이벤트가 없을 때만 확인하고, 이벤트가 오면 건너뛴다', () {
      fakeAsync((async) {
        var checks = 0;
        final p = SilenceProbe(
            interval: const Duration(seconds: 12), onSilent: () => checks++)
          ..start();
        p.onEvent();
        async.elapse(const Duration(seconds: 12));
        expect(checks, 0, reason: '이번 주기엔 값이 왔다');
        async.elapse(const Duration(seconds: 12));
        expect(checks, 1);
        async.elapse(const Duration(seconds: 12));
        expect(checks, 2);
        p.dispose();
        async.elapse(const Duration(minutes: 1));
        expect(checks, 2);
      });
    });
  });
}
