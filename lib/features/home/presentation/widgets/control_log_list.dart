import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/actuator_marker.dart';
import '../../../../shared/domain/control_log.dart';
import '../../../../shared/domain/num_format.dart';

/// 시각을 `오전 11:23`으로. 키는 통계 스크러버와 같은 것을 재사용한다 —
/// 같은 개념(시각 표기)을 화면마다 다른 키로 두면 문구 수정이 반쪽 난다.
String formatAmPmTime(DateTime at) {
  final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return (at.hour < 12 ? 'stats_scrub_time_am' : 'stats_scrub_time_pm').tr(
    namedArgs: {'h': '$h12', 'm': at.minute.toString().padLeft(2, '0')},
  );
}

/// 기기 종류 → 아이콘. **홈 제어 그리드([CageControlGrid])와 같은 그림**을
/// 쓴다 — 그리드에서 누른 버튼과 기록의 아이콘이 다르면 같은 기기로 안 읽힌다.
IconData controlKindIcon(MarkerKind kind) => switch (kind) {
      MarkerKind.fan => Icons.wind_power,
      MarkerKind.mist => Icons.water_drop,
      MarkerKind.heater => Icons.local_fire_department,
      MarkerKind.led => Icons.lightbulb,
    };

/// 기기 종류 → 이름 키 (계획서 §A.5 — fan=환기팬, heater=히터팬).
String controlKindNameKey(MarkerKind kind) => switch (kind) {
      MarkerKind.fan => 'device_vent_fan',
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
      color: glass.surfaceHeader,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'env_detail_control_log'.tr(),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 18 * -0.02,
              color: glass.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
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
    // 온습도 매칭은 같은 버킷에서 오므로 둘 다 있거나 둘 다 없다.
    final hasEnv = entry.temperature != null && entry.humidity != null;

    // 델타는 off 로우에만 온다(도메인 보장) — 있으면 델타, 없으면 캡션.
    final deltaParts = [
      if (entry.deltaTemperature case final dT?)
        'env_detail_delta_temp'.tr(args: [_signed(dT)]),
      if (entry.deltaHumidity case final dH?)
        'env_detail_delta_humid'.tr(args: [_signed(dH)]),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: controlEntryColor(entry, glass),
            shape: BoxShape.circle,
          ),
          child: Icon(controlKindIcon(entry.kind), size: 18, color: Colors.white),
        ),
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
                  fontWeight: FontWeight.w600,
                  letterSpacing: 16 * -0.02,
                  color: glass.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatAmPmTime(entry.at),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: glass.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // 온습도를 모르면(30분 넘게 이격) 우측 열 자체를 생략한다 —
        // `--`를 찍으면 "센서가 0을 쟀다"로 읽힌다.
        if (hasEnv)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'env_detail_env_value'.tr(args: [
                  formatCompact(entry.temperature!),
                  formatCompact(entry.humidity!),
                ]),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 16 * -0.02,
                  color: glass.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                deltaParts.isNotEmpty
                    ? deltaParts.join(' ')
                    : 'env_detail_at_operation'.tr(),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
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
