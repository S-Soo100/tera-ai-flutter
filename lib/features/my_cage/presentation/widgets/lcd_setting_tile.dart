import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/figma_icon.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../data/lcd_repository.dart';
import '../management_colors.dart';
import 'device_setting_sheet.dart';
import 'management_widgets.dart';

const _maxLcdTextLength = 20;

// 화면 인스턴스마다 전송 잠금을 격리하고 닫힐 때 해제한다.
final _lcdSendingProvider =
    StateProvider.autoDispose.family<bool, Object>((ref, sheet) => false);

/// 마지막으로 **성공 전송한** 문구(기기별, 세션 메모리). 서버/펌웨어에 현재
/// LCD 문구를 읽는 계약이 없어 기기 이름 등으로 채우지 않는다 — 같은 세션에서
/// 다시 열면 이 값을 미리 채우고 '수정 없음'이면 완료를 비활성화한다.
final lastLcdTextProvider =
    StateProvider.family<String?, String>((ref, deviceId) => null);

/// LCD 문구 입력 화면 열기 (2026-08-14 핸드오프 §3 → 2026-09-16 P08 전체 화면).
///
/// 진입점은 홈 '기기 예약 설정' 섹션의 LCD 로우다(2026-09-07 사용자 지시로
/// 사육장 설정에서 이동). 대상은 **현재 세트의 제어 기기**(예약·목표
/// 온습도와 같은 기준). `lcd_bitmap/lcd_clear`가 차트 마커에서 제외되는
/// 규칙은 그대로다(액추에이터 동작이 아님).
Future<void> showLcdSheet(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) {
  // 탭 셸 밖(루트)으로 띄운다 — 원본 1081:3160은 전체 화면이고 독이 없다
  // (시뮬 확인 2026-09-16: 탭 내비게이터로 띄우면 독이 남는다).
  return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
          builder: (_) => _LcdScreen(
              deviceId: deviceId, repo: ref.read(lcdRepositoryProvider))));
}

/// Figma 1081:3160 — 헤더 44(뒤로 + 제목 16/700), 모듈 그림 345×171 y118,
/// 안내 16/500 #626262 y305, 입력 369×65 y359(글자 x29, 카운터 N/20 우 17),
/// 완료 CTA y696(키보드 위 36). 기본값 복원은 기존 기능이라 y752 텍스트
/// 버튼으로 두되 키보드가 있으면 숨긴다(노출 위치는 결정 목록).
class _LcdScreen extends ConsumerStatefulWidget {
  const _LcdScreen({required this.deviceId, required this.repo});

  final String deviceId;
  final LcdRepository repo;

  @override
  ConsumerState<_LcdScreen> createState() => _LcdScreenState();
}

class _LcdScreenState extends ConsumerState<_LcdScreen> {
  late final TextEditingController _text = TextEditingController(
      text: ref.read(lastLcdTextProvider(widget.deviceId)) ?? '');
  final _identity = Object();

  @override
  void initState() {
    super.initState();
    // 프로그램 입력(controller.text=)도 완료 버튼 활성 판정에 반영한다.
    _text.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final sending = ref.watch(_lcdSendingProvider(_identity));
    final last = ref.watch(lastLcdTextProvider(widget.deviceId));
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
        backgroundColor: glass.surfaceHeader,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ManagementTopBar(
                  title: 'lcd_screen_title'.tr(),
                  onBack: sending ? () {} : () => Navigator.of(context).pop())),
          Expanded(
              child: Stack(children: [
            SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                    12, 12, 12, (keyboard ? 36 : 66) + 56 + 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 모듈 그림 345×171 @x24 (Figma 1081:3474, x3 PNG).
                      const Center(
                          child: Image(
                              key: Key('lcd_illustration_slot'),
                              image: FigmaImages.lcdModule,
                              width: 345,
                              height: 171,
                              fit: BoxFit.contain)),
                      const SizedBox(height: 16),
                      Text('lcd_screen_description'.tr(),
                          textAlign: TextAlign.center,
                          style: managementStyle(context,
                                  color: glass.bodySecondary)
                              .copyWith(height: 19.09375 / 16)),
                      const SizedBox(height: 16),
                      Container(
                          key: const Key('lcd_field'),
                          constraints: const BoxConstraints(minHeight: 65),
                          decoration: BoxDecoration(
                              color: ManagementColors.nameField(context),
                              border: Border.all(color: glass.border),
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.only(left: 16, right: 16),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                                    key: const Key('lcd_text_field'),
                                    controller: _text,
                                    // 기기 이름과 독립적인 문구이며 공백도
                                    // 입력 한도에 포함한다.
                                    maxLength: _maxLcdTextLength,
                                    readOnly: sending,
                                    style: managementStyle(context,
                                        color: glass.textPrimary),
                                    decoration: InputDecoration(
                                        hintText: 'lcd_hint'.tr(),
                                        counterText: '',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false))),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _text,
                                builder: (context, value, _) => Text(
                                    '${value.text.characters.length}/$_maxLcdTextLength',
                                    key: const Key('lcd_counter'),
                                    style: managementStyle(context,
                                        color: glass.textTertiary))),
                          ])),
                    ])),
            Positioned(
                left: 12,
                right: 12,
                // 원본 1081:3160 — 완료 단독 y696(세이프 66 위), 키보드 위 36.
                // 기본값 복원 버튼은 원본에 없어 제거(2026-09-16 사용자 결정).
                bottom: keyboard ? 36 : 66,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                          key: const Key('lcd_apply'),
                          onPressed: sending ||
                                  _text.text.trim().isEmpty ||
                                  _text.text == last
                              ? null
                              : _send,
                          style: FilledButton.styleFrom(
                              backgroundColor: glass.textPrimary,
                              disabledBackgroundColor: glass.border,
                              foregroundColor:
                                  ManagementColors.buttonForeground(context),
                              disabledForegroundColor:
                                  ManagementColors.buttonForeground(context),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: managementStyle(context,
                                      size: 18, weight: FontWeight.w600)
                                  .copyWith(height: 28 / 18)),
                          child: Text('lcd_done'.tr()))),
                ])),
          ])),
        ])));
  }

  Future<void> _send() async {
    if (!mounted) return;
    final sending = ref.read(_lcdSendingProvider(_identity).notifier);
    if (sending.state) return;
    sending.state = true;
    // Controller의 프로그램 입력은 TextField formatter를 거치지 않는다.
    // 전송 직전에도 화면 카운터와 같은 문자 단위로 상한을 적용한다.
    final text = _text.text.characters.take(_maxLcdTextLength).toString();
    final last = ref.read(lastLcdTextProvider(widget.deviceId).notifier);
    final ok = await submitAndClose(
      context,
      () async {
        await widget.repo.setText(widget.deviceId, text);
        last.state = text;
      },
      successKey: 'lcd_sent',
      failureKey: 'lcd_failed',
    );
    if (!ok && mounted) sending.state = false;
  }
}
