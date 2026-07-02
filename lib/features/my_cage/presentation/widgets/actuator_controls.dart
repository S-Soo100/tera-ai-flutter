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
/// - [embedded] = true 이면 외곽 Container(배경/그림자/radius)를 그리지 않고
///   내용물 Column만 반환한다. 상위 통합 카드 셸이 감쌀 때 사용.
/// - currentDeviceProvider로 device 획득
/// - telemetryStreamProvider로 relay/fan/heaterState/heaterLocked 표시
/// - moduleCommandSenderProvider.notifier.send()로 명령 발행
/// - commandUpdatesProvider listen으로 pending → acked/rejected 피드백
class ActuatorControls extends ConsumerStatefulWidget {
  const ActuatorControls({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ActuatorControls> createState() => _ActuatorControlsState();
}

class _ActuatorControlsState extends ConsumerState<ActuatorControls> {
  // pending 명령 ID 집합 — 발행 후 commandUpdatesProvider가 응답하면 제거
  final Set<String> _pendingIds = {};

  // LED 전원 버튼 시각 피드백
  bool _ledPulsing = false;

  // LED 로컬 on/off 상태 — telemetry에 LED 상태 없으므로 세션 내 추적.
  // 앱 재시작 시 false로 초기화됨 (정상 동작).
  bool _ledOn = false;

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
    final isOffline = !ref.watch(moduleOnlineProvider(device.id));

    // 첫 로딩 (값 없음)
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
          // 연결 끊김이면 제어 타일 전체의 탭을 차단 (1층 방어).
          IgnorePointer(
            ignoring: isOffline,
            child: _buildTileGrid(context, device, telemetry, hasPending),
          ),
          // 연결 끊김 오버레이 (제어 차단 표시 + 재시도)
          if (isOffline)
            Positioned.fill(
              child: _OfflineContent(
                onRetry: () {
                  ref.invalidate(telemetryStreamProvider(device.id));
                  // is_online 스냅샷도 갱신 (devices realtime 미구독).
                  ref.invalidate(deviceListProvider);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTileGrid(
    BuildContext context,
    Device device,
    TelemetryReading telemetry,
    bool hasPending,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 행 1: 팬 + 히터 ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _ActuatorTile(
                label: 'module_actuator_fan'.tr(),
                icon: Icons.air,
                state: telemetry.fan,
                isBusy: hasPending,
                accentColor: const Color(0xFF2E7D32),
                onTap: () => _sendCommand(
                  context,
                  device,
                  CommandAction.fanToggle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeaterTile(
                heaterState: telemetry.heater,
                isBusy: hasPending,
                onTap: () => _handleHeaterTap(context, device, telemetry),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── 행 2: LED 통합 타일 (전폭) ────────────────────────────
        _LedTile(
          ledOn: _ledOn,
          pulsing: _ledPulsing,
          isBusy: hasPending,
          onTurnOn: () => _ledTurnOn(context, device),
          onTurnOff: () => _ledTurnOff(context, device),
        ),
        const SizedBox(height: 12),
        // ── 행 3: 워터펌프 (전폭) ─────────────────────────────────
        _ActuatorTile(
          label: 'module_actuator_relay'.tr(),
          icon: Icons.water_drop_outlined,
          state: telemetry.relay,
          isBusy: hasPending,
          accentColor: const Color(0xFF2E7D32),
          onTap: () => _sendCommand(
            context,
            device,
            CommandAction.relayToggle,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    final titleAndChild = Column(
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
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: titleAndChild,
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
      child: titleAndChild,
    );
  }

  // ── 명령 발행 공통 ───────────────────────────────────────────────────────────

  Future<void> _sendCommand(
    BuildContext context,
    Device device,
    CommandAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // 연결 끊김 시 제어 차단 (UI가 뚫려도 명령이 나가지 않도록 최종 방어).
    if (!ref.read(moduleOnlineProvider(device.id))) {
      _showOfflineBlockedOn(messenger);
      return;
    }
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

  // ── LED 전원 켜기 ────────────────────────────────────────────────────────────

  Future<void> _ledTurnOn(BuildContext context, Device device) async {
    if (_ledPulsing) return;
    setState(() {
      _ledPulsing = true;
      _ledOn = true; // 낙관적 업데이트
    });
    await _sendCommand(context, device, CommandAction.ledOn);
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _ledPulsing = false);
    }
  }

  // ── LED 전원 끄기 ────────────────────────────────────────────────────────────
  // 낙관적 업데이트: 끄기 명령 발행 즉시 _ledOn = false.
  // 펌웨어가 led_off 미지원 시 rejected_unknown_action → _handleCommandResult가
  // 스낵바를 표시하고 _ledOn을 다시 true로 롤백한다.

  Future<void> _ledTurnOff(BuildContext context, Device device) async {
    setState(() => _ledOn = false); // 낙관적 업데이트
    await _sendCommand(context, device, CommandAction.ledOff);
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

    // led_off 거부 시 낙관적 업데이트 롤백
    if (cmd.action == CommandAction.ledOff &&
        result == CommandResult.rejectedUnknownAction) {
      setState(() => _ledOn = true);
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

  void _showOfflineBlockedOn(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('module_control_offline_blocked'.tr()),
        backgroundColor: const Color(0xFFFF8F00),
        duration: const Duration(seconds: 2),
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

// ── iOS 제어센터 스타일: 일반 액추에이터 타일 (가로 한 row 컴팩트) ───────────
//
// 레이아웃: [원형 아이콘 뱃지 32px] [라벨] (Spacer) [ON/OFF 상태 + BusyDot]
// ON=강조색 채움, OFF=surfaceContainerHighest 반투명

class _ActuatorTile extends StatelessWidget {
  const _ActuatorTile({
    required this.label,
    required this.icon,
    required this.state,
    required this.isBusy,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ActuatorState state;
  final bool isBusy;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isOn = state == ActuatorState.on;
    final isUnavailable = state == ActuatorState.unavailable;

    final Color tileBg = isUnavailable
        ? cs.surfaceContainerHigh
        : isOn
            ? accentColor
            : cs.surfaceContainerHighest;

    final Color iconBgColor = isUnavailable
        ? cs.surfaceContainerHighest
        : isOn
            ? Colors.white.withValues(alpha: 0.25)
            : accentColor.withValues(alpha: 0.12);

    final Color iconColor = isUnavailable
        ? cs.outline
        : isOn
            ? Colors.white
            : accentColor;

    final Color labelColor = isUnavailable
        ? cs.outline
        : isOn
            ? Colors.white
            : cs.onSurface;

    final String stateLabel = isUnavailable
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // 원형 아이콘 뱃지
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ),
            const SizedBox(width: 10),
            // 라벨
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ON/OFF 상태 + BusyDot
            if (stateLabel.isNotEmpty) ...[
              Text(
                stateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isBusy && !isUnavailable) ...[
                const SizedBox(width: 4),
                _BusyDot(color: labelColor),
              ],
            ] else if (isBusy && !isUnavailable) ...[
              _BusyDot(color: labelColor),
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

// ── iOS 제어센터 스타일: 히터 타일 (가로 한 row + 잠금 아이콘 인라인) ─────────

class _HeaterTile extends StatelessWidget {
  const _HeaterTile({
    required this.heaterState,
    required this.isBusy,
    required this.onTap,
  });

  final HeaterState heaterState;
  final bool isBusy;
  final VoidCallback onTap;

  static const _amber = Color(0xFFFF8F00);
  static const _amberBg = Color(0xFFFFF3E0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isOn = heaterState.state == ActuatorState.on;
    final isUnavailable = heaterState.state == ActuatorState.unavailable;
    final locked = heaterState.locked;

    final Color tileBg = locked
        ? _amberBg
        : isUnavailable
            ? cs.surfaceContainerHigh
            : isOn
                ? _amber
                : cs.surfaceContainerHighest;

    final Color iconBgColor = locked
        ? _amber.withValues(alpha: 0.2)
        : isUnavailable
            ? cs.surfaceContainerHighest
            : isOn
                ? Colors.white.withValues(alpha: 0.25)
                : _amber.withValues(alpha: 0.12);

    final Color iconColor = locked
        ? _amber
        : isUnavailable
            ? cs.outline
            : isOn
                ? Colors.white
                : _amber;

    final Color labelColor = locked
        ? _amber
        : isUnavailable
            ? cs.outline
            : isOn
                ? Colors.white
                : cs.onSurface;

    final String stateLabel = locked
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // 원형 아이콘 뱃지
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.whatshot_outlined,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 라벨
            Expanded(
              child: Text(
                'module_actuator_heater'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 상태 + 잠금 아이콘 + BusyDot
            if (stateLabel.isNotEmpty)
              Text(
                stateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (locked) ...[
              const SizedBox(width: 4),
              Icon(Icons.lock_outline, size: 13, color: _amber),
            ],
            if (isBusy) ...[
              const SizedBox(width: 4),
              _BusyDot(color: labelColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ── iOS 제어센터 스타일: LED 통합 타일 (전폭, 켜기/끄기 토글) ─────────────────
//
// _ledOn == false: [아이콘] LED (Spacer) [켜기]
// _ledOn == true:  [아이콘] LED (Spacer) [끄기]

class _LedTile extends StatelessWidget {
  const _LedTile({
    required this.ledOn,
    required this.pulsing,
    required this.isBusy,
    required this.onTurnOn,
    required this.onTurnOff,
  });

  final bool ledOn;
  final bool pulsing;
  final bool isBusy;
  final VoidCallback onTurnOn;
  final VoidCallback onTurnOff;

  // LED 강조색: Green 계열 (기존 프라이머리 컬러 유지)
  static const _ledAccent = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dimmed = pulsing || isBusy;

    final Color tileBg = ledOn
        ? _ledAccent
        : cs.surfaceContainerHighest;

    final Color iconBgColor = ledOn
        ? Colors.white.withValues(alpha: 0.25)
        : _ledAccent.withValues(alpha: 0.12);

    final Color iconColor = ledOn ? Colors.white : _ledAccent;
    final Color labelColor = ledOn ? Colors.white : cs.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // 원형 아이콘 뱃지
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.light_mode_outlined,
                size: 16,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 라벨
          Expanded(
            child: Text(
              'module_actuator_led'.tr(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 우측 컨트롤 — 켜기 / 끄기 토글
          _LedActionBtn(
            label: ledOn
                ? 'module_actuator_power_off'.tr()
                : 'module_actuator_power_on'.tr(),
            color: labelColor,
            tileBg: tileBg,
            dimmed: dimmed,
            onTap: dimmed ? null : (ledOn ? onTurnOff : onTurnOn),
          ),
          if (isBusy) ...[
            const SizedBox(width: 4),
            _BusyDot(color: labelColor),
          ],
        ],
      ),
    );
  }
}

// ── LED 액션 버튼 (켜기/끄기 텍스트 버튼) ────────────────────────────────────

class _LedActionBtn extends StatelessWidget {
  const _LedActionBtn({
    required this.label,
    required this.color,
    required this.tileBg,
    required this.dimmed,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color tileBg;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = dimmed ? color.withValues(alpha: 0.45) : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dimmed ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
              ),
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
