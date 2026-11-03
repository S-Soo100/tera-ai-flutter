import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import '../../home/presentation/widgets/control_feedback.dart';
import '../../home/presentation/widgets/control_loading_overlay.dart';
import '../../home/presentation/widgets/env_setting_widgets.dart';
import '../domain/lcd_screen_state.dart';
import 'lcd_screen_providers.dart';
import 'management_colors.dart';
import 'supabase_module_providers.dart';
import 'widgets/lcd_setting_tile.dart';

/// 오전/오후 + `h:mm` — "오전 8:00".
String lcdAmPmLabel(LcdAmPmTime t) =>
    '${(t.pm ? 'routine_pm' : 'routine_am').tr()} ${t.clockLabel}';

/// LCD 명령 결과 안내 — 늦어지면 한 번, 실패하면 이유(§11-2·§12-2). 화면이
/// 루트 전체 화면이라 스낵바가 아니라 [ControlFeedback]이다. 사진 명령은
/// 화면을 나가도 알려야 해서 실행기의 `run(onResult:)`로 안내한다(보호 사진
/// 화면).
void listenLcdCommandFeedback(
    WidgetRef ref, BuildContext context, LcdCommandKey key) {
  ref.listen<LcdCommandState>(lcdCommandProvider(key), (prev, next) {
    final feedback = ControlFeedback.of(context);
    if (next.slow && !(prev?.slow ?? false) && next.pending) {
      // 사진은 30초 판정까지 "기기로 보내는 중"을 칸에 그린다(§11-2) —
      // 따로 늦어요를 띄우지 않는다.
      if (key.$2 != LcdCommandKind.image) {
        feedback.show('lcd_result_slow'.tr());
      }
      return;
    }
    if (prev != null && next.round != prev.round) {
      final message = next.result?.messageKeyFor(key.$2);
      if (message != null) {
        feedback.show(message.tr());
      } else if (prev.slow) {
        // "늦어요"를 띄운 뒤 결국 성공했다 — 그 안내를 걷는다.
        ControlFeedback.hideCurrent();
      }
    }
  });
}

/// 모듈 화면 설정(Figma 1659:5964 예약 꺼짐 / 1660:6770 예약 켜짐).
///
/// 393 기준: 바닥 #F4F4F4, 헤더 0~106 #FAFAFA + 하단선 #E3E3E3(
/// [EnvSettingScaffold]), 본문 x24 w345 첫 묶음 y130. 묶음 r16 · 줄 48 흰 면 ·
/// 줄 사이 2(바닥이 비쳐 선처럼 보인다) · 묶음 사이 24(y130/y202/y324). 줄 글자
/// x36 18/600 행간 21.48 #3C3C3C, 오른쪽 값 16/500 행간 19.09 #949090 + 화살표
/// 18 #3C3C3C(우 12). 스위치 80×32(우 8). 각주 y429 x36 14/500 행간 18 #949090.
///
/// 기기 구분(§12-4): 지원=전부, 구 펌웨어=세 줄 흐리게+업데이트 안내, 허브=문구
/// 줄만. 지원 기기는 `GET /lcd`까지 불러와야 쓰기가 열린다(§11-1).
class LcdSettingsScreen extends ConsumerStatefulWidget {
  const LcdSettingsScreen({super.key, required this.deviceId});

  final String deviceId;

  static const powerRowKey = Key('lcd_settings_power_row');
  static const powerSwitchKey = Key('lcd_settings_power_switch');
  static const powerPendingKey = Key('lcd_settings_power_pending');
  static const powerNoteKey = Key('lcd_settings_power_note');
  static const textRowKey = Key('lcd_settings_text_row');
  static const textValueKey = Key('lcd_settings_text_value');
  static const saverRowKey = Key('lcd_settings_saver_row');
  static const saverValueKey = Key('lcd_settings_saver_value');
  static const saverPendingKey = Key('lcd_settings_saver_pending');
  static const quietRowKey = Key('lcd_settings_quiet_row');
  static const quietSwitchKey = Key('lcd_settings_quiet_switch');
  static const quietPendingKey = Key('lcd_settings_quiet_pending');
  static const timeRowKey = Key('lcd_settings_time_row');
  static const timeValueKey = Key('lcd_settings_time_value');
  static const quietNoteKey = Key('lcd_settings_quiet_note');
  static const updateNoteKey = Key('lcd_settings_update_note');
  static const offlineNoteKey = Key('lcd_settings_offline_note');
  static const retryKey = Key('lcd_settings_retry');
  static const loadingKey = Key('lcd_settings_loading');

  @override
  ConsumerState<LcdSettingsScreen> createState() => _LcdSettingsScreenState();
}

class _LcdSettingsScreenState extends ConsumerState<LcdSettingsScreen> {
  // "지금은 꺼짐 예약 시간" 판정은 그릴 때·앱 복귀 때만(§11-3).
  late final AppLifecycleListener _lifecycle;

  String get _id => widget.deviceId;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      if (mounted) ref.read(lcdResumeTickProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final powerKey = (_id, LcdCommandKind.power);
    final quietKey = (_id, LcdCommandKind.quiet);
    listenLcdCommandFeedback(ref, context, powerKey);
    listenLcdCommandFeedback(ref, context, quietKey);
    // 보호기 완료는 보호 사진 화면이 보내고 바로 돌아온다 — 결과는 여기서
    // 안내한다(§11-4). 사진 명령은 실행기가 직접 안내한다(화면 밖, §11-5).
    listenLcdCommandFeedback(ref, context, (_id, LcdCommandKind.saver));

    final view = ref.watch(lcdScreenViewProvider(_id));
    final support = view.valueOrNull?.support;
    final textOnly = support == LcdSupport.hub || support == LcdSupport.noLcd;

    return EnvSettingScaffold(
      title: 'lcd_settings_title'.tr(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: textOnly
              ? [
                  _LcdGroup(children: [_textRow(context)])
                ]
              : view.hasValue
                  ? _content(context, view.requireValue)
                  : view.hasError && !view.isLoading
                      ? _failed(context)
                      : _loading(context),
        ),
      ),
    );
  }

  /// 화면 표시 문구 줄 — 기존 문구 화면으로(완료하면 이 화면으로 돌아온다).
  Widget _textRow(BuildContext context) {
    final device = ref
        .watch(deviceListProvider)
        .valueOrNull
        ?.where((d) => d.id == _id)
        .firstOrNull;
    final hardwareId = device?.hardwareId;
    final text = ref.watch(lcdDisplayTextProvider(_id)) ?? hardwareId ?? '--';
    return _LcdRow(
      key: LcdSettingsScreen.textRowKey,
      title: 'lcd_settings_text_row'.tr(),
      trailing: _LinkValue(Text(text, key: LcdSettingsScreen.textValueKey)),
      onTap: () => showLcdSheet(context, ref, _id, defaultText: hardwareId),
    );
  }

  List<Widget> _loading(BuildContext context) => [
        _LcdGroup(key: LcdSettingsScreen.loadingKey, children: [
          _LcdRow(
              title: 'lcd_settings_power_plain'.tr(),
              rightPadding: 8,
              trailing: const SkeletonLoading(
                  width: 80, height: 32, borderRadius: 16)),
        ]),
        const SizedBox(height: 24),
        _LcdGroup(children: [
          _textRow(context),
          _LcdRow(
              title: 'lcd_settings_saver_row'.tr(),
              trailing: const SkeletonLoading(width: 40, height: 19)),
        ]),
        const SizedBox(height: 24),
        _LcdGroup(children: [
          _LcdRow(
              title: 'lcd_settings_quiet_toggle'.tr(),
              rightPadding: 8,
              trailing: const SkeletonLoading(
                  width: 80, height: 32, borderRadius: 16)),
          _LcdRow(
              title: 'lcd_settings_quiet_time'.tr(),
              trailing: const SkeletonLoading(width: 88, height: 19)),
        ]),
      ];

  /// 불러오기 실패 — 문구 줄은 따로 동작하니 남기고, 나머지는 재시도.
  List<Widget> _failed(BuildContext context) => [
        _LcdGroup(children: [_textRow(context)]),
        const SizedBox(height: 16),
        Text('lcd_settings_load_failed'.tr(),
            textAlign: TextAlign.center, style: _footnoteStyle(context)),
        InlineRetry(
            key: LcdSettingsScreen.retryKey,
            onRetry: () {
              ref.invalidate(lcdSnapshotProvider(_id));
              ref.invalidate(lcdLinkRefreshProvider(_id));
            }),
      ];

  List<Widget> _content(BuildContext context, LcdScreenView view) {
    final glass = context.glass;
    final supported = view.support == LcdSupport.supported;
    final online = ref.watch(moduleOnlineProvider(_id));
    final power = ref.watch(lcdCommandProvider((_id, LcdCommandKind.power)));
    final quiet = ref.watch(lcdCommandProvider((_id, LcdCommandKind.quiet)));
    // 보호기·사진 대기는 보호 사진 화면이 만든다 — 줄 반짝임만 여기서.
    final saverBusy =
        ref.watch(lcdCommandProvider((_id, LcdCommandKind.saver))).pending ||
            ref.watch(lcdCommandProvider((_id, LcdCommandKind.image))).pending;

    // 대기 중엔 목표 상태를 그린다 — 스위치가 바로 넘어간다(§4).
    final powerTarget = power.target;
    final powerOn =
        powerTarget is LcdPowerTarget ? powerTarget.on : view.switchOn;
    final quietTarget = quiet.target;
    final scheduleOn = quietTarget is LcdQuietTarget
        ? !quietTarget.isClear
        : view.screen.quiet != null;
    final LcdQuietWindow resolved = ref.watch(lcdQuietTimeProvider(_id));
    final window =
        (quietTarget is LcdQuietTarget ? quietTarget.window : null) ?? resolved;

    final canPower = supported && online && !power.pending;
    final canQuiet = supported && online && !quiet.pending;
    // 예약이 꺼져 있으면 시간은 폰에만 기억하니 오프라인이어도 고칠 수 있다
    // (§11-6). 켜져 있으면 고치는 즉시 기기로 보낸다.
    final canEditTime = supported && !quiet.pending && (!scheduleOn || online);

    // Figma 1659:5964 — 사진 없이 꺼져 있으면 '꺼짐'. '사진 없음'은 켜 놨는데
    // 사진이 없을 때만(기기는 온습도만 띄운다, §11-4).
    final saverOn = view.screen.saverOrDefault.enabled;
    final saverLabel = !saverOn
        ? 'lcd_state_off'
        : view.screen.hasImage
            ? 'lcd_state_on'
            : 'lcd_saver_no_photo';

    final notes = <Widget>[
      if (!supported)
        _Footnote('lcd_needs_update_note'.tr(),
            textKey: LcdSettingsScreen.updateNoteKey)
      else ...[
        if (_powerNote(view, power.pending, quiet.pending) case final note?)
          _Footnote(note, textKey: LcdSettingsScreen.powerNoteKey),
        if (!online)
          _Footnote('lcd_offline_note'.tr(),
              textKey: LcdSettingsScreen.offlineNoteKey,
              color: Theme.of(context).colorScheme.error),
      ],
    ];

    // 각주: 구 규칙에서 전원이 꺼져 있으면 "다시 켤 때까지 꺼져 있어요"(§11-3),
    // 신 규칙은 Figma 문구 그대로(§12-1).
    final quietNote = supported && !view.overrideRule && !view.screen.power
        ? 'lcd_power_sticky_note'
        : 'lcd_settings_quiet_note';

    return [
      _LcdGroup(children: [
        _Pending(
          pendingKey: LcdSettingsScreen.powerPendingKey,
          pending: power.pending,
          child: _LcdRow(
            key: LcdSettingsScreen.powerRowKey,
            title: 'lcd_settings_power'.tr(args: [
              (powerOn ? 'lcd_state_on' : 'lcd_state_off').tr(),
            ]),
            dimmed: !supported,
            rightPadding: 8,
            trailing: LcdSwitch(
              key: LcdSettingsScreen.powerSwitchKey,
              value: powerOn,
              enabled: canPower,
              dimmed: supported && !online,
              onChanged: (on) => ref
                  .read(
                      lcdCommandProvider((_id, LcdCommandKind.power)).notifier)
                  .run(LcdPowerTarget(on)),
            ),
          ),
        ),
      ]),
      ...notes,
      const SizedBox(height: 24),
      _LcdGroup(children: [
        _textRow(context),
        // 대기 중에도 들어갈 수 있다 — 화면 안에서 편집을 잠근다(§11-4).
        // 오프라인도 들어가서 화면 안에서 막는다(§11-6, 사진·값을 볼 수 있게).
        _Pending(
          pendingKey: LcdSettingsScreen.saverPendingKey,
          pending: saverBusy,
          absorb: false,
          child: _LcdRow(
            key: LcdSettingsScreen.saverRowKey,
            title: 'lcd_settings_saver_row'.tr(),
            dimmed: !supported,
            trailing: _LinkValue(
                Text(saverLabel.tr(), key: LcdSettingsScreen.saverValueKey)),
            onTap: () => context.push(lcdSaverPath(_id)),
          ),
        ),
      ]),
      const SizedBox(height: 24),
      _Pending(
        pendingKey: LcdSettingsScreen.quietPendingKey,
        pending: quiet.pending,
        radius: 16,
        child: _LcdGroup(children: [
          _LcdRow(
            key: LcdSettingsScreen.quietRowKey,
            title: 'lcd_settings_quiet_toggle'.tr(),
            dimmed: !supported,
            rightPadding: 8,
            trailing: LcdSwitch(
              key: LcdSettingsScreen.quietSwitchKey,
              value: scheduleOn,
              enabled: canQuiet,
              dimmed: supported && !online,
              onChanged: (on) => ref
                  .read(
                      lcdCommandProvider((_id, LcdCommandKind.quiet)).notifier)
                  .run(on
                      ? LcdQuietTarget.set(window)
                      : LcdQuietTarget.clear(previous: view.screen.quiet)),
            ),
          ),
          _LcdRow(
            key: LcdSettingsScreen.timeRowKey,
            title: 'lcd_settings_quiet_time'.tr(),
            dimmed: !supported,
            trailing: _LinkValue(
                Text(window.displayLabel, key: LcdSettingsScreen.timeValueKey)),
            onTap:
                canEditTime ? () => context.push(lcdQuietTimePath(_id)) : null,
          ),
        ]),
      ),
      Padding(
        // 묶음 끝 y422 → 각주 y429.
        padding: const EdgeInsets.only(top: 7, left: 12, right: 12),
        child: Text(quietNote.tr(),
            key: LcdSettingsScreen.quietNoteKey,
            style: _footnoteStyle(context, color: glass.textTertiary)),
      ),
    ];
  }

  /// 전원 줄 아래 보조 글자(§12-1 신 규칙 / §11-3·D1 구 규칙). 판정은 서버
  /// 확정값 기준이고, 같은 종류 명령 대기 중엔 숨긴다.
  String? _powerNote(LcdScreenView view, bool powerPending, bool quietPending) {
    if (powerPending) return null;
    ref.watch(lcdResumeTickProvider);
    final now = ref.watch(lcdNowProvider)();
    final quiet = view.screen.quiet;
    final inQuiet = !quietPending && quiet != null && quiet.contains(now);
    String endLabel() => lcdAmPmLabel(quiet!.endAmPm);
    if (view.overrideRule) {
      final until = view.screen.overrideUntil;
      if (until != null) {
        return 'lcd_power_override_until'.tr(args: [
          lcdAmPmLabel(LcdAmPmTime.fromMinuteOfDay(kstMinuteOfDay(until))),
        ]);
      }
      final screenOn = view.screen.screenOn!;
      if (screenOn) return null;
      if (inQuiet) return 'lcd_power_in_quiet'.tr(args: [endLabel()]);
      if (quiet == null && !quietPending) return 'lcd_power_sticky_note'.tr();
      return null;
    }
    // 구 규칙 — 전원 켜짐이어도 예약 시간엔 화면이 꺼져 있다. 전원 꺼짐 안내는
    // 각주가 맡는다(§11-3).
    if (view.screen.power && inQuiet) {
      return 'lcd_power_in_quiet'.tr(args: [endLabel()]);
    }
    return null;
  }
}

TextStyle _footnoteStyle(BuildContext context, {Color? color}) =>
    envSettingText(context,
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 18,
        color: color ?? context.glass.textTertiary);

/// 묶음 아래 보조 글자 — 위 8, 왼쪽 12(x36). [textKey]는 글자에 붙는다.
class _Footnote extends StatelessWidget {
  const _Footnote(this.text, {this.textKey, this.color});
  final String text;
  final Key? textKey;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
        child: Text(text,
            key: textKey, style: _footnoteStyle(context, color: color)),
      );
}

/// 흰 줄 묶음 r16 — 줄 사이 2는 비워 바닥(#F4F4F4)이 선처럼 보이게(Figma 줄
/// y202→y252).
class _LcdGroup extends StatelessWidget {
  const _LcdGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              children[i],
            ],
          ],
        ),
      );
}

/// 줄 하나 — 최소 48(글자를 키우면 늘어난다), 제목 18/600 행간 21.48 #3C3C3C
/// 왼쪽 12. [dimmed]면 흐리게 + 조작 불가(구 펌웨어, D8).
class _LcdRow extends StatelessWidget {
  const _LcdRow({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    this.rightPadding = 12,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: rightPadding),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(title,
                  style: envSettingText(context,
                      size: 18,
                      weight: FontWeight.w600,
                      lineHeight: 21.48,
                      color: glass.textSecondary)),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ]),
      ),
    );
    if (dimmed) {
      row = IgnorePointer(child: Opacity(opacity: 0.4, child: row));
    }
    return Material(
      color: glass.surfaceHeader,
      child: onTap == null || dimmed ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

/// 이동 줄 오른쪽 — 값 16/500 행간 19.09 #949090(넘치면 말줄임) + 4 + 화살표
/// 18 #3C3C3C.
class _LinkValue extends StatelessWidget {
  const _LinkValue(this.value);
  final Text value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            // Figma 1660:6770 — 긴 문구가 약 130에서 말줄임된다.
            constraints: const BoxConstraints(maxWidth: 140),
            child: DefaultTextStyle.merge(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: envSettingText(context,
                  size: 16,
                  weight: FontWeight.w500,
                  lineHeight: 19.09,
                  color: context.glass.textTertiary),
              child: value,
            ),
          ),
          const SizedBox(width: 4),
          FigmaIcon.tinted(FigmaIcons.arrowNext,
              size: 18, color: context.glass.textSecondary),
        ],
      );
}

/// Figma 토글 80×32 — 켬 #C00306·끔 #B4AEAE, 손잡이 켬 #FAFAFA·끔 #F4F4F4.
/// [enabled]가 false면 눌리지 않고, [dimmed]면 흐리게(오프라인·사진 없음).
/// 보호 사진 화면도 쓴다.
class LcdSwitch extends StatelessWidget {
  const LcdSwitch({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.dimmed = false,
  });

  final bool value;
  final bool enabled;
  final bool dimmed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: !enabled,
          child: ScheduleSwitch(
            value: value,
            color: context.glass.navSelected,
            onKnobColor: ManagementColors.buttonForeground(context),
            onChanged: onChanged,
          ),
        ),
      );
}

/// 확인 대기 반짝임 — 덮은 줄은 눌리지 않는다(사육장 제어와 같은 문법).
/// [absorb]가 false면 반짝임만 그리고 탭은 아래 줄로 보낸다(보호 사진 줄 —
/// 대기 중 재진입은 화면 안에서 잠근다).
class _Pending extends StatelessWidget {
  const _Pending({
    required this.pending,
    required this.child,
    this.pendingKey,
    this.radius = 0,
    this.absorb = true,
  });

  final bool pending;
  final Widget child;
  final Key? pendingKey;
  final double radius;
  final bool absorb;

  @override
  Widget build(BuildContext context) {
    if (!pending) return child;
    final overlay = ControlLoadingOverlay(
        key: pendingKey, borderRadius: BorderRadius.circular(radius));
    return Stack(children: [
      child,
      Positioned.fill(child: absorb ? overlay : IgnorePointer(child: overlay)),
    ]);
  }
}
