/// 한글 어절 안에서 줄이 바뀌지 않게(CSS `word-break: keep-all`) 글자 사이에
/// WORD JOINER(U+2060)를 넣는다. 공백·명시 줄바꿈에서만 접힌다.
///
/// 한글이 든 어절에만 넣는다 — 영문·숫자 어절은 원래 공백에서만 접히고,
/// 테스트에서 `.tr()`이 돌려주는 키 문자열(ASCII)을 그대로 찾을 수 있다.
String keepAllWords(String text) => text.splitMapJoin(RegExp(r'\s+'),
    onMatch: (m) => m[0]!,
    onNonMatch: (word) =>
        _hangul.hasMatch(word) ? word.split('').join('⁠') : word);

final _hangul = RegExp(r'[가-힣ᄀ-ᇿ㄰-㆏]');
