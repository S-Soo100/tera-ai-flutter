import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';
import 'variant_a_widgets.dart';

/// A안 — Liquid Glass 통계 탭.
///
/// 실앱 통계 구성을 미러: 기간 세그먼트(일간/주간, 월간=흐림 '준비 중') +
/// 지표 칩(온도/습도, 마지막 하나는 못 끔) + 온습도 차트(CustomPaint) +
/// 준비 중 카드. 실 `EnvChart`·provider는 쓰지 않는다(랩 격리).
class VariantAStatsScreen extends StatefulWidget {
  const VariantAStatsScreen({super.key});

  @override
  State<VariantAStatsScreen> createState() => _VariantAStatsScreenState();
}

class _VariantAStatsScreenState extends State<VariantAStatsScreen> {
  /// 0=일간, 1=주간. (2=월간은 비활성)
  int _period = 1;
  bool _showTemp = true;
  bool _showHumid = true;

  void _toggleMetric(bool isTemp) {
    setState(() {
      if (isTemp) {
        // 마지막 하나는 못 끈다 — 빈 플롯은 고장으로 읽힌다.
        if (_showTemp && !_showHumid) return;
        _showTemp = !_showTemp;
      } else {
        if (_showHumid && !_showTemp) return;
        _showHumid = !_showHumid;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AScreenScaffold(
      title: '통계',
      children: [
        AGlassSegment(
          labels: const ['일간', '주간', '월간'],
          selected: _period,
          onSelected: (i) => setState(() => _period = i),
          disabledFrom: 2,
          disabledHint: '준비 중',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricChip(
              label: '온도',
              tint: VariantATokens.heaterTint,
              active: _showTemp,
              onTap: () => _toggleMetric(true),
            ),
            const SizedBox(width: 8),
            _MetricChip(
              label: '습도',
              tint: VariantATokens.mistTint,
              active: _showHumid,
              onTap: () => _toggleMetric(false),
            ),
          ],
        ),
        const SizedBox(height: VariantATokens.tileGap),
        _ChartCard(
          isDaily: _period == 0,
          showTemp: _showTemp,
          showHumid: _showHumid,
        ),
        const SizedBox(height: 20),
        const ASectionLabel('더 깊은 분석'),
        const _PendingCard(
          icon: Icons.auto_awesome,
          title: 'AI 주간 요약',
          reason: '데이터 수집 중 — 준비되면 열린다',
        ),
        const SizedBox(height: VariantATokens.tileGap),
        const _PendingCard(
          icon: Icons.pets,
          title: '행동 분석',
          reason: '비전 모델 학습 중 — 준비되면 열린다',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 지표 칩
// ─────────────────────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.tint,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color tint;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: active ? 1.0 : 0.45,
        child: AGlassCapsule(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? tint : VariantATokens.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: VariantATokens.tileStatus),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 차트 카드 (일간=24h 곡선, 주간=7일 범위 바 + 습도 곡선)
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.isDaily,
    required this.showTemp,
    required this.showHumid,
  });

  final bool isDaily;
  final bool showTemp;
  final bool showHumid;

  @override
  Widget build(BuildContext context) {
    return AGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isDaily ? '지난 24시간' : '지난 7일',
                  style: VariantATokens.tileTitle),
              const Spacer(),
              Flexible(
                child: Text(
                  isDaily
                      ? '최고 ${kLabTempMax.toStringAsFixed(1)}℃ · '
                          '최저 ${kLabTempMin.toStringAsFixed(1)}℃'
                      : '최고 ${kLabWeekTempMax.toStringAsFixed(1)}℃ · '
                          '최저 ${kLabWeekTempMin.toStringAsFixed(1)}℃',
                  style: VariantATokens.tileStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 168,
            child: CustomPaint(
              size: Size.infinite,
              painter: isDaily
                  ? _DailyChartPainter(showTemp: showTemp, showHumid: showHumid)
                  : _WeeklyChartPainter(
                      showTemp: showTemp, showHumid: showHumid),
            ),
          ),
          const SizedBox(height: 8),
          if (isDaily)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final h in const ['-24h', '-18h', '-12h', '-6h', '지금'])
                  Text(h,
                      style: VariantATokens.tileStatus.copyWith(fontSize: 10)),
              ],
            )
          else
            Row(
              children: [
                for (final d in kLabWeekEnv)
                  Expanded(
                    child: Text(
                      kLabWeekdayKo[d.day.weekday - 1],
                      textAlign: TextAlign.center,
                      style: VariantATokens.tileStatus.copyWith(fontSize: 10),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: isDaily ? '평균 온도' : '주간 평균 온도',
                  value: isDaily
                      ? '${_avg(kLabEnvSeries.map((p) => p.temp)).toStringAsFixed(1)}℃'
                      : '${kLabWeekTempAvg.toStringAsFixed(1)}℃',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: isDaily ? '평균 습도' : '주간 평균 습도',
                  value: isDaily
                      ? '${_avg(kLabEnvSeries.map((p) => p.humid)).round()}%'
                      : '${kLabWeekHumidAvg.round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static double _avg(Iterable<double> vs) =>
      vs.reduce((a, b) => a + b) / vs.length;
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantATokens.tileStatus),
        const SizedBox(height: 2),
        Text(value, style: VariantATokens.chipValue),
      ],
    );
  }
}

/// 일간 — 24시간 곡선(온도·습도 각자 정규화, 홈 미니 차트 문법 확대).
class _DailyChartPainter extends CustomPainter {
  _DailyChartPainter({required this.showTemp, required this.showHumid});

  final bool showTemp;
  final bool showHumid;

  @override
  void paint(Canvas canvas, Size size) {
    // 격자·폴리라인은 공용 헬퍼 한 벌([aChartGrid]/[aPolylinePath]) —
    // 홈 미니 차트와 같은 수식. inset 6%는 곡선이 카드 모서리에 닿지 않게.
    aChartGrid(canvas, size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (showTemp) {
      canvas.drawPath(
        aPolylinePath(size, kLabEnvSeries.map((p) => p.temp).toList(),
            inset: 0.06),
        stroke..color = VariantATokens.heaterTint,
      );
    }
    if (showHumid) {
      canvas.drawPath(
        aPolylinePath(size, kLabEnvSeries.map((p) => p.humid).toList(),
            inset: 0.06),
        stroke..color = VariantATokens.mistTint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DailyChartPainter old) =>
      old.showTemp != showTemp || old.showHumid != showHumid;
}

/// 주간 — 일별 온도 범위 바(최저~최고) + 평균 점, 습도는 평균 곡선.
class _WeeklyChartPainter extends CustomPainter {
  _WeeklyChartPainter({required this.showTemp, required this.showHumid});

  final bool showTemp;
  final bool showHumid;

  // 온도 축 고정(비교 안정): 23~30℃.
  static const _tFloor = 23.0;
  static const _tCeil = 30.0;
  // 습도 축 고정: 50~75%.
  static const _hFloor = 50.0;
  static const _hCeil = 75.0;

  @override
  void paint(Canvas canvas, Size size) {
    final days = kLabWeekEnv;
    final slot = size.width / days.length;

    // 가로 격자 — 공용 [aChartGrid].
    aChartGrid(canvas, size);

    double tempY(double v) =>
        size.height * (1 - (v - _tFloor) / (_tCeil - _tFloor));
    double humidY(double v) =>
        size.height * (1 - (v - _hFloor) / (_hCeil - _hFloor));

    if (showTemp) {
      final barW = slot * 0.22;
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        final cx = slot * i + slot / 2;
        // 최저~최고 범위 바.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - barW / 2,
              tempY(d.tempMax),
              cx + barW / 2,
              tempY(d.tempMin),
            ),
            Radius.circular(barW / 2),
          ),
          Paint()
            ..color = VariantATokens.heaterTint
                .withValues(alpha: d.isWarning ? 0.85 : 0.45),
        );
        // 평균 점.
        canvas.drawCircle(
          Offset(cx, tempY(d.tempAvg)),
          3,
          Paint()..color = VariantATokens.heaterTint,
        );
      }
    }

    if (showHumid) {
      final path = Path();
      for (var i = 0; i < days.length; i++) {
        final x = slot * i + slot / 2;
        final y = humidY(days[i].humidAvg);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = VariantATokens.mistTint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter old) =>
      old.showTemp != showTemp || old.showHumid != showHumid;
}

// ─────────────────────────────────────────────────────────────────────────────
// 준비 중 카드
// ─────────────────────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.icon,
    required this.title,
    required this.reason,
  });

  final IconData icon;
  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: AGlass(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: VariantATokens.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VariantATokens.tileTitle),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: VariantATokens.tileStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline,
                size: 16, color: VariantATokens.textSecondary),
          ],
        ),
      ),
    );
  }
}
