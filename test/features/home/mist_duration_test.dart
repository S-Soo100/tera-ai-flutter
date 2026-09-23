import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';

void main() {
  group('MistDuration', () {
    test('선택지는 5/10초뿐이다 (2026-09-23 사용자 결정)', () {
      // 서버 화이트리스트와 같은 값만 둔다 — 임의 값은 400으로 거절만 왕복한다.
      expect(MistDuration.values.map((d) => d.milliseconds).toList(),
          [5000, 10000]);
    });

    test('기본값은 5초', () {
      expect(MistDuration.defaultValue, MistDuration.fiveSeconds);
    });

    test('밀리초로 되찾을 수 있다 — 저장값 복원용', () {
      for (final d in MistDuration.values) {
        expect(MistDuration.tryFromMilliseconds(d.milliseconds), d);
      }
    });

    test('빠진 7초도 null — 저장된 적 있어도 기본으로 떨어진다', () {
      expect(MistDuration.tryFromMilliseconds(7000), isNull);
    });

    test('옛 1/2/3초·모르는 값은 null — 화면이 저장값을 그대로 둔다', () {
      expect(MistDuration.tryFromMilliseconds(3000), isNull);
      expect(MistDuration.tryFromMilliseconds(4500), isNull);
      expect(MistDuration.tryFromMilliseconds(null), isNull);
    });

    test('명령 payload는 duration_ms 하나다', () {
      expect(MistDuration.tenSeconds.payload, {'duration_ms': 10000});
    });

    test('초 표시는 정수다 — 10.0초로 쓰지 않는다', () {
      expect(MistDuration.tenSeconds.seconds, 10);
    });
  });
}
