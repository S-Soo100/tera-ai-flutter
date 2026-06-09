import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/telemetry_reading.dart';
import '../supabase_module_providers.dart';

/// 환경 모니터링 카드.
///
/// - device null / telemetry 미도착: shimmer 스켈레톤
/// - hasValue + 에러: 마지막 값 유지 + 연결 끊김 표시 (깜빡임 방지)
/// - 정상: tA/hA(메인), tB/hB(보조) 표시. ds18b20 미노출.
class ModuleStatusCard extends ConsumerWidget {
  const ModuleStatusCard({super.key});

  static const _green = Color(0xFF2E7D32);
  static const _greenBg = Color(0xFFE8F5E9);
  static const _orange = Color(0xFFFF8F00);
  static const _faultBg = Color(0xFFFFF3E0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(currentDeviceProvider);

    // 디바이스 로딩 중 or null: shimmer
    if (!deviceAsync.hasValue) {
      return const SkeletonCard(lineCount: 4, height: 160);
    }

    final device = deviceAsync.value;
    if (device == null) {
      return _buildNoDeviceCard(context);
    }

    final telemetryAsync = ref.watch(telemetryStreamProvider(device.id));

    // 첫 telemetry 미도착: shimmer
    if (!telemetryAsync.hasValue) {
      return const SkeletonCard(lineCount: 4, height: 160);
    }

    final telemetry = telemetryAsync.value;
    final isError = telemetryAsync.hasError;
    final theme = Theme.of(context);

    if (telemetry == null) {
      return const SkeletonCard(lineCount: 4, height: 160);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더: 디바이스 이름 + 연결 상태 점 ──────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? 'smart_cage_main_title'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'smart_cage_main_target'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              _ConnectionBadge(isError: isError, isOnline: device.isOnline),
            ],
          ),
          const SizedBox(height: 4),
          // 서브 타이틀
          Text(
            'module_status_title'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isError) ...[
            const SizedBox(height: 6),
            _DisconnectedLabel(),
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
      ),
    );
  }

  Widget _buildNoDeviceCard(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Column(
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
      ),
    );
  }
}

// ── 연결 상태 배지 ────────────────────────────────────────────────────────────

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.isError,
    required this.isOnline,
  });

  final bool isError;
  final bool isOnline;

  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFFF8F00);

  @override
  Widget build(BuildContext context) {
    final showError = isError || !isOnline;
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

// ── 연결 끊김 라벨 ────────────────────────────────────────────────────────────

class _DisconnectedLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '${'module_status_disconnected'.tr()} · ${'module_status_reconnecting'.tr()}',
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFFFF8F00),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── 센서 박스 ─────────────────────────────────────────────────────────────────

class _SensorBox extends StatelessWidget {
  const _SensorBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.okBg,
    required this.okFg,
    required this.faultBg,
    required this.faultFg,
  });

  final IconData icon;
  final String label;
  final String value;
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
          const SizedBox(height: 2),
          Text(
            status
                ? 'module_status_sensor_ok'.tr()
                : 'module_status_sensor_fault'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
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
            color: Color(0xFFFF8F00),
          ),
        ],
      ],
    );
  }
}
