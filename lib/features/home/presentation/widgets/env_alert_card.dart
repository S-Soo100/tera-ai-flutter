import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../domain/env_alert.dart';
import 'env_insight_card.dart';

/// 온습도 상세의 v4 실시간 이탈 카드(Figma A10·A12·A13, Alert 369×139).
///
/// 줄마다 칩(서버 `message`의 `[ ]` 안) · 제목(`]` 뒤) · 설명(노션 v4 1-5 고정
/// 문구). 줄 순서·칸별 1개는 [EnvAlert.openLatestPerSlot]이 정한다 — 여기선
/// 받은 순서대로 그린다. 행이 없으면 아무것도 그리지 않는다. 겉모양은
/// [EnvInsightCard](일일·주간 분석 카드와 공용).
class EnvAlertCard extends StatelessWidget {
  const EnvAlertCard({super.key, required this.alerts});

  final List<EnvAlert> alerts;

  static const cardKey = Key('env_alert_card');
  static Key rowKey(EnvAlert a) => Key('env_alert_row_${a.id}');

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final glass = context.glass;
    return EnvInsightCard(key: cardKey, rows: [
      for (final a in alerts)
        EnvInsightRow(
          key: rowKey(a),
          chip: a.chip,
          chipColor: a.metric == EnvAlertMetric.temp
              ? glass.tempAccent
              : glass.humidAccent,
          title: a.title,
          lines: [a.hintKey.tr()],
        ),
    ]);
  }
}
