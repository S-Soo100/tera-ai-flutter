import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/env_thresholds.dart';
import '../../../shared/domain/num_format.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_cage/domain/device.dart';
import '../../my_cage/presentation/device_settings_providers.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import 'env_alert_prefs_providers.dart';
import 'env_range_setting_screen.dart';
import 'routine_settings_screen.dart' show ScheduleSwitch;
import 'temp_offset_providers.dart';
import 'widgets/device_offline_notice.dart';
import 'widgets/env_setting_widgets.dart';

/// 온습도 설정(Figma 1623:8671 S05 · 1623:8553 S04 · 1623:8751 S06).
///
/// 대상 기기는 **라우트의 [deviceId]로 고정**한다. 기기별 값(적정 범위·보정)과
/// 계정 단위 값(이탈 알림 토글, D2)이 한 화면에 있어서, 어느 사육장인지 첫 섹션
/// 위에 사육장 이름을 보여 준다(Figma 밖 추가 — 2026-11-02 결정).
///
/// **온도 보정**(S04·S32·S35·S06, 메모 S45~S47): 사용자 보정값이 0이면 꺼짐,
/// null(구 펌웨어)이면 비활성 + 안내, 그 외는 켜짐 + "측정값 +1℃". 사용자값은
/// [deviceOffsetProvider](조회 실패 시 목록의 [userOffsetOf])가 계약에 맞춰
/// 해석해 준다 — 이 화면은 공장 보정을 모른다.
/// - 켜기는 화면 상태만 바꾼다 — "보정 값 · 설정하기" 행이 나타나고, 보정값
///   설정에서 저장해야 기기로 간다(S45). 첫 진입 취소면 다시 꺼진다(S46).
/// - 끄기(저장된 보정이 있을 때)는 바로 공장 보정으로 되돌리는 명령을 보내고 기기
///   확인까지 꺼진 모양으로 잠근다. 실패하면 켜짐으로 돌아오고 안내한다.
class TempHumidSettingScreen extends ConsumerWidget {
  const TempHumidSettingScreen({super.key, required this.deviceId});

  final String deviceId;

  static const deviceNameKey = Key('temp_humid_device_name');
  static const missingKey = Key('temp_humid_device_missing');
  static const offsetToggleKey = Key('temp_humid_offset_toggle');
  static const offsetValueKey = Key('temp_humid_offset_value');
  static const offsetRowKey = Key('temp_humid_offset_row');
  static const offsetUnsupportedKey = Key('temp_humid_offset_unsupported');
  static const tempAlertToggleKey = Key('temp_humid_temp_alert_toggle');
  static const humidAlertToggleKey = Key('temp_humid_humid_alert_toggle');
  static const tempRangeRowKey = Key('temp_humid_temp_range_row');
  static const humidRangeRowKey = Key('temp_humid_humid_range_row');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final device =
        devices.valueOrNull?.where((d) => d.id == deviceId).firstOrNull;
    final missing = devices.hasValue && device == null;

    return EnvSettingScaffold(
      title: 'temp_humid_title'.tr(),
      child: missing
          ? Padding(
              key: missingKey,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('temp_humid_device_missing'.tr(),
                  textAlign: TextAlign.center,
                  style: envSettingText(context,
                      size: 16,
                      weight: FontWeight.w500,
                      lineHeight: 19.1,
                      color: context.glass.textTertiary)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 좌우 12는 안내 자체 여백 — 본문 24 선에 맞는다.
                if (device != null) DeviceOfflineNotice(deviceId: deviceId),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._name(context, ref, devices, device),
                      ..._offsetSection(context, ref, devices, device),
                      const SizedBox(height: 24),
                      ..._rangeSection(context, ref, EnvRangeKind.temp),
                      const SizedBox(height: 24),
                      ..._rangeSection(context, ref, EnvRangeKind.humid),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 사육장 이름 — 섹션 제목과 같은 글꼴, 아래 16.
  List<Widget> _name(BuildContext context, WidgetRef ref,
      AsyncValue<List<Device>> devices, Device? device) {
    if (device != null) {
      final name = device.name?.trim();
      if (name == null || name.isEmpty) return const [];
      return [
        EnvSettingSectionTitle(name, key: deviceNameKey, bottom: 16),
      ];
    }
    if (devices.hasError) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: InlineRetry(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              onRetry: () => ref.invalidate(deviceListProvider)),
        ),
      ];
    }
    return const [
      Padding(
        padding: EdgeInsets.only(left: 12, bottom: 16),
        child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonLoading(width: 120, height: 19)),
      ),
    ];
  }

  /// 온도 보정 — 토글 + (켜짐이면) 보정 값 행.
  List<Widget> _offsetSection(BuildContext context, WidgetRef ref,
      AsyncValue<List<Device>> devices, Device? device) {
    final glass = context.glass;
    final live = ref.watch(deviceOffsetProvider(deviceId));
    final loaded = device != null && (live.hasValue || live.hasError);
    // 실시간 조회가 실패하면 목록 값으로 그린다(같은 계약으로 해석).
    final userContract = ref.watch(tempOffsetUserContractProvider);
    final saved = live.hasValue
        ? live.value
        : (device == null
            ? null
            : userOffsetOf(device, userContract: userContract));
    final unsupported = loaded && saved == null;
    final pending = ref.watch(tempOffsetSaveProvider(deviceId));
    final draft = ref.watch(tempOffsetToggleDraftProvider(deviceId));
    final on = pending != null
        ? !pending.isOff
        : saved != null && (!saved.isOff || draft);

    final Widget? toggle;
    if (loaded) {
      final locked = unsupported || pending != null;
      toggle = Opacity(
        opacity: unsupported ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: locked,
          child: ScheduleSwitch(
              key: offsetToggleKey,
              value: on,
              color: glass.navSelected,
              onChanged: (v) => _setOffsetEnabled(context, ref, v, saved)),
        ),
      );
    } else if (devices.isLoading || device != null) {
      toggle = const SkeletonLoading(width: 80, height: 32, borderRadius: 16);
    } else {
      toggle = null;
    }

    return [
      EnvSettingSectionTitle('temp_humid_offset_section'.tr()),
      EnvSettingCard(children: [
        EnvSettingRow(
            title: 'temp_humid_offset_toggle'.tr(),
            rightPadding: 8,
            trailing: toggle),
        if (on && saved != null)
          EnvSettingRow(
            key: offsetRowKey,
            title: 'temp_humid_offset_row'.tr(),
            trailing: EnvSettingLinkTrailing(
              value: Text(
                  saved.isOff
                      ? 'temp_humid_offset_unset'.tr()
                      : 'temp_humid_offset_value'.tr(args: [saved.signedLabel]),
                  key: offsetValueKey),
            ),
            onTap: pending != null
                ? null
                : () => context.push(tempHumidOffsetPath(deviceId)),
          ),
      ]),
      if (unsupported)
        EnvSettingFootnote('temp_humid_offset_unsupported'.tr(),
            key: offsetUnsupportedKey),
      EnvSettingFootnote('temp_humid_offset_note'.tr()),
    ];
  }

  /// 켜기 = 화면 상태만(S45). 끄기 = 저장된 보정이 있으면 공장 보정으로 되돌리는
  /// 명령 — 기기가 확인할 때까지 기다리고, 실패하면 안내한다(토글은 기기 값으로
  /// 그리므로 저절로 켜짐으로 돌아온다).
  Future<void> _setOffsetEnabled(
      BuildContext context, WidgetRef ref, bool on, TempOffset? saved) async {
    final draft = ref.read(tempOffsetToggleDraftProvider(deviceId).notifier);
    if (on || saved == null || saved.isOff) {
      draft.state = on;
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    void tell(String key) =>
        messenger.showSnackBar(SnackBar(content: Text(key.tr())));
    if (!ref.read(moduleOnlineProvider(deviceId))) {
      tell('temp_humid_offset_offline');
      return;
    }
    draft.state = false;
    final result = await ref
        .read(tempOffsetSaveProvider(deviceId).notifier)
        .save(const TempOffset(0));
    if (!context.mounted) return;
    switch (result) {
      case TempOffsetSaveResult.saved || TempOffsetSaveResult.unchanged:
        return;
      case TempOffsetSaveResult.noResponse:
        tell('temp_offset_no_response');
      case TempOffsetSaveResult.rejected:
        tell('temp_offset_rejected');
      case TempOffsetSaveResult.failed:
        tell('temp_offset_failed');
    }
  }

  /// 온도 / 습도 — 이탈 알림 토글 + 적정 범위 행 + 각주.
  List<Widget> _rangeSection(
      BuildContext context, WidgetRef ref, EnvRangeKind kind) {
    final settings = ref.watch(deviceSettingsProvider(deviceId));
    final range =
        settings.hasValue ? kind.rangeOf(settings.requireValue) : null;
    final temp = kind == EnvRangeKind.temp;

    final Widget value;
    if (range != null) {
      value = Text(kind.format(range));
    } else if (settings.hasError) {
      value = const Text('--');
    } else {
      value = const SkeletonLoading(width: 88, height: 19);
    }

    return [
      EnvSettingSectionTitle(
          (temp ? 'temp_humid_temp_section' : 'temp_humid_humid_section').tr()),
      EnvSettingCard(children: [
        EnvSettingRow(
          title: 'temp_humid_alert_toggle'.tr(),
          rightPadding: 8,
          trailing: _alertSwitch(context, ref, temp: temp),
        ),
        EnvSettingRow(
          key: temp ? tempRangeRowKey : humidRangeRowKey,
          title: kind.label,
          trailing: EnvSettingLinkTrailing(value: value),
          onTap: () => context.push(tempHumidRangePath(deviceId, kind)),
        ),
      ]),
      if (range != null)
        EnvSettingFootnote((temp
                ? 'temp_humid_temp_note'
                : 'temp_humid_humid_note')
            .tr(args: [formatCompact(range.min), formatCompact(range.max)])),
    ];
  }

  Widget _alertSwitch(BuildContext context, WidgetRef ref,
      {required bool temp}) {
    final prefs = ref.watch(envAlertPrefsProvider);
    final value = prefs.valueOrNull;
    if (value != null) {
      return ScheduleSwitch(
        key: temp ? tempAlertToggleKey : humidAlertToggleKey,
        value: temp ? value.temp : value.humid,
        color: context.glass.navSelected,
        onChanged: (on) => _setAlert(context, ref, temp: temp, on: on),
      );
    }
    if (prefs.hasError) {
      return InlineRetry(
          padding: const EdgeInsets.symmetric(vertical: 8),
          onRetry: () => ref.invalidate(envAlertPrefsProvider));
    }
    return const SkeletonLoading(width: 80, height: 32, borderRadius: 16);
  }

  /// 바로 서버에 저장한다. 실패하면 provider가 그 토글만 원래대로 돌리고, 여기선
  /// 안내만 띄운다(시트가 아닌 화면이라 일반 스낵바).
  Future<void> _setAlert(BuildContext context, WidgetRef ref,
      {required bool temp, required bool on}) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(envAlertPrefsProvider.notifier);
    try {
      await (temp ? notifier.setTemp(on) : notifier.setHumid(on));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('temp_humid_alert_save_failed'.tr())));
    }
  }
}
