// 카드 문구의 어절 줄바꿈용 U+2060이 자간을 두 번 먹지 않는지(Figma A10 대조).
// 글자 폭을 재야 하므로 테스트 기본 폰트가 아니라 실제 Pretendard를 올린다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_insight_card.dart';
import 'package:vivanaut/shared/domain/keep_all_words.dart';

const _title = '온도가 너무 낮아 개체가 위험할 수 있어요';
const _body = '환기 상태를 점검해 주세요';

double _plainWidth(
    String text, double size, FontWeight weight, double spacing) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  addTearDown(painter.dispose);
  return painter.width;
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == keepAllWords(text)));

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final name in ['Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/Pretendard-$name.otf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<void> pump(WidgetTester tester, double width) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: const EnvInsightCard(rows: [
              EnvInsightRow(title: _title, lines: [_body]),
            ]),
          ),
        ),
      ),
    ));
  }

  testWidgets('설명·제목 폭이 Figma 자간 그대로다', (tester) async {
    await pump(tester, 393);
    expect(
      _paragraph(tester, _body).getMaxIntrinsicWidth(double.infinity),
      closeTo(_plainWidth(_body, 14, FontWeight.w500, 14 * -0.03), 0.5),
    );
    expect(
      _paragraph(tester, _title).getMaxIntrinsicWidth(double.infinity),
      closeTo(_plainWidth(_title, 16, FontWeight.w600, 16 * -0.02), 0.5),
    );
  });

  testWidgets('좁아져도 어절 중간에서 줄이 바뀌지 않는다', (tester) async {
    await pump(tester, 100);
    final paragraph = _paragraph(tester, _body);
    final text = keepAllWords(_body);
    // 첫 줄 오른쪽 끝을 찍으면 그 줄이 끝나는 문자 위치가 나온다.
    final end =
        paragraph.getPositionForOffset(Offset(paragraph.size.width, 5)).offset;
    expect(end, lessThan(text.length), reason: '줄이 실제로 접혀야 하는 폭');
    expect(
      text[end - 1] == ' ' || text[end] == ' ',
      isTrue,
      reason: '첫 줄이 공백에서 끝나야 한다: ${text.substring(0, end)}',
    );
  });
}
