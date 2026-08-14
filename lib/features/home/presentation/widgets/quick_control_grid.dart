import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../cage_control_actions.dart';
import '../home_control_providers.dart';

/// PRD §3.4 IoT 퀵 제어판 (2x2 Grid) — A안 액세서리 타일 표면.
///
/// **사육장 제어의 유일한 진입점**이다. 한때 라이브 바로 아래 같은 4종을 담은
/// 컴팩트 바를 얹었다가 한 화면에 버튼이 두 벌 쌓여 걷어냈다(2026-08-09).
/// 다시 두 벌로 만들지 말 것 — 어느 쪽을 눌러야 하는지 매번 판단하게 된다.
///
/// 표면만 A안(Apple Home 액세서리 타일)이다 — 켜짐 = 불투명 흰 타일 + 기기색
/// 아이콘, 꺼짐 = 유리. **탭 동작은 전부 기존 [cage_control_actions] 경유**
/// (히터 2단 안전확인 포함) — 여기서 명령을 직접 만들지 말 것.
class QuickControlGrid extends ConsumerWidget {
  const QuickControlGrid({super.key});

  static const mistKey = Key('quick_control_mist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final lock = ref.watch(mistLockProvider(deviceId));
    final mistDuration = ref.watch(mistDurationProvider);
    final mistLocked = lock.isLocked(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppStyles.spacing12,
        crossAxisSpacing: AppStyles.spacing12,
        // 랩의 오버플로 교훈: 1.72도 좁은 폭(320)에서는 아이콘+두 줄 텍스트가
        // 몇 px 넘친다. 1.45로 세로 여유를 확보하고, 텍스트 블록은 타일 쪽에서
        // FittedBox로 한 번 더 방어한다.
        childAspectRatio: 1.45,
        children: [
          _Tile(
            label: 'module_actuator_fan'.tr(),
            value: _stateLabel(t?.fan),
            icon: Icons.mode_fan_off,
            tint: AppTheme.deviceFanTint,
            enabled: online,
            active: t?.fan == ActuatorState.on,
            onTap: () => handleFanTap(context, ref, deviceId, t),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            tint: AppTheme.deviceHeaterTint,
            enabled: online,
            active: t?.heaterState == ActuatorState.on,
            onTap: () => handleHeaterTap(context, ref, deviceId, t),
          ),
          _Tile(
            label: 'module_actuator_led'.tr(),
            // 밝기 %를 띄우던 자리다. 현 보드의 LED는 PWM이 아니라 on/off
            // 릴레이라 그 숫자가 기기에 반영된 적이 없다(백엔드 회신
            // 2026-08-12). 아무 효과 없는 숫자보다 비워두는 게 정직하다.
            value: '',
            icon: Icons.lightbulb_outline,
            tint: AppTheme.deviceLedTint,
            // terra-server 계약에 LED 상태 telemetry가 없다(메모리
            // project_led_control_gap). 모르는 것을 켜진 것처럼 칠하지 않는다.
            enabled: online,
            active: false,
            onTap: () => openLedSheet(context, ref, deviceId),
          ),
          _Tile(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            // 남은 초를 표시하지 않는다. build 시점 값이라 매초 갱신되지 않아
            // 멈춘 숫자를 보여주게 된다 — 없는 편이 정직하다.
            // 쿨다운이 아닐 때는 마지막에 고른 분사 시간을 띄운다.
            value: mistLocked
                ? 'home_mist_cooldown_short'.tr()
                : 'home_mist_seconds'.tr(args: ['${mistDuration.seconds}']),
            icon: Icons.water_drop_outlined,
            tint: AppTheme.deviceMistTint,
            enabled: online && !mistLocked,
            // 1회성 동작이라 '켜진 상태'가 없다.
            active: false,
            onTap: () => openMistSheet(context, ref, deviceId),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(ActuatorState? s) {
    switch (s) {
      case ActuatorState.on:
        return 'ON';
      case ActuatorState.off:
        return 'OFF';
      default:
        return '--';
    }
  }
}

/// 제어 타일 — A안 액세서리 타일 문법.
///
/// 켜짐은 **불투명 흰 타일 + 기기색 아이콘**, 꺼짐은 유리, 비활성은 흐린 유리.
/// 상태를 텍스트(`ON`/`OFF`)로만 구분하면 훑어볼 때 안 읽힌다 — 면과 색이
/// 먼저 보이고 글자가 확인해주는 순서여야 한다.
class _Tile extends StatefulWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// 기기색 (히터 주황·분무 파랑·LED 노랑·팬 민트).
  final Color tint;

  final bool enabled;

  /// 기기가 켜져 있는가. 흰 타일 전환 여부를 가른다.
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.active && widget.enabled;

    final Color iconColor;
    final TextStyle titleStyle;
    final TextStyle statusStyle;
    if (!widget.enabled) {
      iconColor = AppTheme.glassTextTertiary;
      titleStyle =
          AppTheme.glassTileTitle.copyWith(color: AppTheme.glassTextTertiary);
      statusStyle =
          AppTheme.glassTileStatus.copyWith(color: AppTheme.glassTextTertiary);
    } else if (on) {
      iconColor = widget.tint;
      titleStyle = AppTheme.glassTileTitleActive;
      statusStyle = AppTheme.glassTileStatusActive;
    } else {
      iconColor = AppTheme.glassTextSecondary;
      titleStyle = AppTheme.glassTileTitle;
      statusStyle = AppTheme.glassTileStatus;
    }

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 24, color: iconColor),
          // 텍스트 블록은 남은 높이 안에서만 그린다 — 큰 글씨 설정·좁은 폭에서
          // 넘치는 대신 비율을 유지한 채 줄어든다(랩의 오버플로 교훈).
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label, style: titleStyle, maxLines: 1),
                    if (widget.value.isNotEmpty)
                      Text(widget.value, style: statusStyle, maxLines: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // 탭 스프링 스케일(0.96→1.0) + 켜짐 시 불투명 흰 타일 전환 (A안 모션).
    //
    // **표면은 단일 AnimatedContainer 하나로 지속시킨다.** 예전처럼
    // `on ? AnimatedContainer : GlassCard`로 타입을 갈아끼우면 토글마다
    // element가 재생성돼, 새 위젯에는 출발색이 없어 200ms 전환 없이 팝만
    // 됐다. 삼항은 위젯이 아니라 decoration **안**에 둔다(서브탭 방식).
    // 켜짐/꺼짐 면은 GlassCard와 같은 토큰(blur 없는 플랫 유리 + 테두리)이다.
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      // 리셋은 enabled와 무관하게 **무조건** 한다. 눌림 도중 enabled가 플립돼
      // 콜백이 전부 null로 갈리면 GestureDetector가 recognizer를 dispose하며
      // build 중 cancel을 쏴서 debug 에러 로그 + 한 프레임 리빌드가 늘어난다.
      // 핸들러를 살려 두면 dispose 자체가 일어나지 않는다.
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: on
                ? AppTheme.glassActiveTile
                : (widget.enabled
                    ? AppTheme.glassOverlay
                    : AppTheme.glassOverlayFaint),
            borderRadius: BorderRadius.circular(AppTheme.glassTileRadius),
            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
          ),
          // 안쪽 잉크가 앉을 면 — GlassCard가 하던 Material transparency 유지.
          child: Material(type: MaterialType.transparency, child: content),
        ),
      ),
    );
  }
}
