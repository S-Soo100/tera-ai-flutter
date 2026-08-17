import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/actuator_marker.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/hourly_env_slot.dart';
import '../home_control_providers.dart';
import 'env_section_label.dart';

/// 홈 "지난 24시간" — 애플 날씨 **시간별 예보** 문법의 가로 스트립 (2026-08-17).
///
/// 칸: `시각 / 기기 동작 아이콘 / 온도°`. 왼쪽이 "지금", 오른쪽으로 3시간
/// 간격 8칸이 과거로 이어진다. 아이콘 자리는 그 시간대에 돈 기기(히터·분무·
/// 팬·LED), 없으면 작은 점.
///
/// 데이터: [hourlyEnvSlotsProvider](24h 버킷 + 마커, 통계 차트와 같은 창).
/// "지금" 칸 온도만 [telemetryStreamProvider] 실시간 값으로 덮어쓴다.
///
/// 데이터가 하나도 없으면 **그리지 않는다** — 빈 상태 문구는 바로 아래
/// "이번 주" 카드가 맡는다. 둘 다 같은 문구를 띄우면 화면이 고장난 것처럼 보인다.
class HourlyEnvStrip extends ConsumerWidget {
  const HourlyEnvStrip({super.key});

  static const stripKey = Key('hourly_env_strip');
  static Key slotKey(int index) => Key('hourly_env_slot_$index');

  /// 칸 폭·스트립 높이. 애플 시간별 예보와 비슷한 밀도.
  static const double slotWidth = 48;
  static const double stripHeight = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(hourlyEnvSlotsProvider);
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    final current = deviceId == null
        ? null
        : ref.watch(telemetryStreamProvider(deviceId)).valueOrNull?.tA;

    final Widget body;
    switch (slotsAsync) {
      case AsyncData(:final value):
        final hasAny = value.any((s) => s.temp != null || s.kinds.isNotEmpty) ||
            current != null;
        if (!hasAny) return const SizedBox.shrink();
        body = _Strip(slots: value, current: current);
      case AsyncError():
        return const SizedBox.shrink();
      default:
        body = const _Skeleton();
    }

    return Padding(
      key: stripKey,
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        0,
      ),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(
          AppStyles.spacing16,
          AppStyles.spacing12,
          0,
          AppStyles.spacing12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppStyles.spacing16),
              child: EnvSectionLabel(
                icon: Icons.schedule,
                label: 'home_hourly_title'.tr(),
              ),
            ),
            const SizedBox(height: AppStyles.spacing8),
            SizedBox(height: stripHeight, child: body),
          ],
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.slots, required this.current});

  final List<HourlyEnvSlot> slots;
  final double? current;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: slots.length,
      itemBuilder: (context, i) {
        final s = slots[i];
        // 지금 칸은 실시간 값이 우선 — 30분 버킷은 최대 30분 늦다.
        final temp = s.isNow && current != null ? current : s.temp;
        return _Slot(
          key: HourlyEnvStrip.slotKey(i),
          slot: s,
          temp: temp,
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({super.key, required this.slot, required this.temp});

  final HourlyEnvSlot slot;
  final double? temp;

  String _timeLabel() => slot.isNow
      ? 'home_hourly_now'.tr()
      : 'home_hourly_hour'.tr(args: ['${slot.at.hour}']);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: HourlyEnvStrip.slotWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _timeLabel(),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: slot.isNow
                    ? context.glass.textPrimary
                    : context.glass.textSecondary,
                fontWeight: slot.isNow ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          _KindGlyphs(kinds: slot.kinds),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              temp == null
                  ? '--'
                  : 'home_hourly_temp'.tr(args: ['${temp!.round()}']),
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: temp == null
                    ? context.glass.textTertiary
                    : context.glass.textPrimary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 그 시간대에 돈 기기 아이콘. 통계 차트 마커와 **같은 그림·같은 틴트**다 —
/// 홈에서 본 분무 아이콘이 통계에서 다른 모양이면 다른 뜻으로 읽힌다.
class _KindGlyphs extends StatelessWidget {
  const _KindGlyphs({required this.kinds});

  final Set<MarkerKind> kinds;

  static const double _size = 14;

  /// 표시 순서·색. PRD §3.4 순서(분무·팬·히터·LED).
  static const _order = [
    MarkerKind.mist,
    MarkerKind.fan,
    MarkerKind.heater,
    MarkerKind.led,
  ];

  static Color _tint(GlassPalette glass, MarkerKind k) => switch (k) {
        MarkerKind.mist => glass.mistTint,
        MarkerKind.fan => glass.fanTint,
        MarkerKind.heater => glass.heaterTint,
        MarkerKind.led => glass.ledTint,
      };

  Widget _glyph(GlassPalette glass, MarkerKind k) {
    final color = _tint(glass, k);
    return switch (k) {
      MarkerKind.mist =>
        FigmaIcon.tinted(FigmaIcons.shower, color: color, size: _size),
      MarkerKind.fan =>
        FigmaIcon.tinted(FigmaIcons.modeFan, color: color, size: _size),
      MarkerKind.heater =>
        Icon(Icons.local_fire_department, size: _size, color: color),
      MarkerKind.led => Icon(Icons.lightbulb, size: _size, color: color),
    };
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final k in _order)
        if (kinds.contains(k)) k
    ];
    if (shown.isEmpty) {
      return Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: context.glass.textTertiary,
          shape: BoxShape.circle,
        ),
      );
    }
    // 칸 폭 48에 14pt 아이콘은 2개까지 — 그 이상은 2×2로 접는다.
    return SizedBox(
      width: HourlyEnvStrip.slotWidth - AppStyles.spacing8,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [for (final k in shown) _glyph(context.glass, k)],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    // 좁은 기기에서 칸이 넘치지 않게 잘라낸다(스크롤은 막는다 — 자리표시자다).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.only(right: AppStyles.spacing8),
              child: SkeletonLoading(
                  width: HourlyEnvStrip.slotWidth - AppStyles.spacing8,
                  height: HourlyEnvStrip.stripHeight),
            ),
        ],
      ),
    );
  }
}
