import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';

/// A안 — Apple Home (iOS 26, Liquid Glass) 스타일 홈 체험.
///
/// 핵심 문법: 배경(월페이퍼)이 바닥, UI는 그 위에 뜬 반투명 유리 레이어.
/// 구성: 대형 타이틀 헤더 → 카메라 카드 → 센서 칩 행 → 2×2 액세서리 타일 →
/// 미니 차트 → 타임라인. 모션: 타일 스프링 스케일, 스크롤 시 탭바 축소.
class VariantAHomeScreen extends StatefulWidget {
  const VariantAHomeScreen({super.key});

  @override
  State<VariantAHomeScreen> createState() => _VariantAHomeScreenState();
}

class _VariantAHomeScreenState extends State<VariantAHomeScreen> {
  /// 기기 on/off 로컬 상태 — fixtures 초기값에서 출발.
  late final Map<LabDeviceKind, bool> _on = {
    for (final d in kLabDevices) d.kind: d.isOn,
  };

  /// 스크롤 방향에 따라 하단 유리 독을 축소/복원 (iOS 26 문법).
  bool _dockShrunk = false;

  bool _onScroll(UserScrollNotification n) {
    final shrink = n.direction == ScrollDirection.reverse;
    if (shrink != _dockShrunk &&
        n.direction != ScrollDirection.idle) {
      setState(() => _dockShrunk = shrink);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경은 Stack의 월페이퍼가 담당 — Scaffold는 비워 둔다.
      backgroundColor: VariantATokens.wallpaperTop,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _Wallpaper()),
          NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                _header(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: VariantATokens.screenHPad),
                  sliver: SliverList.list(
                    children: [
                      const _CameraCard(),
                      const SizedBox(height: VariantATokens.tileGap),
                      const _SensorChipRow(),
                      const SizedBox(height: 20),
                      const Text('액세서리', style: VariantATokens.sectionLabel),
                      const SizedBox(height: 10),
                      _accessoryGrid(),
                      const SizedBox(height: 20),
                      const Text('온습도', style: VariantATokens.sectionLabel),
                      const SizedBox(height: 10),
                      const _MiniChartCard(),
                      const SizedBox(height: 20),
                      const Text('타임라인', style: VariantATokens.sectionLabel),
                      const SizedBox(height: 10),
                      for (final e in kLabTimeline) ...[
                        _TimelineTile(event: e),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 하단 유리 독 (가짜 탭바) — 스크롤 내리면 축소.
          Align(
            alignment: Alignment.bottomCenter,
            child: _GlassDock(shrunk: _dockShrunk),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 132,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: VariantATokens.textPrimary,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: FlexibleSpaceBar(
            expandedTitleScale: 1.8,
            titlePadding: const EdgeInsetsDirectional.only(
                start: 52, bottom: 14, end: 16),
            title: const Text('내 사육장',
                style: VariantATokens.headerTitleCollapsed),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: VariantATokens.screenHPad),
          child: _GlassCapsule(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('1번 사육장', style: VariantATokens.tileStatus),
                SizedBox(width: 4),
                Icon(Icons.expand_more,
                    size: 16, color: VariantATokens.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accessoryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: VariantATokens.tileGap,
      crossAxisSpacing: VariantATokens.tileGap,
      childAspectRatio: 1.9,
      children: [
        for (final d in kLabDevices)
          _AccessoryTile(
            device: d,
            isOn: _on[d.kind] ?? false,
            onToggle: () =>
                setState(() => _on[d.kind] = !(_on[d.kind] ?? false)),
            onLongPress: () => _showDetailSheet(d),
          ),
      ],
    );
  }

  void _showDetailSheet(LabDevice d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailSheet(device: d, isOn: _on[d.kind] ?? false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 배경 월페이퍼
// ─────────────────────────────────────────────────────────────────────────────

class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VariantATokens.wallpaperTop,
            VariantATokens.wallpaperMid,
            VariantATokens.wallpaperBottom,
          ],
        ),
      ),
      // 은은한 빛 번짐 — 유리가 "받쳐 보일" 바닥 콘텐츠.
      child: CustomPaint(painter: _GlowPainter()),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.8, size.height * 0.25),
        size.width * 0.7,
        [const Color(0x2E4FD8C4), const Color(0x004FD8C4)],
      );
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.25),
        size.width * 0.7, glow);

    final glow2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6,
        [const Color(0x244AA8FF), const Color(0x004AA8FF)],
      );
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.7),
        size.width * 0.6, glow2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 유리 조각들
// ─────────────────────────────────────────────────────────────────────────────

/// 유리 타일 공통 — blur + 흰 오버레이 + 얇은 테두리.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = VariantATokens.tileRadius,
    this.overlay = VariantATokens.glassOverlay,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final Color overlay;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: VariantATokens.blurSigma,
          sigmaY: VariantATokens.blurSigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: overlay,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: VariantATokens.glassBorder, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 카메라 카드
// ─────────────────────────────────────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  const _CameraCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(VariantATokens.tileRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 라이브 스틸 플레이스홀더 — 실제 이미지 대신 그라데이션+아이콘.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF25402F), Color(0xFF122019)],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.videocam_outlined,
                  size: 44, color: Color(0x66FFFFFF)),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _Glass(
                radius: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: VariantATokens.liveRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: VariantATokens.textPrimary,
                          letterSpacing: 0.5,
                        )),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _Glass(
                radius: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(labHm(kLabNow), style: VariantATokens.tileStatus),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 센서 칩 행 (Home 앱 '기후' 요약 문법)
// ─────────────────────────────────────────────────────────────────────────────

class _SensorChipRow extends StatelessWidget {
  const _SensorChipRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _sensorChip(
            icon: Icons.thermostat,
            tint: VariantATokens.heaterTint,
            value: '${kLabCurrent.temp.toStringAsFixed(1)}℃',
            label: '온도',
          ),
        ),
        const SizedBox(width: VariantATokens.tileGap),
        Expanded(
          child: _sensorChip(
            icon: Icons.water_drop_outlined,
            tint: VariantATokens.mistTint,
            value: '${kLabCurrent.humid.round()}%',
            label: '습도',
          ),
        ),
      ],
    );
  }

  Widget _sensorChip({
    required IconData icon,
    required Color tint,
    required String value,
    required String label,
  }) {
    return _Glass(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 8),
          Text(value, style: VariantATokens.chipValue),
          const SizedBox(width: 6),
          Text(label, style: VariantATokens.tileStatus),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 액세서리 타일 (2×2)
// ─────────────────────────────────────────────────────────────────────────────

class _AccessoryTile extends StatefulWidget {
  const _AccessoryTile({
    required this.device,
    required this.isOn,
    required this.onToggle,
    required this.onLongPress,
  });

  final LabDevice device;
  final bool isOn;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  State<_AccessoryTile> createState() => _AccessoryTileState();
}

class _AccessoryTileState extends State<_AccessoryTile> {
  bool _pressed = false;

  static const _tints = {
    LabDeviceKind.heater: VariantATokens.heaterTint,
    LabDeviceKind.mist: VariantATokens.mistTint,
    LabDeviceKind.led: VariantATokens.ledTint,
    LabDeviceKind.fan: VariantATokens.fanTint,
  };
  static const _icons = {
    LabDeviceKind.heater: Icons.local_fire_department_outlined,
    LabDeviceKind.mist: Icons.water_drop_outlined,
    LabDeviceKind.led: Icons.light_mode_outlined,
    LabDeviceKind.fan: Icons.air,
  };

  @override
  Widget build(BuildContext context) {
    final on = widget.isOn;
    final tint = _tints[widget.device.kind]!;

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icons[widget.device.kind],
              size: 24,
              color: on ? tint : VariantATokens.textSecondary),
          const Spacer(),
          Text(widget.device.name,
              style: on
                  ? VariantATokens.tileTitleActive
                  : VariantATokens.tileTitle),
          Text(
            on ? widget.device.statusLabel : '꺼짐',
            style: on
                ? VariantATokens.tileStatusActive
                : VariantATokens.tileStatus,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // 탭 스프링 스케일(0.96→1.0) + 활성 시 불투명 흰 타일로 전환.
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onToggle,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: on
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: VariantATokens.activeTile,
                  borderRadius:
                      BorderRadius.circular(VariantATokens.tileRadius),
                ),
                child: content,
              )
            : _Glass(child: content),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 롱프레스 상세 시트 (더미)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({required this.device, required this.isOn});

  final LabDevice device;
  final bool isOn;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  double _level = 0.7;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VariantATokens.screenHPad),
      child: _Glass(
        overlay: VariantATokens.glassOverlayStrong,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name, style: VariantATokens.tileTitle),
            const SizedBox(height: 4),
            Text(
              widget.isOn ? widget.device.statusLabel : '꺼짐',
              style: VariantATokens.tileStatus,
            ),
            const SizedBox(height: 16),
            // 더미 세기 슬라이더 — 상세 제어 문법 자리만 확인.
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: VariantATokens.activeTile,
                inactiveTrackColor: VariantATokens.glassOverlay,
                thumbColor: Colors.white,
                trackHeight: 28,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _level,
                onChanged: (v) => setState(() => _level = v),
              ),
            ),
            const SizedBox(height: 8),
            Text('세기 ${(_level * 100).round()}% (더미)',
                style: VariantATokens.tileStatus),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 미니 차트 (유리 카드 + 더미 곡선)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniChartCard extends StatelessWidget {
  const _MiniChartCard();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('지난 24시간', style: VariantATokens.tileTitle),
              const Spacer(),
              Text(
                '최고 ${kLabTempMax.toStringAsFixed(1)}℃ · '
                '최저 ${kLabTempMin.toStringAsFixed(1)}℃',
                style: VariantATokens.tileStatus,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: CustomPaint(
              size: Size.infinite,
              painter: _MiniChartPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawLine(
      canvas,
      size,
      kLabEnvSeries.map((p) => p.temp).toList(),
      VariantATokens.heaterTint,
    );
    _drawLine(
      canvas,
      size,
      kLabEnvSeries.map((p) => p.humid).toList(),
      VariantATokens.mistTint,
    );
  }

  void _drawLine(Canvas canvas, Size size, List<double> vs, Color color) {
    final min = vs.reduce((a, b) => a < b ? a : b);
    final max = vs.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1 : max - min;

    final path = Path();
    for (var i = 0; i < vs.length; i++) {
      final x = size.width * i / (vs.length - 1);
      final y = size.height * (1 - (vs[i] - min) / span);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 타임라인 (얇은 유리 카드)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final LabTimelineEvent event;

  static const _icons = {
    LabEventKind.heater: Icons.local_fire_department_outlined,
    LabEventKind.mist: Icons.water_drop_outlined,
    LabEventKind.led: Icons.light_mode_outlined,
    LabEventKind.fan: Icons.air,
    LabEventKind.activity: Icons.pets,
    LabEventKind.report: Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(_icons[event.kind],
              size: 18, color: VariantATokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.detail == null
                  ? event.title
                  : '${event.title} · ${event.detail}',
              style: VariantATokens.tileStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(labHm(event.at), style: VariantATokens.tileStatus),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 하단 유리 독 (가짜 탭바 — 스크롤 축소/복원 모션 확인용)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassDock extends StatelessWidget {
  const _GlassDock({required this.shrunk});

  final bool shrunk;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + 12),
      child: AnimatedScale(
        scale: shrunk ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: shrunk ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 260),
          child: _Glass(
            radius: 100,
            overlay: VariantATokens.glassOverlayStrong,
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.home_filled,
                    size: 22, color: VariantATokens.textPrimary),
                SizedBox(width: 26),
                Icon(Icons.bar_chart,
                    size: 22, color: VariantATokens.textSecondary),
                SizedBox(width: 26),
                Icon(Icons.pets, size: 22, color: VariantATokens.textSecondary),
                SizedBox(width: 26),
                Icon(Icons.forum_outlined,
                    size: 22, color: VariantATokens.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
