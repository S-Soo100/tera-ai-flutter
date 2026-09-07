import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';

/// 랩 A·B 공용 — 홈 온습도의 **애플 날씨 행 문법**(2026-08-17).
///
/// 실앱 `HourlyEnvStrip`·`WeeklyEnvRowsCard`와 같은 구조를 fixtures로 그린다.
/// 색·타이포는 전부 [LabWeatherStyle]로 주입한다 — A(솔리드 다크·기기 틴트)와
/// B(전광판 앰버)가 **같은 행 구조, 다른 옷**을 입는다. `AppTheme` 참조 금지(랩 격리).
class LabWeatherStyle {
  const LabWeatherStyle({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.barTrack,
    required this.barStart,
    required this.barEnd,
    required this.dot,
    required this.dotBorder,
    required this.mist,
    required this.humid,
    required this.heater,
    required this.fan,
    required this.led,
    required this.sectionLabel,
    required this.dayText,
    required this.numText,
    required this.smallText,
  });

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color barTrack;
  final Color barStart;
  final Color barEnd;
  final Color dot;
  final Color dotBorder;
  final Color mist;
  final Color humid;
  final Color heater;
  final Color fan;
  final Color led;
  final TextStyle sectionLabel;
  final TextStyle dayText;
  final TextStyle numText;
  final TextStyle smallText;

  Color tintOf(LabDeviceKind k) => switch (k) {
        LabDeviceKind.heater => heater,
        LabDeviceKind.mist => mist,
        LabDeviceKind.led => led,
        LabDeviceKind.fan => fan,
      };
}

IconData labKindIcon(LabDeviceKind k) => switch (k) {
      LabDeviceKind.heater => Icons.local_fire_department_outlined,
      LabDeviceKind.mist => Icons.water_drop_outlined,
      LabDeviceKind.led => Icons.light_mode_outlined,
      LabDeviceKind.fan => Icons.air,
    };

/// 섹션 라벨 — 작은 아이콘 + 텍스트, 오른쪽 chevron 옵션.
class LabWeatherSectionLabel extends StatelessWidget {
  const LabWeatherSectionLabel({
    super.key,
    required this.icon,
    required this.text,
    required this.style,
    this.chevron = false,
  });

  final IconData icon;
  final String text;
  final LabWeatherStyle style;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: style.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: style.sectionLabel.copyWith(letterSpacing: 0.4)),
        ),
        if (chevron)
          Icon(Icons.chevron_right, size: 16, color: style.textSecondary),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ② 지난 24시간 스트립
// ─────────────────────────────────────────────────────────────────────────────

class LabHourlyStrip extends StatelessWidget {
  const LabHourlyStrip({super.key, required this.style});

  final LabWeatherStyle style;

  static const double slotWidth = 48;
  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: kLabHourSlots.length,
        itemBuilder: (context, i) =>
            _Slot(slot: kLabHourSlots[i], style: style),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot, required this.style});

  final LabHourSlot slot;
  final LabWeatherStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LabHourlyStrip.slotWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            slot.isNow ? '지금' : '${slot.at.hour}시',
            style: style.smallText.copyWith(
              color: slot.isNow ? style.textPrimary : style.textSecondary,
              fontWeight: slot.isNow ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (slot.kinds.isEmpty)
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  color: style.textTertiary, shape: BoxShape.circle),
            )
          else
            SizedBox(
              width: LabHourlyStrip.slotWidth - 8,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final k in slot.kinds)
                    Icon(labKindIcon(k), size: 14, color: style.tintOf(k)),
                ],
              ),
            ),
          Text('${slot.temp.round()}°', style: style.numText),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 이번 주 7행
// ─────────────────────────────────────────────────────────────────────────────

class LabWeeklyRows extends StatelessWidget {
  const LabWeeklyRows({super.key, required this.style, this.onRowTap});

  final LabWeatherStyle style;
  final VoidCallback? onRowTap;

  @override
  Widget build(BuildContext context) {
    // 오늘(마지막)이 맨 위 — 아래로 과거.
    final days = kLabWeekEnv.reversed.toList(growable: false);
    final mists = kLabWeekMist.reversed.toList(growable: false);
    final lo = kLabWeekTempMin;
    final hi = kLabWeekTempMax;
    double pos(double v) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

    return Column(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: style.divider),
          InkWell(
            onTap: onRowTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      i == 0 ? '오늘' : kLabWeekdayKo[days[i].day.weekday - 1],
                      style: style.dayText.copyWith(
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: mists[i] == 0
                        ? Text('·',
                            textAlign: TextAlign.center,
                            style: style.smallText
                                .copyWith(color: style.textTertiary))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.water_drop,
                                  size: 11, color: style.mist),
                              const SizedBox(width: 2),
                              Text('${mists[i]}회',
                                  style: style.smallText.copyWith(
                                      color: style.mist,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${days[i].tempMin.round()}°',
                        textAlign: TextAlign.right,
                        style:
                            style.numText.copyWith(color: style.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 14,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _RangeBarPainter(
                          start: pos(days[i].tempMin),
                          end: pos(days[i].tempMax),
                          dot: i == 0 ? pos(kLabCurrent.temp) : null,
                          style: style,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text('${days[i].tempMax.round()}°',
                        style: style.numText
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${days[i].humidAvg.round()}%',
                        textAlign: TextAlign.right,
                        style: style.numText.copyWith(color: style.humid)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  const _RangeBarPainter({
    required this.start,
    required this.end,
    required this.dot,
    required this.style,
  });

  final double start;
  final double end;
  final double? dot;
  final LabWeatherStyle style;

  static const double h = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = const Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - h / 2, size.width, cy + h / 2, r),
      Paint()..color = style.barTrack,
    );
    final left = start * size.width;
    final right = math.max(end * size.width, left + h);
    final fill = RRect.fromLTRBR(left, cy - h / 2, right, cy + h / 2, r);
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = LinearGradient(colors: [style.barStart, style.barEnd])
            .createShader(fill.outerRect),
    );
    final d = dot;
    if (d != null) {
      final cx = d * size.width;
      canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = style.dotBorder);
      canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = style.dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RangeBarPainter old) =>
      old.start != start || old.end != end || old.dot != dot;
}
