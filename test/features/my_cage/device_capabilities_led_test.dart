import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';

/// 2026-08-18 백엔드 회신 §2(`devices.capabilities`)·§4(`telemetry.led`).
void main() {
  group('Device.capabilities', () {
    test('mosfet + led_dimmable:true → 밝기 UI 허용', () {
      final d = Device.fromJson({
        'id': 'd1',
        'capabilities': {'board': 'mosfet', 'led_dimmable': true},
      });
      expect(d.ledDimmable, isTrue);
      expect(d.boardType, 'mosfet');
    });

    test('릴레이 백필 값 → 밝기 UI 없음', () {
      final d = Device.fromJson({
        'id': 'd1',
        'capabilities': {'board': 'relay', 'led_dimmable': false},
      });
      expect(d.ledDimmable, isFalse);
      expect(d.boardType, 'relay');
    });

    test('capabilities 없음(null) — 모르는 능력은 없는 것으로', () {
      final d = Device.fromJson({'id': 'd1'});
      expect(d.capabilities, isNull);
      expect(d.ledDimmable, isFalse);
      expect(d.boardType, isNull);
    });
  });

  group('TelemetryReading.led', () {
    Map<String, dynamic> base() => {
          'device_id': 'd1',
          't_a': 26.0,
          'h_a': 60.0,
          'a_ok': true,
        };

    test('"ON" + brightness 60 → on/60', () {
      final t = TelemetryReading.fromJson({
        ...base(),
        'led': 'ON',
        'led_brightness': 60,
      });
      expect(t.led, ActuatorState.on);
      expect(t.ledBrightness, 60);
    });

    test('"OFF" + brightness null(릴레이) → off/null', () {
      final t = TelemetryReading.fromJson({...base(), 'led': 'OFF'});
      expect(t.led, ActuatorState.off);
      expect(t.ledBrightness, isNull);
    });

    test('구 펌웨어(컬럼 없음) → unavailable — "꺼짐"이 아니라 "모름"', () {
      final t = TelemetryReading.fromJson(base());
      expect(t.led, ActuatorState.unavailable);
      expect(t.ledBrightness, isNull);
    });
  });
}
