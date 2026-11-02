import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../domain/env_report.dart';
import 'env_insight_card.dart';

/// 일일 분석 카드(Figma A14·A15~A18·A27·A28) — 줄마다 지표 칩 "온도"(`#D61619`)
/// / "습도"(`#2E408C`) · 서버 제목 · 서버 설명 줄(이벤트 1건 = 1줄). 카드가
/// 하나도 없으면 아무것도 그리지 않는다.
class EnvDailyReportCard extends StatelessWidget {
  const EnvDailyReportCard({super.key, required this.report});

  final EnvDailyReport report;

  static const cardKey = Key('env_daily_report_card');
  static Key rowKey(EnvReportElement e) => Key('env_daily_report_${e.name}');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return EnvInsightCard(key: cardKey, rows: [
      for (final c in report.cards)
        EnvInsightRow(
          key: rowKey(c.element),
          chip: switch (c.element) {
            EnvReportElement.temp => 'env_report_chip_temp'.tr(),
            EnvReportElement.humid => 'env_report_chip_humid'.tr(),
          },
          chipColor: switch (c.element) {
            EnvReportElement.temp => glass.tempAccent,
            EnvReportElement.humid => glass.humidAccent,
          },
          title: c.title,
          lines: c.lines,
        ),
    ]);
  }
}

/// 주간 분석 한 지표의 자리(Figma A19 차트 아래 · A20~A25·A29~A34 카드).
///
/// - 안내(`notices`, 이 지표 것)는 칩 없이 제목·본문으로, 카드보다 **위**에 둔다
///   (ERR_DISCONNECT는 카드와 함께 — 서버 §3).
/// - `ERR_NO_DATA`면 카드를 그리지 않는다(서버도 null을 준다).
/// - 카드 칩은 상태 "경고"/"주의"/"적정"(`#3C3C3C`), 모르는 상태면 칩 생략.
/// - 설명은 서버 줄마다 한 Text(Figma A20은 한 문단이지만 문장을 잇지 않는다).
/// 그릴 것이 없으면 아무것도 그리지 않는다.
class EnvWeeklyReportSection extends StatelessWidget {
  const EnvWeeklyReportSection(
      {super.key, required this.report, required this.element});

  final EnvWeeklyReport report;
  final EnvReportElement element;

  static Key cardKey(EnvReportElement e) => Key('env_weekly_report_${e.name}');
  static Key noticeKey(EnvReportElement e) =>
      Key('env_weekly_notice_${e.name}');

  /// 이 지표에 그릴 것이 있는가 — 화면이 위 간격을 넣을지 정한다.
  static bool hasContent(EnvWeeklyReport report, EnvReportElement e) =>
      report.noticesFor(e).isNotEmpty || _card(report, e) != null;

  static EnvReportCard? _card(EnvWeeklyReport report, EnvReportElement e) {
    final notices = report.noticesFor(e);
    if (notices.any((n) => n.replacesCard)) return null;
    return report.cardFor(e);
  }

  @override
  Widget build(BuildContext context) {
    final notices = report.noticesFor(element);
    final card = _card(report, element);
    if (notices.isEmpty && card == null) return const SizedBox.shrink();
    final chipKey = switch (card?.status) {
      EnvReportStatus.danger => 'env_report_status_danger',
      EnvReportStatus.caution => 'env_report_status_caution',
      EnvReportStatus.normal => 'env_report_status_normal',
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notices.isNotEmpty)
          EnvInsightCard(key: noticeKey(element), rows: [
            for (final n in notices)
              EnvInsightRow(
                title: n.title,
                lines: [if (n.body.isNotEmpty) n.body],
                lineLetterSpacing: -0.02,
              ),
          ]),
        if (notices.isNotEmpty && card != null) const SizedBox(height: 8),
        if (card != null)
          EnvInsightCard(key: cardKey(element), rows: [
            EnvInsightRow(
              chip: chipKey?.tr(),
              title: card.title,
              lines: card.lines,
              lineLetterSpacing: -0.02,
            ),
          ]),
      ],
    );
  }
}
