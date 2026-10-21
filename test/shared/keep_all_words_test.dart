import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/domain/keep_all_words.dart';

void main() {
  test('한글 어절 안에만 WORD JOINER — 공백·줄바꿈은 그대로', () {
    expect(keepAllWords('절전모드로 들어갑니다'),
        '절⁠전⁠모⁠드⁠로 들⁠어⁠갑⁠니⁠다');
    expect(keepAllWords('가\n나'), '가\n나');
  });

  test('한글 없는 어절(영문·숫자·번역 키)은 바꾸지 않는다', () {
    expect(keepAllWords('crecam_live_cooldown_title'),
        'crecam_live_cooldown_title');
    expect(keepAllWords('0:29 뒤'), '0:29 뒤');
    expect(keepAllWords('Wi-Fi를'), 'W⁠i⁠-⁠F⁠i⁠를');
  });
}
