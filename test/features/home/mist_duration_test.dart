import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';

void main() {
  group('MistDuration', () {
    test('선택지는 3/6/9초 (2026-09-25 사용자 결정)', () {
      expect(MistDuration.values.map((d) => d.milliseconds).toList(),
          [3000, 6000, 9000]);
    });

    test('기본값은 3초', () {
      expect(MistDuration.defaultValue, MistDuration.threeSeconds);
    });

    test('밀리초로 되찾을 수 있다 — 저장값 복원용', () {
      for (final d in MistDuration.values) {
        expect(MistDuration.tryFromMilliseconds(d.milliseconds), d);
      }
    });

    test('옛 1/2·5/10초·모르는 값은 null — 화면이 저장값을 그대로 둔다', () {
      expect(MistDuration.tryFromMilliseconds(1000), isNull);
      expect(MistDuration.tryFromMilliseconds(5000), isNull);
      expect(MistDuration.tryFromMilliseconds(10000), isNull);
      expect(MistDuration.tryFromMilliseconds(null), isNull);
    });

    // 2026-09-28 서버 확인: 즉시 분무는 서버가 기기 상한에 맞춰 나눠 보낸다.
    test('즉시 분무는 명령 한 번 — 고른 시간 그대로 싣는다', () {
      expect(kMistServerSupportsLong, isTrue);
      for (final d in MistDuration.values) {
        expect(d.parts, 1);
        expect(d.partPayload, {'duration_ms': d.milliseconds});
      }
    });

    // 예약 REST 검증(1~20초, e2eba29)이 운영에 배포되기 전엔 6·9초가 400이다.
    test('예약은 서버 배포 확인 전까지 3초만', () {
      expect(kMistSchedulesSupportLong, isFalse);
      expect(MistDuration.values.where((d) => d.schedulable).toList(),
          [MistDuration.threeSeconds]);
      expect(MistDuration.threeSeconds.payload, {'duration_ms': 3000});
    });

    test('초 표시는 정수다', () {
      expect(MistDuration.nineSeconds.seconds, 9);
    });
  });
}
