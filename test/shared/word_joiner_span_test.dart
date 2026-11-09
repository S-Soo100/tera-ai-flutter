// keepAllWords가 넣은 U+2060이 자간을 한 번 더 먹지 않는지. 글자 폭을 재야 해서
// 테스트 기본 폰트가 아니라 실제 Pretendard를 올린다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/shared/domain/keep_all_words.dart';
import 'package:vivanaut/shared/widgets/word_joiner_span.dart';

const _style = TextStyle(
  fontFamily: 'Pretendard',
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: 14 * -0.02,
);

double _width(InlineSpan span) {
  final painter = TextPainter(
    text: TextSpan(style: _style, children: [span]),
    textDirection: TextDirection.ltr,
  )..layout();
  addTearDown(painter.dispose);
  return painter.width;
}

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/Pretendard-Medium.otf').readAsBytesSync();
    final loader = FontLoader('Pretendard')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  test('글자는 그대로다 — 찾기·복사·스크린리더 문자열 불변', () {
    final joined = keepAllWords('환기 상태를 점검해 주세요');
    expect(wordJoinerSpan(joined).toPlainText(), joined);
  });

  test('연결 문자가 없으면 나누지 않는다', () {
    final span = wordJoinerSpan('Wi-Fi 0:29');
    expect(span.text, 'Wi-Fi 0:29');
    expect(span.children, isNull);
  });

  test('자간이 있어도 폭이 연결 문자 없는 문구와 같다', () {
    const text = '분무 후 6시간이 지났지만 사육장이 충분히 마르지 않았습니다';
    expect(_width(wordJoinerSpan(keepAllWords(text))),
        closeTo(_width(const TextSpan(text: text)), 0.5));
  });
}
