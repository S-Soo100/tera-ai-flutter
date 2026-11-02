import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/domain/env_thresholds.dart';

/// v4 1-1·1-2 적정 범위·온도 보정 도메인 (계획 Task 1).
void main() {
  group('EnvRange.fromSettings', () {
    test(
        'null 설정은 디폴트',
        () => expect(
            EnvRange.fromSettings(
                null, null, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(18, 26)));
    test(
        '한쪽 null은 그쪽만 디폴트',
        () => expect(
            EnvRange.fromSettings(
                20, null, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(20, 26)));
    test(
        '범위 밖은 clamp',
        () => expect(
            EnvRange.fromSettings(
                10, 35, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(15, 29)));
    test(
        '스텝 불일치는 맞춤',
        () => expect(
            EnvRange.fromSettings(
                18.3, 26, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(18.5, 26)));
    test(
        'min>=max면 둘 다 디폴트',
        () => expect(
            EnvRange.fromSettings(
                24, 24, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(18, 26)));
    test(
        '맞춘 뒤 뒤집히면 둘 다 디폴트 — 한쪽만 디폴트로 채운 경우 포함',
        () => expect(
            EnvRange.fromSettings(
                null, 17, EnvRangeRule.temp, EnvRange.tempDefault),
            const EnvRange(18, 26)));
    test(
        '습도 저장값',
        () => expect(
            EnvRange.fromSettings(
                45, 75, EnvRangeRule.humid, EnvRange.humidDefault),
            const EnvRange(45, 75)));
  });

  group('EnvRangeRule', () {
    test('온도 0.5 스텝·상한', () {
      expect(EnvRangeRule.temp.decrease(18), 17.5);
      expect(EnvRangeRule.temp.canIncrease(29), isFalse);
    });
    test('습도 5 스텝·하한', () {
      expect(EnvRangeRule.humid.decrease(40), 35);
      expect(EnvRangeRule.humid.canDecrease(35), isFalse);
    });
    test('끝에서는 더 가지 않는다', () {
      expect(EnvRangeRule.temp.increase(29), 29);
      expect(EnvRangeRule.temp.decrease(15), 15);
      expect(EnvRangeRule.humid.increase(85), 85);
    });
    test('반복 증가해도 부동소수 오차가 쌓이지 않는다', () {
      var v = 15.0;
      for (var i = 0; i < 28; i++) {
        v = EnvRangeRule.temp.increase(v);
      }
      expect(v, 29);
    });
    test('snap은 가장 가까운 스텝 + clamp', () {
      expect(EnvRangeRule.temp.snap(18.2), 18);
      expect(EnvRangeRule.temp.snap(14), 15);
      expect(EnvRangeRule.humid.snap(62), 60);
      expect(EnvRangeRule.humid.snap(99), 85);
    });
  });

  group('EnvRange.isValidFor', () {
    test(
        '스텝 배수 아님은 무효',
        () => expect(
            const EnvRange(18.3, 26).isValidFor(EnvRangeRule.temp), isFalse));
    test('디폴트는 유효', () {
      expect(EnvRange.tempDefault.isValidFor(EnvRangeRule.temp), isTrue);
      expect(EnvRange.humidDefault.isValidFor(EnvRangeRule.humid), isTrue);
    });
    test(
        '경계값 15·29는 유효',
        () => expect(
            const EnvRange(15, 29).isValidFor(EnvRangeRule.temp), isTrue));
    test(
        'min == max는 무효',
        () => expect(
            const EnvRange(24, 24).isValidFor(EnvRangeRule.temp), isFalse));
    test('범위 밖은 무효', () {
      expect(const EnvRange(14.5, 26).isValidFor(EnvRangeRule.temp), isFalse);
      expect(const EnvRange(40, 90).isValidFor(EnvRangeRule.humid), isFalse);
    });
  });

  group('EnvRangeRule 스테퍼 판정(MIN < MAX 유지)', () {
    const r = EnvRangeRule.temp;
    test('최소 +는 최대 바로 아래에서 멈춘다', () {
      expect(r.canIncreaseMin(const EnvRange(25, 26)), isTrue);
      expect(r.canIncreaseMin(const EnvRange(25.5, 26)), isFalse);
    });
    test('최대 −는 최소 바로 위에서 멈춘다', () {
      expect(r.canDecreaseMax(const EnvRange(18, 19)), isTrue);
      expect(r.canDecreaseMax(const EnvRange(18, 18.5)), isFalse);
    });
    test('경계 — 최소 15에서 −, 최대 29에서 + 불가', () {
      expect(r.canDecreaseMin(const EnvRange(15, 26)), isFalse);
      expect(r.canIncreaseMax(const EnvRange(18, 29)), isFalse);
      expect(r.canDecreaseMin(const EnvRange(18, 26)), isTrue);
      expect(r.canIncreaseMax(const EnvRange(18, 26)), isTrue);
    });
    test('습도 5 단위', () {
      expect(EnvRangeRule.humid.canIncreaseMin(const EnvRange(75, 80)), isFalse);
      expect(EnvRangeRule.humid.canDecreaseMax(const EnvRange(40, 50)), isTrue);
    });
  });

  group('TempOffset', () {
    test('보정 빼기 1.0', () {
      final o = TempOffset.of(subtract: true, magnitude: 1.0);
      expect(o.value, -1.0);
      expect(o.isSubtract, isTrue);
      expect(o.magnitude, 1.0);
      expect(o.apply(26.2), closeTo(25.2, 1e-9));
    });
    test('보정 더하기 0.3 (스텝 누적 오차 허용)', () {
      final o = TempOffset.of(subtract: false, magnitude: 0.1 + 0.1 + 0.1);
      expect(o.value, 0.3);
      expect(o.isSubtract, isFalse);
    });
    test('원래 측정값 복원',
        () => expect(TempOffset.rawFrom(24.7, -1.5), closeTo(26.2, 1e-9)));
    test('편집기 범위 0.1~4.0', () {
      expect(() => TempOffset.of(subtract: false, magnitude: 4.1),
          throwsArgumentError);
      expect(() => TempOffset.of(subtract: false, magnitude: 0),
          throwsArgumentError);
      expect(TempOffset.of(subtract: true, magnitude: 4.0).value, -4.0);
      expect(TempOffset.of(subtract: false, magnitude: 0.1).value, 0.1);
    });
    test('0.1 스텝 밖 크기는 거절', () {
      expect(() => TempOffset.of(subtract: false, magnitude: 1.05),
          throwsArgumentError);
    });
    test('기기 값 ±4 초과도 throw 없음', () {
      final o = TempOffset.fromDevice(-6);
      expect(o.outOfEditorRange, isTrue);
      expect(o.isOff, isFalse);
    });
    test('기기 값 4.0은 편집기 범위 안',
        () => expect(TempOffset.fromDevice(4).outOfEditorRange, isFalse));
    test('D1 임시: 끔은 0', () {
      expect(TempOffset.fromDevice(0).isOff, isTrue);
      expect(const TempOffset(0).toDeviceValue(), 0);
    });
    test('D1 임시: 기기 값 ↔ 사용자 값 그대로', () {
      expect(TempOffset.fromDevice(-1.5).value, -1.5);
      expect(TempOffset.fromDevice(-1.5).isOff, isFalse);
      expect(const TempOffset(1.0).toDeviceValue(), 1.0);
    });
  });
}
