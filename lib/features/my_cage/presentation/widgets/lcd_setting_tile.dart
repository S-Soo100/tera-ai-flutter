import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../data/lcd_repository.dart';

/// 사육장 설정의 LCD 문구 진입점 (2026-08-14 핸드오프 §3).
///
/// 대상은 **현재 세트의 제어 기기**다(`currentDeviceIdProvider` — 예약 화면과
/// 같은 기준). 기기가 없으면 탭을 막는 대신 이유를 subtitle로 밝힌다 —
/// 회색 타일만 두면 고장으로 읽힌다.
class LcdSettingTile extends ConsumerWidget {
  const LcdSettingTile({super.key});

  static const tileKey = Key('lcd_setting_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    return ListTile(
      key: tileKey,
      leading: const Icon(Icons.smart_display_outlined),
      title: Text('lcd_tile_title'.tr()),
      subtitle: Text(
          (deviceId == null ? 'lcd_no_device' : 'lcd_tile_subtitle').tr()),
      enabled: deviceId != null,
      onTap: deviceId == null ? null : () => _openSheet(context, ref, deviceId),
    );
  }

  Future<void> _openSheet(
      BuildContext context, WidgetRef ref, String deviceId) async {
    final repo = ref.read(lcdRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LcdSheet(deviceId: deviceId, repo: repo),
    );
  }
}

class _LcdSheet extends StatefulWidget {
  const _LcdSheet({required this.deviceId, required this.repo});

  final String deviceId;
  final LcdRepository repo;

  @override
  State<_LcdSheet> createState() => _LcdSheetState();
}

class _LcdSheetState extends State<_LcdSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
            Text('lcd_sheet_title'.tr(),
                style: AppStyles.subsectionTitle(context)),
            const SizedBox(height: AppStyles.spacing12),
            TextField(
              key: const Key('lcd_text_field'),
              controller: _text,
              // 하드 상한만 막는다 — 권장 한도(한글 8/영문 12)는 힌트로 두고,
              // 넘치면 서버가 자동 축소한다(§3).
              maxLength: 64,
              decoration: InputDecoration(
                hintText: 'lcd_hint'.tr(),
                helperText: 'lcd_length_hint'.tr(),
                helperMaxLines: 2,
                isDense: true,
              ),
            ),
            const SizedBox(height: AppStyles.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('lcd_reset'),
                    onPressed: _sending ? null : () => _send(clear: true),
                    child: Text('lcd_reset'.tr()),
                  ),
                ),
                const SizedBox(width: AppStyles.spacing8),
                Expanded(
                  child: FilledButton(
                    key: const Key('lcd_apply'),
                    onPressed: _sending ? null : () => _send(clear: false),
                    child: Text('lcd_apply'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send({required bool clear}) async {
    setState(() => _sending = true);
    try {
      if (clear) {
        await widget.repo.clear(widget.deviceId);
      } else {
        await widget.repo.setText(widget.deviceId, _text.text.trim());
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('lcd_sent'.tr())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('lcd_failed'.tr(args: ['$e']))));
    }
  }
}
