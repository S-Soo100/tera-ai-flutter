import 'package:flutter/painting.dart';

const _wordJoiner = '⁠';

/// `keepAllWords`를 거친 문자열을 자간이 두 번 붙지 않게 그리는 span.
/// `Text.rich(wordJoinerSpan(keepAllWords(text)), style: …)`로 쓴다.
///
/// `letterSpacing`은 U+2060에도 붙어 `Text`로 그대로 그리면 글자 사이 자간이
/// 두 배가 된다(−3%가 −6%로, 글자가 빽빽해 굵어 보인다). 그 문자에만 자간 0을
/// 준다. 글자 자체는 바꾸지 않는다.
TextSpan wordJoinerSpan(String joined) {
  if (!joined.contains(_wordJoiner)) return TextSpan(text: joined);
  final parts = joined.split(_wordJoiner);
  return TextSpan(children: [
    for (var i = 0; i < parts.length; i++) ...[
      if (i > 0)
        const TextSpan(text: _wordJoiner, style: TextStyle(letterSpacing: 0)),
      TextSpan(text: parts[i]),
    ],
  ]);
}
