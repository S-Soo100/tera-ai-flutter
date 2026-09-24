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

    test('서버가 긴 분사를 받기 전엔 3초씩 이어 보낸다', () {
      expect(kMistServerSupportsLong, isFalse);
      expect(MistDuration.threeSeconds.parts, 1);
      expect(MistDuration.sixSeconds.parts, 2);
      expect(MistDuration.nineSeconds.parts, 3);
      // 한 번에 싣는 값은 서버 허용값(1/2/3초) 안의 3초.
      for (final d in MistDuration.values) {
        expect(d.partPayload, {'duration_ms': 3000});
      }
    });

    test('예약은 3초만 — 서버가 한 번에 실행해 이어 붙일 수 없다', () {
      expect(MistDuration.values.where((d) => d.schedulable).toList(),
          [MistDuration.threeSeconds]);
      expect(MistDuration.threeSeconds.payload, {'duration_ms': 3000});
    });

    test('초 표시는 정수다', () {
      expect(MistDuration.nineSeconds.seconds, 9);
    });
  });
}
