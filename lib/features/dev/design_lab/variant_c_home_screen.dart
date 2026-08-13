import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_c_tokens.dart';

/// C안 — Copilot Money (프리미엄 데이터 시각화) 스타일 홈 체험.
///
/// 핵심 문법: 밝은 배경 + 채도 높은 그라데이션 차트 + 큰 라운드 수치.
/// 구성: 인사말 헤더 → 히어로 수치 → 그라데이션 차트(스크러버) →
/// 카테고리 그리드 → 거래 내역식 타임라인.
/// 모션: 차트 좌→우 reveal, 숫자 카운트업, 진행 링 채움.
class VariantCHomeScreen extends StatefulWidget {
  const VariantCHomeScreen({super.key});

  @override
  State<VariantCHomeScreen> createState() => _VariantCHomeScreenState();
}

class _VariantCHomeScreenState extends State<VariantCHomeScreen> {
  late final Map<LabDeviceKind, bool> _on = {
    for (final d in kLabDevices) d.kind: d.isOn,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantCTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            VariantCTokens.screenHPad,
            8,
            VariantCTokens.screenHPad,
            32,
          ),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            const _HeroNumber(),
            const SizedBox(height: 16),
            const _MainChartCard(),
            const SizedBox(height: 24),
            const Text('오늘 가동', style: VariantCTokens.sectionLabel),
            const SizedBox(height: 10),
            _categoryGrid(),
            const SizedBox(height: 24),
            const Text('타임라인', style: VariantCTokens.sectionLabel),
            const SizedBox(height: 10),
            const _TimelineList(),
          ],
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: VariantCTokens.cardGap,
      crossAxisSpacing: VariantCTokens.cardGap,
      // 1.65는 카드 내부 고정 높이(아이콘 원+제목+가동시간)가 0.5px 넘친다.
      childAspectRatio: 1.55,
      children: [
        for (final d in kLabDevices)
          _CategoryCard(
            device: d,
            isOn: _on[d.kind] ?? false,
            onTap: () => _showControlSheet(d),
          ),
      ],
    );
  }

  void _showControlSheet(LabDevice d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VariantCTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VariantCTokens.cardRadius),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final on = _on[d.kind] ?? false;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PastelIconCircle(kind: d.kind, size: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: VariantCTokens.cardTitle),
                        Text(d.statusLabel, style: VariantCTokens.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('전원', style: VariantCTokens.body),
                  activeTrackColor: _CategoryStyle.of(d.kind).on,
                  value: on,
                  onChanged: (v) {
                    setSheetState(() {});
                    setState(() => _on[d.kind] = v);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 헤더 (인사말 + 요약 + 아바타)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final weekAvg =
        kLabEnvSeries.map((p) => p.temp).reduce((a, b) => a + b) /
            kLabEnvSeries.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('좋은 밤이에요', style: VariantCTokens.cardTitle),
              const SizedBox(height: 2),
              Text(
                '이번 주 평균 ${weekAvg.toStringAsFixed(1)}℃ · 안정',
                style: VariantCTokens.caption,
              ),
            ],
          ),
        ),
        // 게코 프로필 아바타 (파스텔 원 + 아이콘 플레이스홀더).
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: VariantCTokens.fanPastel,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pets,
              size: 20, color: VariantCTokens.fanOn),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 히어로 수치 (Copilot 잔액 헤더 문법)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroNumber extends StatelessWidget {
  const _HeroNumber();

  @override
  Widget build(BuildContext context) {
    final temp = kLabCurrent.temp;
    const delta = kLabTempDelta;
    final up = delta >= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 정수부 40 Bold + 소수부 20 Medium 60% — 숫자 카운트업.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: temp - 2, end: temp),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final whole = v.truncate();
            final frac = ((v - whole) * 10).round().clamp(0, 9);
            return RichText(
              text: TextSpan(
                text: '$whole',
                style: VariantCTokens.heroNumber,
                children: [
                  TextSpan(
                      text: '.$frac℃', style: VariantCTokens.heroNumberMinor),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (up ? VariantCTokens.green : VariantCTokens.red)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${up ? '▲' : '▼'}${delta.abs().toStringAsFixed(1)}℃',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: up ? VariantCTokens.green : VariantCTokens.red,
              ),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '습도 ${kLabCurrent.humid.round()}%',
            style: VariantCTokens.value,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 메인 차트 (Cash Flow 문법: 그라데이션 영역 + reveal + 스크러버)
// ─────────────────────────────────────────────────────────────────────────────

class _MainChartCard extends StatefulWidget {
  const _MainChartCard();

  @override
  State<_MainChartCard> createState() => _MainChartCardState();
}

class _MainChartCardState extends State<_MainChartCard> {
  int _period = 0; // 0=24h 1=7d 2=30d — 더미라 시각 선택만.
  double? _scrubX; // 0~1

  static const _periods = ['24h', '7d', '30d'];

  @override
  Widget build(BuildContext context) {
    final temps = kLabEnvSeries.map((p) => p.temp).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantCTokens.card,
        borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
        boxShadow: const [VariantCTokens.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _scrubLabel(temps),
                style: VariantCTokens.cardTitle,
              ),
              const Spacer(),
              // 기간 칩 (더미 — 선택 시각만 바뀐다).
              for (var i = 0; i < _periods.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _period = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _period == i
                            ? VariantCTokens.textPrimary
                            : VariantCTokens.background,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _periods[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _period == i
                              ? Colors.white
                              : VariantCTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // 좌→우 reveal — 기간을 바꾸면 다시 그린다.
          TweenAnimationBuilder<double>(
            key: ValueKey(_period),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, reveal, _) {
              return GestureDetector(
                onHorizontalDragStart: (d) => _scrub(d.localPosition),
                onHorizontalDragUpdate: (d) => _scrub(d.localPosition),
                onHorizontalDragEnd: (_) => setState(() => _scrubX = null),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GradientAreaPainter(
                      values: temps,
                      reveal: reveal,
                      scrubX: _scrubX,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labHm(kLabEnvSeries.first.at),
                  style: VariantCTokens.caption),
              Text(labHm(kLabEnvSeries.last.at),
                  style: VariantCTokens.caption),
            ],
          ),
        ],
      ),
    );
  }

  String _scrubLabel(List<double> temps) {
    final x = _scrubX;
    if (x == null) return '온도 추이';
    final i = (x * (temps.length - 1)).round().clamp(0, temps.length - 1);
    final p = kLabEnvSeries[i];
    return '${labHm(p.at)} · ${p.temp.toStringAsFixed(1)}℃';
  }

  void _scrub(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // 카드 패딩(16) 안쪽 차트 폭 기준으로 정규화.
    final w = box.size.width - 32;
    setState(() => _scrubX = (local.dx / w).clamp(0.0, 1.0));
  }
}

class _GradientAreaPainter extends CustomPainter {
  _GradientAreaPainter({
    required this.values,
    required this.reveal,
    required this.scrubX,
  });

  final List<double> values;
  final double reveal;
  final double? scrubX;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final span = (max - min) == 0 ? 1.0 : max - min;
    // 위아래 여백을 조금 남긴다.
    double yOf(double v) =>
        size.height * (0.92 - 0.84 * (v - min) / span);
    double xOf(int i) => size.width * i / (values.length - 1);

    final line = Path()..moveTo(xOf(0), yOf(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(xOf(i), yOf(values[i]));
    }

    // reveal: 좌→우로 잘라 그린다.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            VariantCTokens.tempGradStart.withValues(alpha: 0.35),
            VariantCTokens.tempGradEnd.withValues(alpha: 0.02),
          ],
        ),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = VariantCTokens.chartLineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [VariantCTokens.tempGradStart, VariantCTokens.tempGradEnd],
        ),
    );
    canvas.restore();

    // 스크러버.
    final sx = scrubX;
    if (sx != null) {
      final i =
          (sx * (values.length - 1)).round().clamp(0, values.length - 1);
      final p = Offset(xOf(i), yOf(values[i]));
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = VariantCTokens.textSecondary.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = VariantCTokens.tempGradEnd,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradientAreaPainter oldDelegate) =>
      oldDelegate.reveal != reveal ||
      oldDelegate.scrubX != scrubX ||
      oldDelegate.values != values;
}

// ─────────────────────────────────────────────────────────────────────────────
// 카테고리 그리드 (지출 카테고리 카드 문법)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryStyle {
  const _CategoryStyle(this.pastel, this.on, this.icon);

  final Color pastel;
  final Color on;
  final IconData icon;

  static _CategoryStyle of(LabDeviceKind kind) => switch (kind) {
        LabDeviceKind.heater => const _CategoryStyle(
            VariantCTokens.heaterPastel,
            VariantCTokens.heaterOn,
            Icons.local_fire_department_outlined),
        LabDeviceKind.mist => const _CategoryStyle(VariantCTokens.mistPastel,
            VariantCTokens.mistOn, Icons.water_drop_outlined),
        LabDeviceKind.led => const _CategoryStyle(VariantCTokens.ledPastel,
            VariantCTokens.ledOn, Icons.light_mode_outlined),
        LabDeviceKind.fan => const _CategoryStyle(
            VariantCTokens.fanPastel, VariantCTokens.fanOn, Icons.air),
      };
}

class _PastelIconCircle extends StatelessWidget {
  const _PastelIconCircle({required this.kind, this.size = 36});

  final LabDeviceKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = _CategoryStyle.of(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: s.pastel, shape: BoxShape.circle),
      child: Icon(s.icon, size: size * 0.5, color: s.on),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.device,
    required this.isOn,
    required this.onTap,
  });

  final LabDevice device;
  final bool isOn;
  final VoidCallback onTap;

  String get _runtime {
    final m = device.todayRuntimeMinutes;
    if (m < 60) return '$m분';
    return '${m ~/ 60}시간 ${m % 60}분';
  }

  @override
  Widget build(BuildContext context) {
    final style = _CategoryStyle.of(device.kind);
    // 진행 링: 오늘 가동 시간 / 24h.
    final ratio =
        (device.todayRuntimeMinutes / (24 * 60)).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VariantCTokens.card,
          borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
          boxShadow: const [VariantCTokens.cardShadow],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PastelIconCircle(kind: device.kind),
                  const Spacer(),
                  Text(device.name, style: VariantCTokens.cardTitle),
                  Text(
                    isOn ? _runtime : '$_runtime · 꺼짐',
                    style: VariantCTokens.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 미니 진행 링 — 채움 애니메이션.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, r, _) => CustomPaint(
                size: const Size(30, 30),
                painter: _RingPainter(
                  ratio: r,
                  color: style.on,
                  track: style.pastel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.color, required this.track});

  final double ratio;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = track;
    canvas.drawCircle(c, r, trackPaint);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

// ─────────────────────────────────────────────────────────────────────────────
// 타임라인 (거래 내역 리스트 문법 — 날짜 섹션 헤더)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineList extends StatelessWidget {
  const _TimelineList();

  static LabEventKind _deviceKindOf(LabTimelineEvent e) => e.kind;

  @override
  Widget build(BuildContext context) {
    // 날짜별 그룹 (fixtures가 최신순이라 순서 유지).
    final groups = <DateTime, List<LabTimelineEvent>>{};
    for (final e in kLabTimeline) {
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      groups.putIfAbsent(day, () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              _dayLabel(entry.key),
              style: VariantCTokens.caption
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: VariantCTokens.card,
              borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
              boxShadow: const [VariantCTokens.cardShadow],
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 60,
                        color: Color(0x0F000000)),
                  _row(entry.value[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _dayLabel(DateTime day) {
    final today = DateTime(kLabNow.year, kLabNow.month, kLabNow.day);
    if (day == today) return '오늘';
    if (day == today.subtract(const Duration(days: 1))) return '어제';
    return '${day.month}월 ${day.day}일';
  }

  Widget _row(LabTimelineEvent e) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _eventIcon(_deviceKindOf(e)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: VariantCTokens.body),
                if (e.detail != null)
                  Text(e.detail!, style: VariantCTokens.caption),
              ],
            ),
          ),
          Text(labHm(e.at), style: VariantCTokens.caption),
        ],
      ),
    );
  }

  Widget _eventIcon(LabEventKind kind) {
    final (pastel, on, icon) = switch (kind) {
      LabEventKind.heater => (
          VariantCTokens.heaterPastel,
          VariantCTokens.heaterOn,
          Icons.local_fire_department_outlined
        ),
      LabEventKind.mist => (
          VariantCTokens.mistPastel,
          VariantCTokens.mistOn,
          Icons.water_drop_outlined
        ),
      LabEventKind.led => (
          VariantCTokens.ledPastel,
          VariantCTokens.ledOn,
          Icons.light_mode_outlined
        ),
      LabEventKind.fan =>
        (VariantCTokens.fanPastel, VariantCTokens.fanOn, Icons.air),
      LabEventKind.activity =>
        (VariantCTokens.fanPastel, VariantCTokens.fanOn, Icons.pets),
      LabEventKind.report => (
          VariantCTokens.mistPastel,
          VariantCTokens.mistOn,
          Icons.description_outlined
        ),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: pastel, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: on),
    );
  }
}
