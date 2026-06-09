import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/actuator_state.dart';
import '../../domain/device.dart';
import '../../domain/device_command.dart';
import '../../domain/telemetry_reading.dart';
import '../supabase_module_providers.dart';
import 'heater_lock_dialog.dart';

/// 액추에이터 제어 카드 (Supabase commands/telemetry 기반).
///
/// - currentDeviceProvider로 device 획득
/// - telemetryStreamProvider로 relay/fan/heaterState/heaterLocked 표시
/// - moduleCommandSenderProvider.notifier.send()로 명령 발행
/// - commandUpdatesProvider listen으로 pending → acked/rejected 피드백
class ActuatorControls extends ConsumerStatefulWidget {
  const ActuatorControls({super.key});

  @override
  ConsumerState<ActuatorControls> createState() => _ActuatorControlsState();
}

class _ActuatorControlsState extends ConsumerState<ActuatorControls> {
  // pending 명령 ID 집합 — 발행 후 commandUpdatesProvider가 응답하면 제거
  final Set<String> _pendingIds = {};

  // LED 밝기 버튼 디바운스
  DateTime? _lastLedBrightnessAt;
  bool _ledBrightnessDebouncing = false;

  // LED 전원 버튼 시각 피드백
  bool _ledPulsing = false;

  static const int _debounceMs = 220;

  @override
  void initState() {
    super.initState();
    // commandUpdatesProvider: listen은 initState 이후 첫 build에서 등록됨.
    // ConsumerStatefulWidget에서 ref.listen은 build() 안에서 호출해야 한다.
  }

  @override
  Widget build(BuildContext context) {
    // commands-rt 결과 수신 — pending 매칭 시 피드백 후 해제
    ref.listen<AsyncValue<DeviceCommand>>(
      commandUpdatesProvider,
      (_, next) {
        next.whenData((cmd) {
          if (!_pendingIds.contains(cmd.id)) return;
          // 종결 상태에서만 pending 해제 — sent/pending 중간 UPDATE는 유지.
          // (sent에서 풀면 이후 acked의 rejected_locked 등 거부 피드백을 놓침)
          final isTerminal = cmd.status == CommandStatus.acked ||
              cmd.status == CommandStatus.rejected ||
              cmd.status == CommandStatus.expired;
          if (!isTerminal) return;
          setState(() => _pendingIds.remove(cmd.id));
          _handleCommandResult(cmd);
        });
      },
    );

    final deviceAsync = ref.watch(currentDeviceProvider);

    // 디바이스 로딩 중
    if (!deviceAsync.hasValue) {
      return _buildCard(
        context,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _BusyRow(),
        ),
      );
    }

    final device = deviceAsync.value;

    // 디바이스 없음
    if (device == null) {
      return _buildCard(
        context,
        child: _NoDeviceContent(),
      );
    }

    final telemetryAsync = ref.watch(telemetryStreamProvider(device.id));

    // 연결 완전 끊김 (hasValue 없음 + 에러)
    if (!telemetryAsync.hasValue && telemetryAsync.hasError) {
      return _buildCard(
        context,
        child: _OfflineContent(
          onRetry: () => ref.invalidate(telemetryStreamProvider(device.id)),
        ),
      );
    }

    // 첫 로딩 (값 없음, 에러도 없음)
    if (!telemetryAsync.hasValue) {
      return _buildCard(
        context,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _BusyRow(),
        ),
      );
    }

    final telemetry = telemetryAsync.value;
    final isOffline = telemetryAsync.hasError;

    // telemetry null 방어
    if (telemetry == null) {
      return _buildCard(
        context,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _BusyRow(),
        ),
      );
    }

    final hasPending = _pendingIds.isNotEmpty;

    return _buildCard(
      context,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 행 1: 팬 + 히터 ──────────────────────────────────────
              Row(
                children: [
                  _ActuatorChip(
                    label: 'module_actuator_fan'.tr(),
                    icon: Icons.air,
                    state: telemetry.fan,
                    isBusy: hasPending,
                    onTap: () => _sendCommand(
                      context,
                      device,
                      CommandAction.fanToggle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaterChip(
                    heaterState: telemetry.heater,
                    isBusy: hasPending,
                    onTap: () =>
                        _handleHeaterTap(context, device, telemetry),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── 행 2: LED 전원 + 밝기 ─────────────────────────────────
              Row(
                children: [
                  _LedOnChip(
                    pulsing: _ledPulsing,
                    isBusy: hasPending,
                    onTap: () => _ledOn(context, device),
                  ),
                  const SizedBox(width: 8),
                  _LedBrightnessRow(
                    debouncing: _ledBrightnessDebouncing,
                    isBusy: hasPending,
                    onUp: () =>
                        _ledBrightness(context, device, up: true),
                    onDown: () =>
                        _ledBrightness(context, device, up: false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── 행 3: 릴레이 ─────────────────────────────────────────
              _ActuatorChip(
                label: 'module_actuator_relay'.tr(),
                icon: Icons.electrical_services_outlined,
                state: telemetry.relay,
                isBusy: hasPending,
                onTap: () => _sendCommand(
                  context,
                  device,
                  CommandAction.relayToggle,
                ),
              ),
            ],
          ),
          // hasValue 있지만 에러 중인 오버레이
          if (isOffline)
            Positioned.fill(
              child: _OfflineContent(
                onRetry: () =>
                    ref.invalidate(telemetryStreamProvider(device.id)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
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
            'module_actuators_title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── 명령 발행 공통 ───────────────────────────────────────────────────────────

  Future<void> _sendCommand(
    BuildContext context,
    Device device,
    CommandAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cmd = await ref
          .read(moduleCommandSenderProvider.notifier)
          .send(device.id, action);
      if (mounted) {
        setState(() => _pendingIds.add(cmd.id));
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorOn(messenger);
    }
  }

  // ── 히터 탭 처리 ─────────────────────────────────────────────────────────────

  Future<void> _handleHeaterTap(
    BuildContext context,
    Device device,
    TelemetryReading telemetry,
  ) async {
    // 잠긴 상태면 해제 다이얼로그 먼저
    if (telemetry.heaterLocked) {
      await showHeaterLockDialog(context, ref, deviceId: device.id);
      return;
    }

    // 히터 토글은 위험 액션 — 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('module_heater_confirm_title'.tr()),
        content: Text('module_heater_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('module_heater_confirm_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
            ),
            child: Text('module_heater_confirm_yes'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    await _sendCommand(context, device, CommandAction.heaterToggle);
    // 명령 결과는 commandUpdatesProvider listen에서 처리됨.
    // rejected_locked 응답 시 _handleCommandResult → 잠금 다이얼로그.
  }

  // ── LED 전원 ─────────────────────────────────────────────────────────────────

  Future<void> _ledOn(BuildContext context, Device device) async {
    if (_ledPulsing) return;
    setState(() => _ledPulsing = true);
    await _sendCommand(context, device, CommandAction.ledOn);
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _ledPulsing = false);
    }
  }

  // ── LED 밝기 ─────────────────────────────────────────────────────────────────

  Future<void> _ledBrightness(
    BuildContext context,
    Device device, {
    required bool up,
  }) async {
    final now = DateTime.now();
    if (_lastLedBrightnessAt != null) {
      final diff = now.difference(_lastLedBrightnessAt!).inMilliseconds;
      if (diff < _debounceMs) {
        if (!_ledBrightnessDebouncing) {
          setState(() => _ledBrightnessDebouncing = true);
          final remaining = _debounceMs - diff;
          Future.delayed(Duration(milliseconds: remaining), () {
            if (mounted) setState(() => _ledBrightnessDebouncing = false);
          });
        }
        return;
      }
    }
    _lastLedBrightnessAt = now;
    setState(() => _ledBrightnessDebouncing = true);
    await _sendCommand(
      context,
      device,
      up ? CommandAction.ledUp : CommandAction.ledDown,
    );
    await Future.delayed(const Duration(milliseconds: _debounceMs));
    if (mounted) setState(() => _ledBrightnessDebouncing = false);
  }

  // ── 명령 결과 피드백 ─────────────────────────────────────────────────────────

  void _handleCommandResult(DeviceCommand cmd) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final status = cmd.status;
    final result = cmd.result;

    if (status == CommandStatus.acked && result == CommandResult.ok) {
      // 성공: 조용히 처리 (telemetry stream이 UI 자동 갱신)
      return;
    }

    String message;
    Color? bgColor;

    if (result == CommandResult.rejectedLocked) {
      message = 'module_cmd_rejected_locked'.tr();
      bgColor = const Color(0xFFFF8F00);
      // 잠금 해제 다이얼로그는 heaterState telemetry로 자동 감지됨
    } else if (result == CommandResult.rejectedTtlExpired ||
        status == CommandStatus.expired) {
      message = 'module_cmd_rejected_ttl'.tr();
      bgColor = Colors.red;
    } else if (result == CommandResult.rejectedUnknownAction) {
      message = 'module_cmd_rejected_unknown'.tr();
      bgColor = Colors.red;
    } else if (result == CommandResult.rejectedDuplicateMsgId) {
      message = 'module_cmd_rejected_duplicate'.tr();
    } else if (status == CommandStatus.rejected) {
      message = 'module_cmd_rejected_generic'.tr();
      bgColor = Colors.red;
    } else {
      // sent/pending 등 중간 상태 — 무시
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorOn(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('module_action_error'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── 디바이스 없음 콘텐츠 ──────────────────────────────────────────────────────

class _NoDeviceContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: 28,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'module_no_device'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 일반 액추에이터 칩 ────────────────────────────────────────────────────────

class _ActuatorChip extends StatelessWidget {
  const _ActuatorChip({
    required this.label,
    required this.icon,
    required this.state,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ActuatorState state;
  final bool isBusy;
  final VoidCallback onTap;

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = state == ActuatorState.on;
    final isUnavailable = state == ActuatorState.unavailable;

    final bgColor = isUnavailable
        ? theme.colorScheme.surfaceContainerHigh
        : isOn
            ? _green
            : theme.colorScheme.surface;
    final fgColor = isUnavailable
        ? theme.colorScheme.outline
        : isOn
            ? Colors.white
            : theme.colorScheme.onSurface;
    final borderColor = isOn ? _green : theme.colorScheme.outlineVariant;
    final stateLabel = isUnavailable
        ? ''
        : isOn
            ? 'module_actuator_state_on'.tr()
            : 'module_actuator_state_off'.tr();

    return GestureDetector(
      onTap: isUnavailable
          ? () => _showUnavailable(context)
          : isBusy
              ? null
              : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(
              stateLabel.isNotEmpty ? '$label $stateLabel' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
            if (isBusy && !isUnavailable) ...[
              const SizedBox(width: 6),
              _BusyDot(color: fgColor),
            ],
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('module_actuator_unavailable'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── 히터 칩 (잠금 아이콘 포함) ──────────────────────────────────────────────

class _HeaterChip extends StatelessWidget {
  const _HeaterChip({
    required this.heaterState,
    required this.isBusy,
    required this.onTap,
  });

  final HeaterState heaterState;
  final bool isBusy;
  final VoidCallback onTap;

  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFFF8F00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = heaterState.state == ActuatorState.on;
    final isUnavailable = heaterState.state == ActuatorState.unavailable;
    final locked = heaterState.locked;

    final bgColor = locked
        ? const Color(0xFFFFF3E0)
        : isUnavailable
            ? theme.colorScheme.surfaceContainerHigh
            : isOn
                ? _green
                : theme.colorScheme.surface;

    final fgColor = locked
        ? _orange
        : isUnavailable
            ? theme.colorScheme.outline
            : isOn
                ? Colors.white
                : theme.colorScheme.onSurface;

    final borderColor = locked
        ? _orange.withValues(alpha: 0.5)
        : isOn
            ? _green
            : theme.colorScheme.outlineVariant;

    final stateLabel = locked
        ? 'module_actuator_state_locked'.tr()
        : isUnavailable
            ? ''
            : isOn
                ? 'module_actuator_state_on'.tr()
                : 'module_actuator_state_off'.tr();

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.whatshot_outlined, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(
              stateLabel.isNotEmpty
                  ? '${'module_actuator_heater'.tr()} $stateLabel'
                  : 'module_actuator_heater'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 4),
              const Icon(Icons.lock_outline, size: 13, color: _orange),
            ],
            if (isBusy) ...[
              const SizedBox(width: 6),
              _BusyDot(color: fgColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ── LED 전원 칩 ───────────────────────────────────────────────────────────────

class _LedOnChip extends StatelessWidget {
  const _LedOnChip({
    required this.pulsing,
    required this.isBusy,
    required this.onTap,
  });

  final bool pulsing;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = pulsing || isBusy;
    return GestureDetector(
      onTap: dimmed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dimmed
              ? theme.colorScheme.surfaceContainerHigh
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new,
              size: 16,
              color: dimmed
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              'module_actuator_led'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dimmed
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LED 밝기 +/- 행 ───────────────────────────────────────────────────────────

class _LedBrightnessRow extends StatelessWidget {
  const _LedBrightnessRow({
    required this.debouncing,
    required this.isBusy,
    required this.onUp,
    required this.onDown,
  });

  final bool debouncing;
  final bool isBusy;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = debouncing || isBusy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: dimmed
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrightnessBtn(
            icon: Icons.remove,
            label: 'module_actuator_brightness_down'.tr(),
            dimmed: dimmed,
            onTap: onDown,
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outlineVariant,
          ),
          _BrightnessBtn(
            icon: Icons.add,
            label: 'module_actuator_brightness_up'.tr(),
            dimmed: dimmed,
            onTap: onUp,
          ),
        ],
      ),
    );
  }
}

class _BrightnessBtn extends StatelessWidget {
  const _BrightnessBtn({
    required this.icon,
    required this.label,
    required this.dimmed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = dimmed
        ? Theme.of(context).colorScheme.outline
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: dimmed ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 오프라인 콘텐츠 ──────────────────────────────────────────────────────────

class _OfflineContent extends StatelessWidget {
  const _OfflineContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 32,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'module_device_offline'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onRetry,
              child: Text('module_device_retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 진행 표시 (CPI 금지 — 단순 회색 점) ────────────────────────────────────

class _BusyDot extends StatelessWidget {
  const _BusyDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _BusyDot(color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text(
          'module_status_reconnecting'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
