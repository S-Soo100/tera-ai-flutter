import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/env_thresholds.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../profile/presentation/widgets/my_page_widgets.dart';
import '../domain/env_realtime_values.dart';
import 'env_live_providers.dart';
import 'temp_offset_providers.dart';
import 'widgets/device_offline_notice.dart';
import 'widgets/env_setting_widgets.dart';
import 'widgets/led_brightness_row.dart' show PillThumbShape;

/// 보정값 설정(Figma 1635:5551 S16 · 1635:5603 S14 · S33~S37, 메모 S45~S47).
///
/// - **첫 진입**(기기 보정이 꺼짐 = 공장 보정만)이면 "빼기 0.1"로 시작하고,
///   저장 전엔 아무것도 보내지 않는다(S45). 취소·뒤로가기면 온습도 설정의 보정
///   토글을 다시 끈다(S46).
/// - 저장해 둔 값을 고치다 취소하면 저장값 그대로(S47) — 명령 없음.
/// - 현재 측정 온도 = 기기 보고값에서 지금 사용자 보정을 걷어낸 값
///   ([TempOffset.measuredFrom]), 보정 온도 = 측정값 ± 선택값.
/// - 저장은 기기가 새 값을 보고할 때까지 기다린다([TempOffsetSaver.save], 최대
///   15초). 그동안 나가기·중복 저장을 막는다. 기기가 오프라인이면 저장을 막고
///   위에 이유를 띄운다.
class TempOffsetScreen extends ConsumerWidget {
  const TempOffsetScreen({super.key, required this.deviceId});

  final String deviceId;

  static const measuredKey = Key('temp_offset_measured');
  static const correctedKey = Key('temp_offset_corrected');
  static const subtractKey = Key('temp_offset_subtract');
  static const addKey = Key('temp_offset_add');
  static const magnitudeKey = Key('temp_offset_magnitude');
  static const sliderKey = Key('temp_offset_slider');
  static const saveKey = Key('temp_offset_save');
  static const cancelKey = Key('temp_offset_cancel');
  static const unsupportedKey = Key('temp_offset_unsupported');

  /// 첫 진입 기본값(S45) — 빼기 0.1.
  static const TempOffsetSelection firstEntryDefault =
      (subtract: true, tenths: 1);

  static const int _maxTenths = 40;

  /// 저장값 → 편집기 시작값. 꺼짐이면 첫 진입 기본값, 편집기 범위(±4) 밖이면 4.0.
  static TempOffsetSelection initialFor(TempOffset saved) => saved.isOff
      ? firstEntryDefault
      : (
          subtract: saved.isSubtract,
          tenths: math.min((saved.magnitude * 10).round(), _maxTenths)
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(deviceOffsetProvider(deviceId));
    final saving = ref.watch(tempOffsetSaveProvider(deviceId)) != null;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final deviceValue = offset.valueOrNull;
    final saved =
        deviceValue == null ? null : TempOffset.fromDevice(deviceValue);
    final selection = saved == null
        ? null
        : ref.watch(tempOffsetSelectionProvider(deviceId)) ?? initialFor(saved);
    final firstEntry = saved?.isOff ?? false;

    final Widget body;
    if (saved != null && selection != null) {
      body = _content(context, ref,
          deviceValue: deviceValue!, selection: selection, saving: saving);
    } else if (offset.hasValue) {
      body = _message(context, 'temp_offset_unsupported'.tr(),
          key: unsupportedKey);
    } else if (offset.hasError) {
      body = Column(children: [
        _message(context, 'env_range_load_failed'.tr()),
        InlineRetry(
            onRetry: () => ref.invalidate(deviceOffsetProvider(deviceId))),
      ]);
    } else {
      body = _loading();
    }

    final canSave = selection != null && online && !saving;
    return PopScope(
      // 저장 중에 나가면 결과(성공·실패)를 알릴 곳이 없어진다.
      canPop: !saving,
      onPopInvokedWithResult: (didPop, result) {
        // 저장 성공은 결과를 들고 닫힌다. 그 밖의 닫힘(취소·뒤로가기)이 첫 진입이면
        // 토글을 되돌린다(S46).
        if (didPop && result == null && firstEntry) {
          ref.read(tempOffsetToggleDraftProvider(deviceId).notifier).state =
              false;
        }
      },
      child: EnvSettingScaffold(
        title: 'temp_offset_title'.tr(),
        cta: MyPageCta(
            key: saveKey,
            label: (saving ? 'temp_offset_saving' : 'temp_offset_save').tr(),
            onPressed: canSave ? () => _save(context, ref, selection) : null),
        secondary: EnvSettingTextButton(
            key: cancelKey,
            label: 'temp_offset_cancel'.tr(),
            onPressed: saving ? null : () => Navigator.of(context).maybePop()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceOfflineNotice(deviceId: deviceId),
            body,
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref,
      {required double deviceValue,
      required TempOffsetSelection selection,
      required bool saving}) {
    final glass = context.glass;
    final live = ref.watch(envLiveViewProvider(deviceId));
    final reported = live.temperature;
    final measured = reported == null
        ? null
        : TempOffset.measuredFrom(reported, deviceValue);
    final chosen = TempOffset.of(
        subtract: selection.subtract, magnitude: selection.tenths / 10);
    final corrected = measured == null ? null : chosen.apply(measured);
    final stale = live.freshness != EnvFreshness.fresh;

    // 방향과 크기는 따로 바뀐다 — 지난 프레임 값이 아니라 지금 값에 덮어쓴다(같은
    // 프레임에 방향을 누르고 슬라이더를 움직여도 방향이 되돌아가지 않게).
    final selected = tempOffsetSelectionProvider(deviceId);
    void select({bool? subtract, int? tenths}) {
      if (saving) return;
      final now = ref.read(selected) ?? selection;
      ref.read(selected.notifier).state =
          (subtract: subtract ?? now.subtract, tenths: tenths ?? now.tenths);
    }

    Widget temp(double? v, Color color, Key key) => Opacity(
          opacity: stale && v != null ? 0.4 : 1,
          child: Text(
              v == null
                  ? '--'
                  : 'temp_offset_temp_value'.tr(args: [v.toStringAsFixed(1)]),
              key: key,
              style: envSettingText(context,
                  size: 18,
                  weight: FontWeight.w500,
                  lineHeight: 21.5,
                  color: color)),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EnvSettingCard(children: [
          EnvSettingRow(
              title: 'temp_offset_measured'.tr(),
              height: 53,
              trailing: temp(measured, glass.textPrimary, measuredKey)),
          EnvSettingRow(
              title: 'temp_offset_corrected'.tr(),
              height: 53,
              trailing: temp(corrected, glass.navSelected, correctedKey)),
        ]),
        EnvSettingFootnote('temp_offset_note'.tr()),
        const SizedBox(height: 24),
        EnvSettingCard(children: [
          EnvSettingRow(
            title: 'temp_offset_direction'.tr(),
            height: 64,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _DirectionButton(
                  key: subtractKey,
                  label: 'temp_offset_subtract'.tr(),
                  selected: selection.subtract,
                  onTap: () => select(subtract: true)),
              const SizedBox(width: 8),
              _DirectionButton(
                  key: addKey,
                  label: 'temp_offset_add'.tr(),
                  selected: !selection.subtract,
                  onTap: () => select(subtract: false)),
            ]),
          ),
          _MagnitudeRow(
            tenths: selection.tenths,
            onChanged: saving ? null : (t) => select(tenths: t),
          ),
        ]),
        const SizedBox(height: 24),
        EnvSettingSectionTitle('temp_offset_guide_title'.tr()),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: glass.surfaceHeader,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, key) in const [
                'temp_offset_guide_1',
                'temp_offset_guide_2',
                'temp_offset_guide_3'
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                Text(key.tr(),
                    style: envSettingText(context,
                        size: 14,
                        weight: FontWeight.w500,
                        lineHeight: 21,
                        color: glass.textSecondary)),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _message(BuildContext context, String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: envSettingText(context,
                size: 16,
                weight: FontWeight.w500,
                lineHeight: 19.1,
                color: context.glass.textTertiary)),
      );

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SkeletonLoading(
              width: double.infinity, height: 107, borderRadius: 16),
          SizedBox(height: 50),
          SkeletonLoading(
              width: double.infinity, height: 113, borderRadius: 16),
        ]),
      );

  Future<void> _save(BuildContext context, WidgetRef ref,
      TempOffsetSelection selection) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final offset = TempOffset.of(
        subtract: selection.subtract, magnitude: selection.tenths / 10);
    final result =
        await ref.read(tempOffsetSaveProvider(deviceId).notifier).save(offset);
    if (!context.mounted) return;
    switch (result) {
      case TempOffsetSaveResult.saved || TempOffsetSaveResult.unchanged:
        // PopScope(저장 중 막음)는 다음 프레임에 풀린다 — pop은 그와 무관하게
        // 바로 한다. 결과를 실어 보내 "첫 진입 취소"와 구분한다.
        if (navigator.canPop()) navigator.pop(offset);
      case TempOffsetSaveResult.noResponse:
        messenger.showSnackBar(
            SnackBar(content: Text('temp_offset_no_response'.tr())));
      case TempOffsetSaveResult.rejected:
        messenger
            .showSnackBar(SnackBar(content: Text('temp_offset_rejected'.tr())));
      case TempOffsetSaveResult.failed:
        messenger
            .showSnackBar(SnackBar(content: Text('temp_offset_failed'.tr())));
    }
  }
}

/// 빼기/더하기 버튼(S17·S18·S20·S21) — 96×40 r16. 선택 `#C00306` 위 16/700
/// `#FAFAFA`, 아니면 `#F4F4F4` 위 16/600 `#3C3C3C`.
class _DirectionButton extends StatelessWidget {
  const _DirectionButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? glass.navSelected : glass.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, minHeight: 40),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label,
                    style: envSettingText(context,
                        size: 16,
                        weight: selected ? FontWeight.w700 : FontWeight.w600,
                        lineHeight: 19.1,
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

/// 크기 행(Figma "Brightness" S19·S25) — 높이 48, 값 18/600 `#3C3C3C`(소수 한
/// 자리) 왼쪽 12, 트랙 6 `#E3E3E3`·채움 `#C00306`이 x133부터 오른쪽 12까지, 흰
/// 52×32 썸. 0.1~4.0, 0.1 단위(S24).
class _MagnitudeRow extends StatelessWidget {
  const _MagnitudeRow({required this.tenths, required this.onChanged});
  final int tenths;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          SizedBox(
            width: 121,
            child: Text((tenths / 10).toStringAsFixed(1),
                key: TempOffsetScreen.magnitudeKey,
                style: envSettingText(context,
                    size: 18,
                    weight: FontWeight.w600,
                    lineHeight: 21.5,
                    color: glass.textSecondary)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                activeTrackColor: glass.navSelected,
                inactiveTrackColor: glass.border,
                disabledActiveTrackColor: glass.navSelected,
                disabledInactiveTrackColor: glass.border,
                thumbShape: const PillThumbShape(),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const _FullWidthTrackShape(),
              ),
              child: SizedBox(
                height: 32,
                child: Slider(
                  key: TempOffsetScreen.sliderKey,
                  value: tenths.toDouble(),
                  min: 1,
                  max: TempOffsetScreen._maxTenths.toDouble(),
                  divisions: TempOffsetScreen._maxTenths - 1,
                  onChanged:
                      onChanged == null ? null : (v) => onChanged!(v.round()),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 트랙을 썸이 움직이는 범위에 맞춰 그린다(Figma S19·S25): 최대(4.0)면 썸 오른쪽
/// 끝 = 트랙 끝(회색이 비어져 나오지 않음), 최소(0.1)면 썸 왼쪽 끝이 트랙 시작에서
/// 4 안쪽이라 빨간 채움이 조금 보인다. 기본 모양은 썸 중심 범위에만 트랙을 그려
/// 양끝이 썸 밖으로 남는다.
class _FullWidthTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthTrackShape();

  static const double _thumbHalf = 26; // PillThumbShape 52 / 2
  static const double _leadIn = 4;

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required ui.TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 2}) {
    final travel = getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete);
    final h = sliderTheme.trackHeight ?? 6;
    final top = travel.center.dy - h / 2;
    // 둥근 트랙의 눈금 슬라이더는 썸 중심을 트랙 높이 절반(3)씩 더 안쪽에 둔다
    // (Flutter `_RenderSlider`) — 썸 실제 이동 범위에 맞춘다.
    final inset = h / 2;
    final left = travel.left + inset - _thumbHalf - _leadIn;
    final right = travel.right - inset + _thumbHalf;
    final radius = Radius.circular(h / 2);
    final canvas = context.canvas;
    canvas.drawRRect(RRect.fromLTRBR(left, top, right, top + h, radius),
        Paint()..color = sliderTheme.inactiveTrackColor!);
    canvas.drawRRect(
        RRect.fromLTRBR(left, top, thumbCenter.dx, top + h, radius),
        Paint()..color = sliderTheme.activeTrackColor!);
  }
}
