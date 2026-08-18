import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../domain/device_settings.dart';
import '../device_settings_providers.dart';

/// 사육장 설정의 목표 온습도(setpoint) 진입점 (2026-08-18 회신 §5).
///
/// 대상은 **현재 세트의 제어 기기**(`currentDeviceIdProvider` — LCD·예약과
/// 같은 기준). 기기가 없으면 탭을 막는 대신 이유를 subtitle로 밝힌다.
/// 값이 있으면 subtitle에 현재 목표를 바로 보여줘 시트를 안 열어도 확인된다.
class SetpointSettingTile extends ConsumerWidget {
  const SetpointSettingTile({super.key});

  static const tileKey = Key('setpoint_setting_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    final settings = deviceId == null
        ? null
        : ref.watch(deviceSettingsProvider(deviceId)).valueOrNull;
    return ListTile(
      key: tileKey,
      leading: const Icon(Icons.thermostat_outlined),
      title: Text('setpoint_tile_title'.tr()),
      subtitle: Text(_subtitle(deviceId, settings)),
      enabled: deviceId != null,
      onTap: deviceId == null
          ? null
          : () => _openSheet(context, ref, deviceId, settings),
    );
  }

  static String _subtitle(String? deviceId, DeviceSettings? s) {
    if (deviceId == null) return 'lcd_no_device'.tr();
    if (s == null || !s.hasTarget) return 'setpoint_tile_subtitle'.tr();
    return 'setpoint_tile_value'.tr(args: [
      s.targetTempC == null ? 'setpoint_unset'.tr() : _fmt(s.targetTempC!),
      s.targetHumidityPct == null
          ? 'setpoint_unset'.tr()
          : _fmt(s.targetHumidityPct!),
    ]);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

  Future<void> _openSheet(BuildContext context, WidgetRef ref, String deviceId,
      DeviceSettings? current) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SetpointSheet(
        initial: current,
        onSave: (t, h) => ref
            .read(deviceSettingsProvider(deviceId).notifier)
            .save(targetTempC: t, targetHumidityPct: h),
      ),
    );
  }
}

class _SetpointSheet extends StatefulWidget {
  const _SetpointSheet({required this.initial, required this.onSave});

  final DeviceSettings? initial;
  final Future<void> Function(double? temp, double? humidity) onSave;

  @override
  State<_SetpointSheet> createState() => _SetpointSheetState();
}

class _SetpointSheetState extends State<_SetpointSheet> {
  late final TextEditingController _temp = TextEditingController(
      text: _init(widget.initial?.targetTempC));
  late final TextEditingController _humid = TextEditingController(
      text: _init(widget.initial?.targetHumidityPct));
  bool _sending = false;

  static String _init(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1));

  @override
  void dispose() {
    _temp.dispose();
    _humid.dispose();
    super.dispose();
  }

  double? get _tempValue => double.tryParse(_temp.text.trim());
  double? get _humidValue => double.tryParse(_humid.text.trim());

  /// 비운 칸은 "안 바꿈"(PATCH에 키 생략). 채운 칸은 서버와 같은 범위 검사.
  bool get _valid {
    final t = _temp.text.trim();
    final h = _humid.text.trim();
    if (t.isEmpty && h.isEmpty) return false;
    if (t.isNotEmpty &&
        (_tempValue == null || !DeviceSettings.validateTemp(_tempValue!))) {
      return false;
    }
    if (h.isNotEmpty &&
        (_humidValue == null ||
            !DeviceSettings.validateHumidity(_humidValue!))) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppStyles.spacing16,
          right: AppStyles.spacing16,
          top: AppStyles.spacing16,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + AppStyles.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('setpoint_sheet_title'.tr(),
                style: AppStyles.subsectionTitle(context)),
            const SizedBox(height: AppStyles.spacing12),
            TextField(
              key: const Key('setpoint_temp_field'),
              controller: _temp,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'setpoint_temp_label'.tr(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppStyles.spacing8),
            TextField(
              key: const Key('setpoint_humidity_field'),
              controller: _humid,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'setpoint_humidity_label'.tr(),
                helperText: 'setpoint_range_hint'.tr(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppStyles.spacing12),
            FilledButton(
              key: const Key('setpoint_apply'),
              onPressed: _valid && !_sending ? _save : null,
              child: Text('setpoint_apply'.tr()),
            ),
            if (!_valid &&
                (_temp.text.isNotEmpty || _humid.text.isNotEmpty)) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                'setpoint_invalid'.tr(),
                key: const Key('setpoint_invalid'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _sending = true);
    try {
      await widget.onSave(
        _temp.text.trim().isEmpty ? null : _tempValue,
        _humid.text.trim().isEmpty ? null : _humidValue,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('setpoint_saved'.tr())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('setpoint_failed'.tr(args: ['$e']))));
    }
  }
}
