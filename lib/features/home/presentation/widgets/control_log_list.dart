import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/domain/actuator_marker.dart';
import '../../../../shared/domain/am_pm_time.dart';
import '../../../../shared/domain/control_log.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../../shared/widgets/figma_icon.dart';

/// 기기 종류 → 아이콘. **홈 제어 그리드([CageControlGrid])와 같은 그림**을
/// 쓴다 — 그리드에서 누른 버튼과 기록의 아이콘이 다르면 같은 기기로 안 읽힌다.
Widget controlEntryIcon(
    ControlLogEntry entry, GlassPalette glass, double size) {
  final off = entry.state == ControlLogState.off;
  final compact = size == 28;
  if (entry.kind == MarkerKind.mist && !off) {
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: controlEntryColor(entry, glass)),
        child: FigmaIcon.metric(
            'redesign_v2/${compact ? '2828' : '3636'}/humidity_high_glyph',
            size: size));
  }
  final asset = switch (entry.kind) {
    MarkerKind.fan => FigmaIcons.fanBadge(on: !off, compact: compact),
    MarkerKind.cooling => FigmaIcons.coolingBadge(on: !off, compact: compact),
    MarkerKind.mist =>
      off ? FigmaIcons.mistOff : FigmaIcons.mistBadge(compact: compact),
    MarkerKind.led => FigmaIcons.ledBadge(on: !off, compact: compact),
    MarkerKind.heater => null,
  };
  if (asset != null) return FigmaIcon.metric(asset, size: size);
  // 히터는 기존 안전 제어용 아이콘 유지(새 Figma 제어 타일에는 없음).
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: controlEntryColor(entry, glass),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.local_fire_department,
        size: size / 2, color: glass.deviceGlyph),
  );
}

/// 기기 종류 → 이름 키 (계획서 §A.5 — fan=환기팬, heater=히터팬).
String controlKindNameKey(MarkerKind kind) => switch (kind) {
      MarkerKind.fan => 'device_vent_fan',
      MarkerKind.cooling => 'device_cool_fan',
      MarkerKind.mist => 'device_mist',
      MarkerKind.heater => 'device_heat_fan',
      MarkerKind.led => 'device_led',
    };

/// 로우/마커의 원 색 — 꺼짐은 공통 [GlassPalette.deviceOff], 켜짐·작동은
/// 기기색(§A.5). 마커 행([EnvDayChart])과 기록 리스트가 같은 규칙을 쓴다.
Color controlEntryColor(ControlLogEntry e, GlassPalette glass) =>
    e.state == ControlLogState.off
        ? glass.deviceOff
        : switch (e.kind) {
            MarkerKind.fan => glass.deviceFan,
            MarkerKind.cooling => glass.deviceCool,
            MarkerKind.mist => glass.deviceMist,
            MarkerKind.heater => glass.deviceHeat,
            MarkerKind.led => glass.deviceLed,
          };

/// 사육장 제어 기록 섹션 (Figma §A.5 하단 — bg surfaceHeader 전폭).
///
/// [entries]는 [buildControlLog] 반환 그대로(**시간 오름차순**)를 받고,
/// 화면에는 최신이 위로 온다 — 뒤집기는 여기서 한다. 호출부마다 `.reversed`를
/// 시키면 한 곳은 잊는다.
class ControlLogList extends StatelessWidget {
  const ControlLogList({super.key, required this.entries});

  final List<ControlLogEntry> entries;

  static const sectionKey = Key('env_detail_control_log');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      key: sectionKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? VivaColors.fillBack
            : glass.surfaceHeader,
        // Figma 1081:4873 Frame 110 — 상단 구분선.
        border: Border(top: BorderSide(color: glass.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'env_detail_control_log'.tr(),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              height: 20 / 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 18 * -0.02,
              color: glass.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Text(
              'env_detail_empty_log'.tr(),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: glass.textTertiary,
              ),
            )
          else
            // 최신이 위(§A.5) — buildControlLog는 오름차순을 준다.
            // (인덱스 루프인 이유: 항목 identity 비교는 const 정규화로 같은
            // 인스턴스가 생기면 간격 판정이 틀어진다.)
            for (var i = entries.length - 1; i >= 0; i--) ...[
              _LogRow(entry: entries[i]),
              if (i > 0) const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final ControlLogEntry entry;

  /// 상태 → 로우 라벨 키. `{}`에 기기명이 들어간다.
  static const _stateKey = {
    ControlLogState.on: 'env_detail_on',
    ControlLogState.off: 'env_detail_off',
    ControlLogState.ran: 'env_detail_ran',
  };

  /// `+2` / `-5` — 델타는 방향이 본체라 부호를 항상 붙인다.
  static String _signed(double v) =>
      v < 0 ? '-${formatCompact(-v)}' : '+${formatCompact(v)}';

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final name = controlKindNameKey(entry.kind).tr();

    // 델타는 off 로우에만 온다(도메인 보장) — 있으면 델타, 없으면 캡션.
    final deltaParts = [
      'env_detail_delta_temp'.tr(args: [
        entry.deltaTemperature == null ? '--' : _signed(entry.deltaTemperature!)
      ]),
      'env_detail_delta_humid'.tr(args: [
        entry.deltaHumidity == null ? '--' : _signed(entry.deltaHumidity!)
      ]),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        controlEntryIcon(entry, glass, 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stateKey[entry.state]!.tr(args: [name]),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  height: 19.09375 / 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 16 * -0.02,
                  color: glass.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatAmPmTime(entry.at),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  height: 16.70703125 / 14,
                  fontWeight: FontWeight.w500,
                  color: glass.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // Missing readings retain the value column with an explicit --.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'env_detail_env_value'.tr(args: [
                entry.temperature == null
                    ? '--'
                    : formatCompact(entry.temperature!),
                entry.humidity == null ? '--' : formatCompact(entry.humidity!),
              ]),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                height: 19.09375 / 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 16 * -0.02,
                color: glass.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.state == ControlLogState.off
                  ? deltaParts.join(' ')
                  : 'env_detail_at_operation'.tr(),
              key: entry.state == ControlLogState.off &&
                      entry.deltaTemperature == null &&
                      entry.deltaHumidity == null
                  ? const ValueKey('control-delta-unknown')
                  : null,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                height: 16.70703125 / 14,
                fontWeight: FontWeight.w500,
                color: glass.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
