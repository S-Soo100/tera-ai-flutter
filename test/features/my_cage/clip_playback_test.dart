import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/clip_playback.dart';

void main() {
  const dur60 = Duration(seconds: 60);

  group('initialClipSeek — 서버 재생 시작점(play_from_sec) 판정', () {
    test('8.8초 · 영상 60초 → 8.8초로 seek', () {
      expect(initialClipSeek(8.8, dur60),
          const Duration(milliseconds: 8800));
    });
    test('null(분석 없음/구 서버) → seek 없음', () {
      expect(initialClipSeek(null, dur60), isNull);
    });
    test('duration 이상(70초 · 영상 60초) → seek 없음 (0초부터)', () {
      expect(initialClipSeek(70, dur60), isNull);
    });
    test('0 이하 → seek 없음 (0초 seek은 무의미)', () {
      expect(initialClipSeek(0, dur60), isNull);
      expect(initialClipSeek(-1, dur60), isNull);
    });
    test('duration 미확보(0) → seek 없음 (방어)', () {
      expect(initialClipSeek(8.8, Duration.zero), isNull);
    });
    test('정수 초도 그대로 (3 → 3초)', () {
      expect(initialClipSeek(3, dur60), const Duration(seconds: 3));
    });
  });
}
