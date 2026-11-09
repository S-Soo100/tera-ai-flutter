import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/keep_all_words.dart';

/// 온습도 상세 카드 한 줄 — 칩(선택) · 제목 · 설명 줄들.
class EnvInsightRow {
  const EnvInsightRow({
    this.key,
    this.chip,
    this.chipColor,
    required this.title,
    this.lines = const [],
    this.lineLetterSpacing = -0.03,
  });

  final Key? key;

  /// null이면 칩 없이 제목부터(주간 예외 안내).
  final String? chip;

  /// 칩 글자색. null이면 `textSecondary`.
  final Color? chipColor;
  final String title;

  /// 줄마다 한 Text — 서버 문구를 잇거나 고치지 않는다.
  final List<String> lines;

  /// 설명 자간(글자 크기 배수). 실시간·일일 −3%(A10·A15), 주간 −2%(A20).
  final double lineLetterSpacing;
}

/// 온습도 상세의 회색 카드 겉모양 — 실시간 이탈(A10)·일일 분석(A15)·주간
/// 분석(A20) 공용.
///
/// Figma Alert: fill `#F4F4F4` r12, 안쪽 위아래 12·좌우 8. 줄 사이는 12 +
/// 선 1(`#E3E3E3`) + 12. 칩 높이 24·좌우 8·흰 r12·14/700, 칩 → 본문 8. 제목
/// 16/600 행간 22.1 `#3C3C3C`, 제목 → 설명 4, 설명 14/500 행간 19.3 `#949090`.
/// 줄이 없으면 아무것도 그리지 않는다.
class EnvInsightCard extends StatelessWidget {
  const EnvInsightCard({super.key, required this.rows});

  final List<EnvInsightRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final glass = context.glass;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: glass.overlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: glass.border),
              ),
            _row(glass, rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(GlassPalette glass, EnvInsightRow r) {
    final chip = r.chip;
    return Row(
      key: r.key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chip != null) ...[
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: glass.surfaceHeader,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chip,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                height: 16.70703125 / 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 14 * -0.02,
                color: r.chipColor ?? glass.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 줄이 넘치면 어절 단위로 넘긴다(글자 중간에서 끊지 않음).
              _keepAllText(
                r.title,
                TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  height: 22.1 / 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 16 * -0.02,
                  color: glass.textSecondary,
                ),
              ),
              if (r.lines.isNotEmpty) const SizedBox(height: 4),
              for (final line in r.lines)
                _keepAllText(
                  line,
                  TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    height: 19.3 / 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 14 * r.lineLetterSpacing,
                    color: glass.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// [keepAllWords]로 어절 단위 줄바꿈을 하되 자간은 Figma 값 그대로 둔다.
  ///
  /// `letterSpacing`은 U+2060에도 붙어 그대로 쓰면 글자 사이 자간이 두 배가
  /// 된다(−3%가 −6%로, 글자가 빽빽해 굵어 보였다). 그 문자만 자간을 0으로 준다.
  Widget _keepAllText(String text, TextStyle style) {
    final parts = keepAllWords(text).split('\u2060');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            const TextSpan(text: '\u2060', style: TextStyle(letterSpacing: 0)),
          TextSpan(text: parts[i]),
        ],
      ]),
      style: style,
    );
  }
}
