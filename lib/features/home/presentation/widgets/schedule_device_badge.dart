import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../../domain/schedule_device.dart';

/// 기기 역할색 — 홈 제어 타일과 같은 팔레트 필드. unknown(null)은 없다.
Color? scheduleDeviceColor(BuildContext context, ScheduleDevice? device) {
  final glass = context.glass;
  return switch (device) {
    ScheduleDevice.fan => glass.deviceFan,
    // 분무는 40 아이콘 export·Figma 편집기(1107:9236)와 같은 #2E408C —
    // `deviceMist`(라이트 #2A97DB)가 아니라 [GlassPalette.humidAccent].
    ScheduleDevice.mist => glass.humidAccent,
    ScheduleDevice.cool => glass.deviceCool,
    ScheduleDevice.led => glass.deviceLed,
    ScheduleDevice.heater => glass.deviceHeat,
    null => null,
  };
}

/// 예약 목록·기기 선택의 40 원 아이콘(Figma 1106:5317 / 4955). 홈 타일의
/// 40 export(원 포함)를 그대로 쓴다 — 예약은 기기 상태와 무관하게 늘 켜짐색.
class ScheduleDeviceBadge extends StatelessWidget {
  const ScheduleDeviceBadge(this.device, {super.key});
  final ScheduleDevice? device;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final asset = switch (device) {
      ScheduleDevice.fan => FigmaIcons.fanOn,
      ScheduleDevice.mist => FigmaIcons.mistOn,
      ScheduleDevice.cool => FigmaIcons.coolOn,
      ScheduleDevice.led => FigmaIcons.ledOn,
      _ => null,
    };
    if (asset != null) return FigmaIcon.metric(asset, size: 40);
    return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: device == ScheduleDevice.heater
                ? glass.deviceHeat
                : glass.deviceOff,
            shape: BoxShape.circle),
        // 히터는 조건부 타일이라 Figma 원본이 없다 — 홈 타일과 같은 Material 유지.
        child: device == ScheduleDevice.heater
            ? Icon(Icons.local_fire_department,
                size: 20, color: glass.deviceGlyph)
            : null);
  }
}

/// 기기 선택 전체 화면(Figma 1106:4955) — 4타일 180.5×72, 고르면 편집기를
/// 열고 편집기 결과를 그대로 돌려준다(부모는 한 번의 push로 초안을 받는다).
class ScheduleDevicePickerScreen extends StatelessWidget {
  const ScheduleDevicePickerScreen({super.key, required this.onPick});

  /// 고른 기기로 편집기를 열고 결과를 돌려준다. null이면 취소.
  final Future<Object?> Function(BuildContext context, ScheduleDevice device)
      onPick;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget tile(ScheduleDevice d) => Material(
        key: Key('routine_device_${d.name}'),
        color: glass.surfaceHeader,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final result = await onPick(context, d);
              if (result != null && context.mounted) {
                Navigator.pop(context, result);
              }
            },
            child: SizedBox(
                height: 72,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      ScheduleDeviceBadge(d),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(d.nameKey.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: managementStyle(context,
                                  weight: FontWeight.w600))),
                    ])))));
    final tiles = ScheduleDevice.pickable;
    return Scaffold(
        backgroundColor: glass.surfaceTint,
        body: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ManagementTopBar(
                      title: '', onBack: () => Navigator.pop(context))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('routine_pick_device_title'.tr(),
                            textAlign: TextAlign.center,
                            style: managementStyle(context,
                                size: 18, weight: FontWeight.w600)),
                        const SizedBox(height: 20),
                        for (var r = 0; r < tiles.length; r += 2) ...[
                          if (r > 0) const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: tile(tiles[r])),
                            const SizedBox(width: 8),
                            Expanded(
                                child: r + 1 < tiles.length
                                    ? tile(tiles[r + 1])
                                    : const SizedBox()),
                          ]),
                        ],
                      ])),
            ])));
  }
}
