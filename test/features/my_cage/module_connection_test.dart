import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/actuator_state.dart';
import 'package:tera_ai/features/my_cage/domain/device.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_reading.dart';
import 'package:tera_ai/features/my_cage/presentation/supabase_module_providers.dart';

/// 연결 끊김 판정(`moduleOnlineProvider`) 회귀 테스트.
///
/// 버그: Supabase Realtime 스트림은 끊겨도 에러를 내지 않아 `hasError`가 항상
/// false였고, 제어 카드가 그것만 보고 있어 오프라인을 전혀 감지하지 못했다
/// (오프라인인데 제어 버튼이 눌리는 문제). 수정 = telemetry staleness watchdog +
/// device.is_online 결합.
Device _device({required bool isOnline}) => Device(
      id: 'd1',
      ownerId: 'u1',
      enclosureId: null,
      name: '테스트 사육장',
      isOnline: isOnline,
      lastSeenAt: null,
    );

TelemetryReading _telemetry() => const TelemetryReading(
      deviceId: 'd1',
      tA: 28.0,
      hA: 70.0,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: ActuatorState.off,
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: null,
    );

ProviderContainer _container(StreamController<TelemetryReading?> tele,
    {required bool isOnline}) {
  final c = ProviderContainer(
    overrides: [
      currentDeviceProvider
          .overrideWith((ref) => Future.value(_device(isOnline: isOnline))),
      telemetryStreamProvider('d1').overrideWith((ref) => tele.stream),
    ],
  );
  // moduleOnlineProvider(및 그 의존)를 계속 구독해 autoDispose 유지.
  c.listen(moduleOnlineProvider('d1'), (_, __) {});
  return c;
}

void main() {
  // Timer + Stream을 한 fake zone에서 동기 처리하기 위해 fakeAsync 사용.
  // (위젯 테스트의 pump는 fake-clock Timer와 real-loop Stream이 어긋난다.)

  test('telemetry 12초 무수신이면 watchdog가 stale → 오프라인(제어 차단)', () {
    fakeAsync((async) {
      final tele = StreamController<TelemetryReading?>();
      final c = _container(tele, isOnline: true);
      addTearDown(c.dispose);

      async.flushMicrotasks(); // currentDevice Future resolve
      tele.add(_telemetry());
      async.flushMicrotasks(); // telemetry 이벤트 전달
      expect(c.read(moduleOnlineProvider('d1')), isTrue,
          reason: 'is_online=true & telemetry 신선 → 온라인');

      async.elapse(const Duration(seconds: 13)); // watchdog 임계값 초과
      async.flushMicrotasks();
      expect(c.read(moduleOnlineProvider('d1')), isFalse,
          reason: 'telemetry 끊김 12초 경과 → 오프라인 감지 '
              '(수정 전에는 hasError만 봐서 영원히 온라인으로 오판)');

      tele.close();
      async.flushMicrotasks();
    });
  });

  test('telemetry가 임계값 이내로 계속 오면 온라인 유지 (watchdog 리셋)', () {
    fakeAsync((async) {
      final tele = StreamController<TelemetryReading?>();
      final c = _container(tele, isOnline: true);
      addTearDown(c.dispose);

      async.flushMicrotasks();
      // 8초(임계값 12초 미만)마다 telemetry 도착 → watchdog 계속 리셋
      for (var i = 0; i < 3; i++) {
        tele.add(_telemetry());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 8));
      }
      async.flushMicrotasks();
      expect(c.read(moduleOnlineProvider('d1')), isTrue,
          reason: '임계값 이내로 telemetry가 계속 오면 온라인 유지');

      tele.close();
      async.flushMicrotasks();
    });
  });

  test('device.is_online=false면 telemetry를 받아도 오프라인 (보수적 AND 결합)', () {
    fakeAsync((async) {
      final tele = StreamController<TelemetryReading?>();
      final c = _container(tele, isOnline: false);
      addTearDown(c.dispose);

      async.flushMicrotasks();
      tele.add(_telemetry());
      async.flushMicrotasks();
      expect(c.read(moduleOnlineProvider('d1')), isFalse,
          reason: 'is_online=false면 telemetry가 신선해도 제어 차단(위음성 최소화)');

      tele.close();
      async.flushMicrotasks();
    });
  });
}
