import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/mist_duration.dart';

void main() {
  group('MistDuration', () {
    test('허용 값은 1/2/3초뿐이다', () {
      // 서버가 화이트리스트로 검증하고(400), 펌웨어는 5초로 clamp한다.
      // 앱이 임의 값을 만들 수 있게 두면 거절만 왕복한다.
      expect(MistDuration.values.map((d) => d.milliseconds).toList(),
          [1000, 2000, 3000]);
    });

    test('기본값은 2초 — 가운데', () {
      expect(MistDuration.defaultValue, MistDuration.twoSeconds);
    });

    test('밀리초로 되찾을 수 있다 — 저장값 복원용', () {
      for (final d in MistDuration.values) {
        expect(MistDuration.fromMilliseconds(d.milliseconds), d);
      }
    });

    test('모르는 값이면 기본값으로 떨어진다 — 잠금 상태로 남지 않는다', () {
      expect(MistDuration.fromMilliseconds(4500), MistDuration.defaultValue);
      expect(MistDuration.fromMilliseconds(null), MistDuration.defaultValue);
    });

    test('명령 payload는 duration_ms 하나다', () {
      expect(MistDuration.twoSeconds.payload, {'duration_ms': 2000});
    });

    test('초 표시는 정수다 — 2.0초로 쓰지 않는다', () {
      expect(MistDuration.threeSeconds.seconds, 3);
    });
  });
}
