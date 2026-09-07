import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/skeleton_loading.dart';
import '../../../../shared/domain/num_format.dart';
import '../../domain/device_settings.dart';
import '../../domain/telemetry_reading.dart';
import '../device_settings_providers.dart';
import '../supabase_module_providers.dart';
import 'setpoint_setting_tile.dart' show showSetpointSheet;

/// 환경 모니터링 카드.
///
/// - [embedded] = true 이면 외곽 Container(배경/그림자/radius)를 그리지 않고
///   내용물 Column만 반환한다. 상위 통합 카드 셸이 감쌀 때 사용.
/// - device null / telemetry 미도착: shimmer 스켈레톤
/// - hasValue + 에러: 마지막 값 유지 + 연결 끊김 표시 (깜빡임 방지)
/// - 정상: tA/hA(메인), tB/hB(보조) 표시. ds18b20 미노출.
class ModuleStatusCard extends ConsumerWidget {
  const ModuleStatusCard({super.key, this.embedded = false});

  final bool embedded;

  static const _green = AppTheme.success;
  static const _greenBg = Color(0xFFE8F5E9);
  static const _orange = AppTheme.warning;
  static const _faultBg = Color(0xFFFFF3E0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(currentDeviceProvider);

    // 디바이스 로딩 중 or null: shimmer
    if (!deviceAsync.hasValue) {
      return embedded
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SkeletonCard(lineCount: 4, height: 120),
            )
          : const SkeletonCard(lineCount: 4, height: 160);
    }

    final device = deviceAsync.value;
    if (device == null) {
      return _buildNoDeviceCard(context);
    }

    final telemetryAsync = ref.watch(telemetryStreamProvider(device.id));
    // 목표 환경(setpoint) — REST(2026-08-18 회신 §5). 로딩·실패 중엔 목표
    // 줄만 비운다(하드코딩 상수로 메우지 않는다 — 틀린 목표는 해롭다).
    // "미설정"은 서버가 null을 **돌려줬을 때만** — 로딩/에러를 미설정이라고
    // 단정하면 설정해 둔 사용자가 다시 입력한다.
    final settingsAsync = ref.watch(deviceSettingsProvider(device.id));

    // 첫 telemetry 미도착: shimmer
    if (!telemetryAsync.hasValue) {
      return embedded
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SkeletonCard(lineCount: 4, height: 120),
            )
          : const SkeletonCard(lineCount: 4, height: 160);
    }

    final telemetry = telemetryAsync.value;
    final isOffline = !ref.watch(moduleOnlineProvider(device.id));
    final theme = Theme.of(context);

    if (telemetry == null) {
      return embedded
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SkeletonCard(lineCount: 4, height: 120),
            )
          : const SkeletonCard(lineCount: 4, height: 160);
    }

    // 오프라인이면 마지막 수신 시각을 상대 시간으로 (1분 tick으로 실시간 갱신).
    String? lastUpdate;
    if (isOffline) {
      final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
      lastUpdate = _lastUpdateText(telemetry.ts, now);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더: 디바이스 이름 + 연결 상태 점 ──────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                device.name ?? 'smart_cage_main_title'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _ConnectionBadge(offline: isOffline),
          ],
        ),
        if (isOffline) ...[
          const SizedBox(height: 6),
          _DisconnectedLabel(lastUpdate: lastUpdate),
        ],
        const SizedBox(height: 14),
        // ── Primary 센서 박스 (tA / hA) ──────────────────────────
        Row(
          children: [
            Expanded(
              child: _SensorBox(
                icon: Icons.thermostat,
                label: 'smart_cage_current_temp'.tr(),
                value: telemetry.aOk && telemetry.tA != null
                    ? '${telemetry.tA!.toStringAsFixed(1)}°'
                    : '—',
                targetLabel: _targetTempLabel(settingsAsync),
                // 목표 줄을 누르면 **이 카드의 기기**로 편집한다 — 사육장 설정
                // 타일은 홈 세트의 기기를 가리켜 여기 기기와 다를 수 있다.
                onTargetTap: () => showSetpointSheet(context, ref, device.id),
                status: telemetry.aOk,
                okBg: _greenBg,
                okFg: _green,
                faultBg: _faultBg,
                faultFg: _orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SensorBox(
                icon: Icons.water_drop_outlined,
                label: 'smart_cage_current_humidity'.tr(),
                value: telemetry.aOk && telemetry.hA != null
                    ? '${telemetry.hA!.toStringAsFixed(0)}%'
                    : '—',
                targetLabel: _targetHumidityLabel(settingsAsync),
                onTargetTap: () => showSetpointSheet(context, ref, device.id),
                status: telemetry.aOk,
                okBg: _greenBg,
                okFg: _green,
                faultBg: _faultBg,
                faultFg: _orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── 보조 센서 한 줄 (tB / hB) — ds18b20 미노출 ──────────
        _SecondaryRow(telemetry: telemetry),
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildNoDeviceCard(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'module_status_title'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off_outlined,
                size: 32,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'module_no_device'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'module_no_device_subtitle'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}

// ── 연결 상태 배지 ────────────────────────────────────────────────────────────

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.offline});

  final bool offline;

  static const _green = AppTheme.success;
  static const _orange = AppTheme.warning;

  @override
  Widget build(BuildContext context) {
    final showError = offline;
    final color = showError ? _orange : _green;
    final label = showError
        ? 'module_status_disconnected'.tr()
        : 'module_status_connected'.tr();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── 마지막 수신 상대 시간 ─────────────────────────────────────────────────────

/// [ts](마지막 telemetry 수신 시각)로부터 [now]까지 경과를 사람이 읽는
/// 상대 시간 문자열로 변환. ts가 없으면 null.
String? _lastUpdateText(DateTime? ts, DateTime now) {
  if (ts == null) return null;
  final diff = now.toUtc().difference(ts.toUtc());
  final minutes = diff.inMinutes;
  if (minutes < 1) return 'module_last_update_just'.tr();
  if (minutes < 60) {
    return 'module_last_update_min'.tr(namedArgs: {'n': '$minutes'});
  }
  final hours = diff.inHours;
  if (hours < 24) {
    return 'module_last_update_hour'.tr(namedArgs: {'n': '$hours'});
  }
  return 'module_last_update_day'.tr(namedArgs: {'n': '${diff.inDays}'});
}

// ── 연결 끊김 라벨 ────────────────────────────────────────────────────────────

class _DisconnectedLabel extends StatelessWidget {
  const _DisconnectedLabel({this.lastUpdate});

  /// "3분 전 업데이트" 같은 마지막 수신 상대 시간. null이면 "연결 끊김"으로 대체.
  final String? lastUpdate;

  @override
  Widget build(BuildContext context) {
    final reconnecting = 'module_status_reconnecting'.tr();
    final prefix = lastUpdate ?? 'module_status_disconnected'.tr();
    return Text(
      '$prefix · $reconnecting',
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.warning,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── 센서 박스 ─────────────────────────────────────────────────────────────────

/// `목표 28°` / 서버가 null이면 `목표 미설정` / 로딩·에러면 빈 줄.
String _targetTempLabel(AsyncValue<DeviceSettings> s) {
  if (!s.hasValue) return '';
  final v = s.value?.targetTempC;
  if (v == null) return 'smart_cage_target_unset'.tr();
  return 'smart_cage_target_temp_fmt'.tr(args: [formatCompact(v)]);
}

String _targetHumidityLabel(AsyncValue<DeviceSettings> s) {
  if (!s.hasValue) return '';
  final v = s.value?.targetHumidityPct;
  if (v == null) return 'smart_cage_target_unset'.tr();
  return 'smart_cage_target_humidity_fmt'.tr(args: [formatCompact(v)]);
}

class _SensorBox extends StatelessWidget {
  const _SensorBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.targetLabel,
    required this.status,
    required this.okBg,
    required this.okFg,
    required this.faultBg,
    required this.faultFg,
    this.onTargetTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String targetLabel;
  final VoidCallback? onTargetTap;
  final bool status;
  final Color okBg;
  final Color okFg;
  final Color faultBg;
  final Color faultFg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = status ? okBg : faultBg;
    final fg = status ? okFg : faultFg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: status
            ? null
            : Border.all(color: faultFg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
              if (!status) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning_amber_rounded, size: 12, color: faultFg),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          // 목표값 라인 — device_settings(REST) 값. 미설정이면 "목표 미설정".
          // 탭하면 이 기기의 목표를 편집한다.
          GestureDetector(
            key: const Key('sensor_target_tap'),
            behavior: HitTestBehavior.opaque,
            onTap: onTargetTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  targetLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onTargetTap != null && targetLabel.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.edit_outlined,
                      size: 11, color: fg.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 보조 센서 한 줄 (tB / hB) — ds18b20 미노출 ──────────────────────────────

class _SecondaryRow extends StatelessWidget {
  const _SecondaryRow({required this.telemetry});

  final TelemetryReading telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final t2TempText = telemetry.bOk && telemetry.tB != null
        ? '${telemetry.tB!.toStringAsFixed(1)}°'
        : '—';
    final t2HumText = telemetry.bOk && telemetry.hB != null
        ? '${telemetry.hB!.toStringAsFixed(0)}%'
        : '—';

    return Row(
      children: [
        Text(
          '${'module_status_secondary_label'.tr()}: T2 $t2TempText / $t2HumText',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        if (!telemetry.bOk) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.warning_amber_rounded,
            size: 11,
            color: AppTheme.warning,
          ),
        ],
      ],
    );
  }
}
