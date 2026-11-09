import 'dart:async';

import '../../../shared/domain/keep_all_words.dart';
import '../../../shared/widgets/word_joiner_span.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../domain/lcd_screen_state.dart';
import 'lcd_screen_providers.dart';
import 'management_colors.dart';
import 'supabase_module_providers.dart';
import 'widgets/management_widgets.dart';

/// 화면 꺼짐 시간(Figma 1659:6267).
///
/// 393 기준: 바닥 #F4F4F4(헤더도 같은 면), 헤더 y62 h44 "화면 꺼짐 시간". 본문
/// x24 w345. 블록 제목 "시작" y118 / "종료" y282(x36 16/600 #949090) → 위 화살표
/// y140(24) → 칸 y164(70) → 아래 화살표 y234(24). 오전/오후 세로 토글 x24
/// 86×70 r8(각 35, 선택 #C00306 면·#FAFAFA 16/700, 비선택 흰 면·#3C3C3C 16/600),
/// 시 칸 x130 108×70 r8 #E3E3E3(24/600 #1E1E1E), `:` x246 24/600 #3C3C3C,
/// 분 칸 x261. 완료 CTA x12 w369 h56 r12 — 안전영역 위 66(y696).
///
/// 완료: 예약이 켜져 있으면 바로 기기로 보내고 돌아간다(확인 대기는 설정 화면
/// 줄의 반짝임). 꺼져 있으면 폰에만 기억하고 돌아간다(오프라인이어도 된다).
class LcdQuietTimeScreen extends ConsumerWidget {
  const LcdQuietTimeScreen({super.key, required this.deviceId});

  final String deviceId;

  static const doneKey = Key('lcd_quiet_done');
  static const offlineNoteKey = Key('lcd_quiet_offline_note');

  /// 블록별 위젯 키 — `lcd_quiet_{start|end}_{am|pm|hour|minute}[_up|_down]`.
  static Key partKey(bool isStart, String part) =>
      Key('lcd_quiet_${isStart ? 'start' : 'end'}_$part');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final draft = ref.watch(lcdQuietDraftProvider(deviceId));
    final view = ref.watch(lcdScreenViewProvider(deviceId)).valueOrNull;
    final quiet =
        ref.watch(lcdCommandProvider((deviceId, LcdCommandKind.quiet)));
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final loaded = view != null && view.support == LcdSupport.supported;
    final scheduleOn = view?.screen.quiet != null;
    final blockedOffline = scheduleOn && !online;
    final canSubmit =
        loaded && draft.canSubmit && !quiet.pending && !blockedOffline;
    final inset = MediaQuery.paddingOf(context).bottom;
    final ctaBottom = inset + 66;

    return Scaffold(
      backgroundColor: glass.surfaceTint,
      body: Stack(children: [
        Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ManagementTopBar(
                  title: 'lcd_quiet_title'.tr(),
                  onBack: () => Navigator.of(context).maybePop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 12, 24, ctaBottom + 56 + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Block(deviceId: deviceId, isStart: true, time: draft.start),
                  const SizedBox(height: 24),
                  _Block(deviceId: deviceId, isStart: false, time: draft.end),
                  if (blockedOffline)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 12),
                      child: Text.rich(
                          wordJoinerSpan(keepAllWords('lcd_offline_note'.tr())),
                          key: offlineNoteKey,
                          style: managementStyle(context,
                              size: 14,
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
          ),
        ]),
        Positioned(
          left: 12,
          right: 12,
          bottom: ctaBottom,
          child: SizedBox(
            height: 56,
            child: FilledButton(
              key: doneKey,
              onPressed: canSubmit
                  ? () => _submit(context, ref, draft.window, scheduleOn)
                  : null,
              style: FilledButton.styleFrom(
                  backgroundColor: glass.textPrimary,
                  disabledBackgroundColor: glass.border,
                  foregroundColor: ManagementColors.buttonForeground(context),
                  disabledForegroundColor:
                      ManagementColors.buttonForeground(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: managementStyle(context,
                          size: 18, weight: FontWeight.w600)
                      .copyWith(height: 28 / 18)),
              child: Text('lcd_done'.tr()),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref,
      LcdQuietWindow window, bool scheduleOn) async {
    final navigator = Navigator.of(context);
    if (scheduleOn) {
      // 결과는 설정 화면이 듣는다(줄 반짝임·실패 안내) — 기다리지 않는다.
      unawaited(ref
          .read(lcdCommandProvider((deviceId, LcdCommandKind.quiet)).notifier)
          .run(LcdQuietTarget.set(window)));
    } else {
      await ref
          .read(lcdQuietMemoryProvider(deviceId).notifier)
          .remember(window);
    }
    if (navigator.mounted) unawaited(navigator.maybePop());
  }
}

/// 시작/종료 블록 — 제목 + (오전/오후 · 시 · : · 분).
class _Block extends ConsumerWidget {
  const _Block(
      {required this.deviceId, required this.isStart, required this.time});

  final String deviceId;
  final bool isStart;
  final LcdAmPmTime time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final draft = ref.read(lcdQuietDraftProvider(deviceId).notifier);
    final label = (isStart ? 'lcd_quiet_start' : 'lcd_quiet_end').tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(label,
              style: managementStyle(context,
                  weight: FontWeight.w600, color: glass.textTertiary)),
        ),
        // 제목 y118(행간 19.09) → 화살표 y140.
        const SizedBox(height: 3),
        Row(children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _AmPmHalf(
                    key: LcdQuietTimeScreen.partKey(isStart, 'am'),
                    text: 'routine_am'.tr(),
                    selected: !time.pm,
                    onTap: () => draft.setPm(isStart, false)),
                _AmPmHalf(
                    key: LcdQuietTimeScreen.partKey(isStart, 'pm'),
                    text: 'routine_pm'.tr(),
                    selected: time.pm,
                    onTap: () => draft.setPm(isStart, true)),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
          const SizedBox(width: 20),
          _Picker(
            isStart: isStart,
            part: 'hour',
            text: '${time.hour12}',
            upLabel: 'lcd_quiet_hour_up'.tr(args: [label]),
            downLabel: 'lcd_quiet_hour_down'.tr(args: [label]),
            onStep: (d) => draft.stepHour(isStart, d),
          ),
          SizedBox(
            width: 23,
            child: Center(
              child: Text(':',
                  style: managementStyle(context,
                      size: 24,
                      weight: FontWeight.w600,
                      color: glass.textSecondary)),
            ),
          ),
          _Picker(
            isStart: isStart,
            part: 'minute',
            text: time.minute.toString().padLeft(2, '0'),
            upLabel: 'lcd_quiet_minute_up'.tr(args: [label]),
            downLabel: 'lcd_quiet_minute_down'.tr(args: [label]),
            onStep: (d) => draft.stepMinute(isStart, d),
          ),
        ]),
      ],
    );
  }
}

/// 오전/오후 반쪽 86×35.
class _AmPmHalf extends StatelessWidget {
  const _AmPmHalf(
      {super.key,
      required this.text,
      required this.selected,
      required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? glass.navSelected : glass.surfaceHeader,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 86,
            height: 35,
            child: Center(
              // 휴대폰 글자를 키워도 칸을 넘지 않게 줄이기만 한다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text,
                    style: managementStyle(context,
                        weight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? ManagementColors.buttonForeground(context)
                            : glass.textSecondary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 위 화살표 24 + 값 칸 108×70 + 아래 화살표 24. 화살표 터치 영역은 칸의
/// 위·아래 20까지 넓혀 44를 확보한다(그림은 Figma 그대로).
class _Picker extends StatelessWidget {
  const _Picker({
    required this.isStart,
    required this.part,
    required this.text,
    required this.upLabel,
    required this.downLabel,
    required this.onStep,
  });

  final bool isStart;
  final String part;
  final String text;
  final String upLabel;
  final String downLabel;
  final ValueChanged<int> onStep;

  static const _hit = 44.0;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget arrow(String icon) => SizedBox(
          height: 24,
          child: Center(
            child: FigmaIcon.tinted(icon,
                size: 12, height: 7, color: glass.textSecondary),
          ),
        );
    Widget hit(String suffix, String label, int direction) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            key: LcdQuietTimeScreen.partKey(isStart, '${part}_$suffix'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onStep(direction),
            child: const SizedBox(width: 108, height: _hit),
          ),
        );
    return SizedBox(
      width: 108,
      height: 118,
      child: Stack(children: [
        Column(children: [
          arrow(FigmaIcons.keyboardArrowUp),
          Container(
            width: 108,
            height: 70,
            decoration: BoxDecoration(
                color: glass.border, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text,
                  key: LcdQuietTimeScreen.partKey(isStart, part),
                  style: managementStyle(context,
                          size: 24,
                          weight: FontWeight.w600,
                          color: glass.textPrimary)
                      .copyWith(height: 28.64 / 24)),
            ),
          ),
          arrow(FigmaIcons.keyboardArrowDown),
        ]),
        Positioned(top: 0, left: 0, right: 0, child: hit('up', upLabel, 1)),
        Positioned(
            bottom: 0, left: 0, right: 0, child: hit('down', downLabel, -1)),
      ]),
    );
  }
}
