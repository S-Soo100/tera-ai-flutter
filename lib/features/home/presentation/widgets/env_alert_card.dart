import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/keep_all_words.dart';
import '../../domain/env_alert.dart';

/// 온습도 상세의 v4 실시간 이탈 카드(Figma A10·A12·A13, Alert 369×139).
///
/// 줄마다 칩(서버 `message`의 `[ ]` 안) · 제목(`]` 뒤) · 설명(노션 v4 1-5 고정
/// 문구). 줄 순서·지표별 1개는 [EnvAlert.openLatestPerMetric]이 정한다 — 여기선
/// 받은 순서대로 그린다. 행이 없으면 아무것도 그리지 않는다.
class EnvAlertCard extends StatelessWidget {
  const EnvAlertCard({super.key, required this.alerts});

  final List<EnvAlert> alerts;

  static const cardKey = Key('env_alert_card');
  static Key rowKey(EnvAlert a) => Key('env_alert_row_${a.id}');

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final glass = context.glass;
    return Container(
      key: cardKey,
      width: double.infinity,
      // Figma Alert — fill #F4F4F4 r12, 안쪽 위아래 12·좌우 8.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: glass.overlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0)
              // Figma Frame 272 — 줄 아래 12 + 하단선 1(#E3E3E3), 다음 줄까지 12.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: glass.border),
              ),
            _row(glass, alerts[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(GlassPalette glass, EnvAlert a) {
    final chipColor =
        a.metric == EnvAlertMetric.temp ? glass.tempAccent : glass.humidAccent;
    final chip = a.chip;
    return Row(
      key: rowKey(a),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chip != null) ...[
          // Figma Tag 67×24 — fill #FFFFFF r12, 글자 14/700.
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
                color: chipColor,
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
              Text(
                keepAllWords(a.title),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  height: 22.1 / 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 16 * -0.02,
                  color: glass.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                keepAllWords(a.hintKey.tr()),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  height: 19.3 / 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 14 * -0.03,
                  color: glass.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
