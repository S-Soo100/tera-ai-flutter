import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../data/lcd_repository.dart';
import 'device_setting_sheet.dart';

/// LCD 문구 입력 시트 열기 (2026-08-14 핸드오프 §3).
///
/// 진입점은 홈 '일정 설정' 섹션의 LCD 로우다(2026-09-07 사용자 지시로
/// 사육장 설정에서 이동). 대상은 **현재 세트의 제어 기기**(예약·목표
/// 온습도와 같은 기준). `lcd_bitmap/lcd_clear`가 차트 마커에서 제외되는
/// 규칙은 그대로다(액추에이터 동작이 아님).
Future<void> showLcdSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) =>
        _LcdSheet(deviceId: deviceId, repo: ref.read(lcdRepositoryProvider)),
  );
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
    return DeviceSettingSheet(
      title: 'lcd_sheet_title'.tr(),
      children: [
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
    );
  }

  Future<void> _send({required bool clear}) async {
    setState(() => _sending = true);
    final ok = await submitAndClose(
      context,
      () => clear
          ? widget.repo.clear(widget.deviceId)
          : widget.repo.setText(widget.deviceId, _text.text.trim()),
      successKey: 'lcd_sent',
      failureKey: 'lcd_failed',
    );
    if (!ok && mounted) setState(() => _sending = false);
  }
}
