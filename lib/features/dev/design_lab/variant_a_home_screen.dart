import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'mock_live_player.dart';
import 'tokens/variant_a_tokens.dart';
import 'variant_a_widgets.dart';

/// A안 — Apple Home (iOS 26, Liquid Glass) 스타일 홈 체험.
///
/// 핵심 문법: 배경(월페이퍼)이 바닥, UI는 그 위에 뜬 반투명 유리 레이어.
/// 구성: 대형 타이틀 헤더 → 카메라 카드 → 센서 칩 행 → 2×2 액세서리 타일 →
/// 미니 차트 → 타임라인. 모션: 타일 스프링 스케일.
/// 탭바(유리 독)는 [VariantAShell]이 그린다 — 화면 내 장식 독은 제거됨.
class VariantAHomeScreen extends StatefulWidget {
  const VariantAHomeScreen({super.key, this.visible = true});

  /// 이 탭이 지금 보이는가 — 셸이 내려보낸다. mock 라이브 pause/play용.
  final bool visible;

  @override
  State<VariantAHomeScreen> createState() => _VariantAHomeScreenState();
}

class _VariantAHomeScreenState extends State<VariantAHomeScreen> {
  /// 기기 on/off 로컬 상태 — fixtures 초기값에서 출발.
  late final Map<LabDeviceKind, bool> _on = {
    for (final d in kLabDevices) d.kind: d.isOn,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경은 Stack의 월페이퍼가 담당 — Scaffold는 비워 둔다.
      backgroundColor: VariantATokens.wallpaperTop,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AWallpaper()),
          CustomScrollView(
            slivers: [
              _header(context),
              // 카메라는 **풀블리드**(2차, 2026-08-14) — 좌우 여백 밖에서
              // 화면 폭을 다 쓴다. 실앱 홈 TopFixedArea와 같은 룩.
              SliverToBoxAdapter(child: _CameraCard(visible: widget.visible)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: VariantATokens.screenHPad),
                sliver: SliverList.list(
                  children: [
                    const SizedBox(height: VariantATokens.tileGap),
                    const _SensorChipRow(),
                    const SizedBox(height: 20),
                    const ASectionLabel('액세서리'),
                    _accessoryGrid(),
                    const SizedBox(height: 20),
                    const ASectionLabel('온습도'),
                    const _MiniChartCard(),
                    const SizedBox(height: 20),
                    const ASectionLabel('타임라인'),
                    for (final e in kLabTimeline) ...[
                      _TimelineTile(event: e),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: aDockClearance),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      // 뒤로가기는 셸(VariantAShell)의 유리 캡슐이 맡는다 — 자동 leading을
      // 켜 두면 pushed 라우트에서 Material 화살표가 겹으로 뜬다.
      automaticallyImplyLeading: false,
      expandedHeight: 132,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: VariantATokens.textPrimary,
      // 핀 헤더 가림막은 플랫 반투명(바닥 톤) — blur는 스크롤 프레임마다
      // 재실행되어 쓰지 않는다.
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          color: VariantATokens.wallpaperTop.withValues(alpha: 0.85),
        ),
        child: FlexibleSpaceBar(
          expandedTitleScale: 1.3, // 17×1.3≈22 — 실앱 glassHeaderTitle과 통일
          // 가운데 정렬 — start: 52 비대칭 패딩은 좌측 뒤로 캡슐 자리를 비운
          // 것이었는데 펼침 상태에서 제목이 왼쪽으로 치우쳐 보였다(2026-08-14).
          centerTitle: true,
          titlePadding: const EdgeInsets.only(bottom: 14),
          title:
              const Text('내 사육장', style: VariantATokens.headerTitleCollapsed),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: VariantATokens.screenHPad),
          child: AGlassCapsule(
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
      // 1.9는 작은 화면에서 타일 내부 Column이 3~5px 넘친다(내용 고정 높이
      // ≈ 아이콘24+제목+상태+패딩28). 1.72로 세로 여유 확보.
      childAspectRatio: 1.72,
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
// 카메라 카드
// ─────────────────────────────────────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.visible});

  /// 홈 탭이 보일 때만 재생 — 셸 → 화면 → 여기로 내려온다.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // 풀블리드라 아래 모서리만 둥글린다.
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(VariantATokens.tileRadius),
      ),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        // 번들 루프 영상 mock 라이브. LIVE 배지·타임스탬프는 플레이어가 그린다.
        child: MockLivePlayer(
          visible: visible,
          fallback: const Stack(
            fit: StackFit.expand,
            children: [
              // 라이브 스틸 플레이스홀더 — 로딩/실패 시 바닥.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF25402F), Color(0xFF122019)],
                  ),
                ),
              ),
              Center(
                child: Icon(Icons.videocam_outlined,
                    size: 44, color: Color(0x66FFFFFF)),
              ),
            ],
          ),
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
    return AGlass(
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
              size: 24, color: on ? tint : VariantATokens.textSecondary),
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
            : AGlass(child: content),
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
      child: AGlass(
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
    return AGlass(
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
    // 정규화 폴리라인은 공용 [aPolylinePath] 한 벌 — 통계 일간 차트와 같은 수식.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      aPolylinePath(size, kLabEnvSeries.map((p) => p.temp).toList()),
      stroke..color = VariantATokens.heaterTint,
    );
    canvas.drawPath(
      aPolylinePath(size, kLabEnvSeries.map((p) => p.humid).toList()),
      stroke..color = VariantATokens.mistTint,
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
    return AGlass(
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
