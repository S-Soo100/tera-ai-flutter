import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../data/lcd_repository.dart';
import 'device_setting_sheet.dart';

const _maxLcdTextLength = 20;

// 시트 인스턴스마다 전송 잠금을 격리하고 닫힐 때 해제한다.
final _lcdSendingProvider =
    StateProvider.autoDispose.family<bool, Object>((ref, sheet) => false);

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

class _LcdSheet extends ConsumerStatefulWidget {
  const _LcdSheet({required this.deviceId, required this.repo});

  final String deviceId;
  final LcdRepository repo;

  @override
  ConsumerState<_LcdSheet> createState() => _LcdSheetState();
}

class _LcdSheetState extends ConsumerState<_LcdSheet> {
  final _text = TextEditingController();
  final _sheetIdentity = Object();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(_lcdSendingProvider(_sheetIdentity));
    return DeviceSettingSheet(
      title: 'lcd_sheet_title'.tr(),
      children: [
        TextField(
          key: const Key('lcd_text_field'),
          controller: _text,
          // 기기 이름과 독립적인 문구이며 공백도 입력 한도에 포함한다.
          maxLength: _maxLcdTextLength,
          readOnly: sending,
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
                onPressed: sending ? null : () => _send(clear: true),
                child: Text('lcd_reset'.tr()),
              ),
            ),
            const SizedBox(width: AppStyles.spacing8),
            Expanded(
              child: FilledButton(
                key: const Key('lcd_apply'),
                onPressed: sending ? null : () => _send(clear: false),
                child: Text('lcd_apply'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _send({required bool clear}) async {
    if (!mounted) return;
    final sending = ref.read(_lcdSendingProvider(_sheetIdentity).notifier);
    if (sending.state) return;
    sending.state = true;
    // Controller의 프로그램 입력은 TextField formatter를 거치지 않는다.
    // 전송 직전에도 화면 카운터와 같은 문자 단위로 상한을 적용한다.
    final text = _text.text.characters.take(_maxLcdTextLength).toString();
    final ok = await submitAndClose(
      context,
      () => clear
          ? widget.repo.clear(widget.deviceId)
          : widget.repo.setText(widget.deviceId, text),
      successKey: 'lcd_sent',
      failureKey: 'lcd_failed',
    );
    if (!ok && mounted) sending.state = false;
  }
}
