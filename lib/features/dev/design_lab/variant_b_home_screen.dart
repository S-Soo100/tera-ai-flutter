import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'mock_live_player.dart';
import 'tokens/variant_b_tokens.dart';

/// B안 — Flighty (공항 전광판 데이터 밀도) 스타일 홈 체험.
///
/// 핵심 문법: "라이브 상태 추적 대시보드". 상단 라이브 헤더 + 하단 카드
/// 리스트. 밤 활동(22:00~06:00)을 비행 진행 바 문법으로 보여준다.
/// 모션: 수치 카운트업, 진행 바 채움, 카드 순차 페이드+슬라이드.
class VariantBHomeScreen extends StatefulWidget {
  const VariantBHomeScreen({super.key});

  @override
  State<VariantBHomeScreen> createState() => _VariantBHomeScreenState();
}

class _VariantBHomeScreenState extends State<VariantBHomeScreen>
    with SingleTickerProviderStateMixin {
  /// 카드 순차 진입용 단일 컨트롤러 — 구간(Interval)으로 스태거를 만든다.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Map<LabDeviceKind, bool> _on = {
    for (final d in kLabDevices) d.kind: d.isOn,
  };

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// [i]번째 카드의 진입 구간 — 페이드+슬라이드.
  Widget _staggered(int i, Widget child) {
    final curved = CurvedAnimation(
      parent: _enter,
      curve: Interval(0.15 * i, 0.15 * i + 0.45, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantBTokens.background,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _LiveHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              VariantBTokens.screenHPad,
              VariantBTokens.cardGap,
              VariantBTokens.screenHPad,
              32,
            ),
            sliver: SliverList.list(
              children: [
                _staggered(0, const _TonightCard()),
                const SizedBox(height: VariantBTokens.cardGap),
                _staggered(1, const _StepTimelineCard()),
                const SizedBox(height: VariantBTokens.cardGap),
                _staggered(
                  2,
                  _ControlCard(
                    on: _on,
                    onToggle: (k) =>
                        setState(() => _on[k] = !(_on[k] ?? false)),
                  ),
                ),
                const SizedBox(height: VariantBTokens.cardGap),
                _staggered(3, const _RecentEventsCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 라이브 헤더 (상단 ~40%: 라이브 스틸 + 전광판 수치 오버레이)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveHeader extends StatelessWidget {
  const _LiveHeader();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.4;
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 번들 루프 영상 mock 라이브 — 배지는 B가 자기 오버레이로 그린다.
          const MockLivePlayer(
            showBadge: false,
            fallback: Stack(
              fit: StackFit.expand,
              children: [
                // 라이브 스틸 플레이스홀더 (그라데이션+아이콘) — 로딩/실패 시.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1D3324), Color(0xFF0E1A13)],
                    ),
                  ),
                ),
                Center(
                  child: Icon(Icons.videocam_outlined,
                      size: 52, color: Color(0x40FFFFFF)),
                ),
              ],
            ),
          ),
          // 하단으로 갈수록 배경색에 잠기는 그라데이션.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, VariantBTokens.background],
                stops: [0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: VariantBTokens.screenHPad,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: VariantBTokens.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE · 1번 사육장', style: VariantBTokens.dataLabel),
                const SizedBox(width: 8),
                Text(labHm(kLabNow), style: VariantBTokens.dataLabel),
              ],
            ),
          ),
          // 전광판 대형 수치 오버레이.
          Positioned(
            left: VariantBTokens.screenHPad,
            right: VariantBTokens.screenHPad,
            bottom: 12,
            child: Row(
              children: [
                Expanded(
                  child: _BigStat(
                    label: 'TEMP',
                    value: kLabCurrent.temp,
                    unit: '℃',
                    decimals: 1,
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: VariantBTokens.divider,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BigStat(
                    label: 'HUMIDITY',
                    value: kLabCurrent.humid,
                    unit: '%',
                    decimals: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 전광판 스타일 수치 — 진입 시 카운트업.
class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.decimals,
  });

  final String label;
  final double value;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantBTokens.dataLabel),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            '${v.toStringAsFixed(decimals)}$unit',
            style: VariantBTokens.bigNumber,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "오늘 밤" 카드 — 비행 카드 문법
// ─────────────────────────────────────────────────────────────────────────────

class _TonightCard extends StatelessWidget {
  const _TonightCard();

  @override
  Widget build(BuildContext context) {
    final night = kLabNightActivity;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('오늘 밤', style: VariantBTokens.body),
              const Spacer(),
              // ON TIME → "안정" 배지.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VariantBTokens.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '안정',
                  style: VariantBTokens.badge
                      .copyWith(color: VariantBTokens.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 출발지/도착지 대신 22:00 → 06:00.
          Row(
            children: [
              Text(labHm(night.start), style: VariantBTokens.midNumber),
              const SizedBox(width: 8),
              const Text('활동 시작', style: VariantBTokens.dataLabel),
              const Spacer(),
              const Text('활동 종료', style: VariantBTokens.dataLabel),
              const SizedBox(width: 8),
              Text(labHm(night.end), style: VariantBTokens.midNumber),
            ],
          ),
          const SizedBox(height: 10),
          _NightProgressBar(progress: night.progress),
          const SizedBox(height: 16),
          const Divider(color: VariantBTokens.divider, height: 1),
          const SizedBox(height: 12),
          // 하단 3열 데이터 그리드.
          Row(
            children: [
              Expanded(
                child: _GridStat(
                  label: 'ACTIVITY',
                  value: night.activityCount.toDouble(),
                  format: (v) => '${v.round()}회',
                ),
              ),
              Expanded(
                child: _GridStat(
                  label: 'MAX TEMP',
                  value: night.maxTemp,
                  format: (v) => '${v.toStringAsFixed(1)}℃',
                ),
              ),
              Expanded(
                child: _GridStat(
                  label: 'MIST',
                  value: night.mistCount.toDouble(),
                  format: (v) => '${v.round()}회',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 비행 진행 바 — 비행기 대신 게코 아이콘이 진행 위치에 앉는다.
class _NightProgressBar extends StatelessWidget {
  const _NightProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) {
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 22,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: VariantBTokens.progressHeight,
                    decoration: BoxDecoration(
                      color: VariantBTokens.progressTrack,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Container(
                    height: VariantBTokens.progressHeight,
                    width: w * p,
                    decoration: BoxDecoration(
                      color: VariantBTokens.amber,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Positioned(
                    left: (w * p - 11).clamp(0.0, w - 22),
                    child: const Icon(Icons.pets,
                        size: 20, color: VariantBTokens.amber),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 3열 그리드 수치 — 카운트업.
class _GridStat extends StatelessWidget {
  const _GridStat({
    required this.label,
    required this.value,
    required this.format,
  });

  final String label;
  final double value;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantBTokens.dataLabel),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) =>
              Text(format(v), style: VariantBTokens.midNumber),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 수직 스텝 타임라인 (체크인→탑승→이륙 문법 → 밤 이벤트)
// ─────────────────────────────────────────────────────────────────────────────

class _StepTimelineCard extends StatelessWidget {
  const _StepTimelineCard();

  @override
  Widget build(BuildContext context) {
    final night = kLabNightActivity;
    final steps = [
      (
        title: '첫 활동 감지',
        time: labHm(night.firstDetectedAt),
        done: true,
      ),
      (
        title: '분무 ${night.mistCount}회',
        time: labHm(DateTime(2026, 8, 12, 23, 58)),
        done: true,
      ),
      (
        title: '피크 활동',
        time: labHm(night.peakAt),
        done: true,
      ),
      (
        title: '아침 리포트',
        time: labHm(DateTime(2026, 8, 13, 7)),
        done: false,
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NIGHT TIMELINE', style: VariantBTokens.dataLabel),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _Step(
              title: steps[i].title,
              time: steps[i].time,
              done: steps[i].done,
              isLast: i == steps.length - 1,
              // 다음 스텝이 미완이면 연결선을 점선으로.
              nextDone: i + 1 < steps.length && steps[i + 1].done,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.time,
    required this.done,
    required this.isLast,
    required this.nextDone,
  });

  final String title;
  final String time;
  final bool done;
  final bool isLast;
  final bool nextDone;

  @override
  Widget build(BuildContext context) {
    final dotColor =
        done ? VariantBTokens.green : VariantBTokens.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: done ? dotColor : Colors.transparent,
                  border: Border.all(color: dotColor, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: nextDone
                      ? Container(width: 2, color: VariantBTokens.green)
                      : CustomPaint(
                          size: const Size(2, double.infinity),
                          painter: _DashedLinePainter(),
                        ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: done
                          ? VariantBTokens.body
                          : VariantBTokens.bodySecondary,
                    ),
                  ),
                  Text(time, style: VariantBTokens.bodySecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VariantBTokens.textTertiary
      ..strokeWidth = 2;
    const dash = 4.0;
    const gapLen = 4.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
      y += dash + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 제어 (가로 스크롤 캡슐 버튼 행 — 데이터가 주인공, 제어는 보조)
// ─────────────────────────────────────────────────────────────────────────────

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.on, required this.onToggle});

  final Map<LabDeviceKind, bool> on;
  final ValueChanged<LabDeviceKind> onToggle;

  static const _icons = {
    LabDeviceKind.heater: Icons.local_fire_department_outlined,
    LabDeviceKind.mist: Icons.water_drop_outlined,
    LabDeviceKind.led: Icons.light_mode_outlined,
    LabDeviceKind.fan: Icons.air,
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('CONTROLS', style: VariantBTokens.dataLabel),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final d in kLabDevices) ...[
                  _CapsuleButton(
                    icon: _icons[d.kind]!,
                    label: d.name,
                    active: on[d.kind] ?? false,
                    onTap: () => onToggle(d.kind),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? VariantBTokens.amber.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: active ? VariantBTokens.amber : VariantBTokens.divider,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active
                    ? VariantBTokens.amber
                    : VariantBTokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: VariantBTokens.bodySecondary.copyWith(
                color: active
                    ? VariantBTokens.amber
                    : VariantBTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 최근 이벤트 (전광판 리스트)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentEventsCard extends StatelessWidget {
  const _RecentEventsCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('RECENT', style: VariantBTokens.dataLabel),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < kLabTimeline.length; i++) ...[
            if (i > 0)
              const Divider(
                  color: VariantBTokens.divider, height: 1, thickness: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      labHm(kLabTimeline[i].at),
                      style: VariantBTokens.bodySecondary.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(kLabTimeline[i].title,
                        style: VariantBTokens.body),
                  ),
                  if (kLabTimeline[i].detail != null)
                    Text(
                      kLabTimeline[i].detail!,
                      style: VariantBTokens.bodySecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 카드 공통
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VariantBTokens.card,
        borderRadius: BorderRadius.circular(VariantBTokens.cardRadius),
      ),
      child: child,
    );
  }
}
