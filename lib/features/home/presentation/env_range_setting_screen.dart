import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/env_thresholds.dart';
import '../../../shared/domain/num_format.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/viva_stepper.dart';
import '../../my_cage/data/device_settings_repository.dart';
import '../../my_cage/domain/device_settings.dart';
import '../../my_cage/presentation/device_settings_providers.dart';
import '../../profile/presentation/widgets/my_page_widgets.dart';
import 'widgets/env_setting_widgets.dart';

/// 적정 범위 종류 — 라우트 `/temp-humid-settings/:deviceId/{temp|humid}`의
/// 마지막 조각이 [name]이다.
enum EnvRangeKind { temp, humid }

extension EnvRangeKindX on EnvRangeKind {
  EnvRangeRule get rule => switch (this) {
        EnvRangeKind.temp => EnvRangeRule.temp,
        EnvRangeKind.humid => EnvRangeRule.humid,
      };

  /// 서버 설정 → 화면용 범위(미설정 = 디폴트, 범위·스텝 밖 = 가장 가까운 허용값).
  EnvRange rangeOf(DeviceSettings s) => switch (this) {
        EnvRangeKind.temp => s.tempRange,
        EnvRangeKind.humid => s.humidRange,
      };

  /// "18℃ ~ 26℃" / "40% ~ 80%".
  String format(EnvRange r) => switch (this) {
        EnvRangeKind.temp => 'env_range_temp_value',
        EnvRangeKind.humid => 'env_range_humid_value',
      }
          .tr(args: [formatCompact(r.min), formatCompact(r.max)]);

  String get _title => switch (this) {
        EnvRangeKind.temp => 'env_range_temp_title',
        EnvRangeKind.humid => 'env_range_humid_title',
      }
          .tr();

  /// "적정 온도" / "적정 습도" — 온습도 설정 화면 행 제목과 같다.
  String get label => switch (this) {
        EnvRangeKind.temp => 'env_range_temp_label',
        EnvRangeKind.humid => 'env_range_humid_label',
      }
          .tr();

  String get _guideTitle => switch (this) {
        EnvRangeKind.temp => 'env_range_temp_guide_title',
        EnvRangeKind.humid => 'env_range_humid_guide_title',
      }
          .tr();

  List<String> get _guide => switch (this) {
        EnvRangeKind.temp => const [
            'env_range_temp_guide_1',
            'env_range_temp_guide_2'
          ],
        EnvRangeKind.humid => const [
            'env_range_humid_guide_1',
            'env_range_humid_guide_2',
            'env_range_humid_guide_3'
          ],
      }
          .map((k) => k.tr())
          .toList();
}

/// 편집 상태. [edited]가 null이면 저장값 그대로 보고 있다.
class EnvRangeDraft {
  const EnvRangeDraft({this.edited, this.saving = false});
  final EnvRange? edited;
  final bool saving;
}

/// 적정 범위 편집(기기 id + 종류). autoDispose — 화면을 벗어나면 편집값을 버린다.
final envRangeDraftProvider = NotifierProvider.autoDispose
    .family<EnvRangeDraftNotifier, EnvRangeDraft, (String, EnvRangeKind)>(
  EnvRangeDraftNotifier.new,
);

class EnvRangeDraftNotifier
    extends AutoDisposeFamilyNotifier<EnvRangeDraft, (String, EnvRangeKind)> {
  bool _disposed = false;

  @override
  EnvRangeDraft build((String, EnvRangeKind) arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const EnvRangeDraft();
  }

  void edit(EnvRange range) =>
      state = EnvRangeDraft(edited: range, saving: state.saving);

  /// 변경 사항 취소(S10) — 저장값으로 되돌린다.
  void discard() => state = EnvRangeDraft(saving: state.saving);

  /// MIN·MAX를 **함께** PATCH(한쪽만 보내면 서버 `min ≤ max` 검증이 저장된
  /// 반대쪽과 비교한다). 성공하면 기기 설정을 다시 읽게 하고 true. 저장할 수
  /// 없는 값·저장 중이면 보내지 않고 false. 실패는 예외 그대로 — 편집값은 유지.
  Future<bool> save(EnvRange range) async {
    final (deviceId, kind) = arg;
    if (state.saving || !range.isValidFor(kind.rule)) return false;
    state = EnvRangeDraft(edited: state.edited, saving: true);
    final repo = ref.read(deviceSettingsRepositoryProvider);
    try {
      switch (kind) {
        case EnvRangeKind.temp:
          await repo.patch(deviceId,
              targetTempMin: range.min, targetTempMax: range.max);
        case EnvRangeKind.humid:
          await repo.patch(deviceId,
              targetHumidMin: range.min, targetHumidMax: range.max);
      }
    } catch (_) {
      if (!_disposed) {
        state = EnvRangeDraft(edited: state.edited, saving: false);
      }
      rethrow;
    }
    if (!_disposed) {
      ref.invalidate(deviceSettingsProvider(deviceId));
      state = EnvRangeDraft(edited: state.edited, saving: false);
    }
    return true;
  }
}

/// 적정 온도 설정(Figma 1635:5123 S08·1623:8882 S10) / 적정 습도 설정
/// (1635:5165 S11·1623:9103 S13).
///
/// 대상 기기는 **라우트의 [deviceId]로 고정**한다 — 편집 중 홈 세트가 바뀌어도
/// 들어온 기기에 저장한다. 헤더 오른쪽 빨간 값은 **저장값**이고, 스테퍼는
/// 편집값이다. 저장은 [EnvRange.isValidFor]를 통과할 때만 누를 수 있다.
class EnvRangeSettingScreen extends ConsumerWidget {
  const EnvRangeSettingScreen(
      {super.key, required this.deviceId, required this.kind});

  final String deviceId;
  final EnvRangeKind kind;

  static const savedValueKey = Key('env_range_saved_value');
  static const minStepperKey = Key('env_range_min_stepper');
  static const maxStepperKey = Key('env_range_max_stepper');
  static const saveKey = Key('env_range_save');
  static const discardKey = Key('env_range_discard');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = (deviceId, kind);
    final settings = ref.watch(deviceSettingsProvider(deviceId));
    final draft = ref.watch(envRangeDraftProvider(target));
    final saved =
        settings.hasValue ? kind.rangeOf(settings.requireValue) : null;
    final current = draft.edited ?? saved;
    final dirty = saved != null && current != saved;
    final canSave =
        current != null && !draft.saving && current.isValidFor(kind.rule);

    final Widget body;
    if (saved != null && current != null) {
      body = _content(context, ref, saved: saved, current: current);
    } else if (settings.hasError) {
      body = _error(context, ref);
    } else {
      body = _loading();
    }

    return PopScope(
      // 저장 중에 나가면 저장 결과(성공·실패)를 알릴 곳이 없어진다.
      canPop: !draft.saving,
      child: EnvSettingScaffold(
        title: kind._title,
        cta: MyPageCta(
            key: saveKey,
            label: 'env_range_save'.tr(),
            onPressed: canSave ? () => _save(context, ref, current) : null),
        secondary: dirty && !draft.saving
            ? _DiscardButton(
                onPressed: () =>
                    ref.read(envRangeDraftProvider(target).notifier).discard())
            : null,
        child: body,
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref,
      {required EnvRange saved, required EnvRange current}) {
    final glass = context.glass;
    final rule = kind.rule;
    final notifier = ref.read(envRangeDraftProvider((deviceId, kind)).notifier);
    void edit(double min, double max) => notifier.edit(EnvRange(min, max));
    final min = current.min;
    final max = current.max;

    final minDown = rule.canDecreaseMin(current);
    final minUp = rule.canIncreaseMin(current);
    final maxDown = rule.canDecreaseMax(current);
    final maxUp = rule.canIncreaseMax(current);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EnvSettingCard(children: [
          EnvSettingRow(
            title: kind.label,
            height: 53,
            trailing: Text(kind.format(saved),
                key: savedValueKey,
                style: envSettingText(context,
                    size: 18,
                    weight: FontWeight.w500,
                    lineHeight: 21.5,
                    color: glass.navSelected)),
          ),
          EnvSettingRow(
            title: 'env_range_min'.tr(),
            titleWeight: FontWeight.w500,
            height: 56,
            trailing: VivaStepper(
              key: minStepperKey,
              value: formatCompact(min),
              onDecrease: minDown ? () => edit(rule.decrease(min), max) : null,
              onIncrease: minUp ? () => edit(rule.increase(min), max) : null,
            ),
          ),
          EnvSettingRow(
            title: 'env_range_max'.tr(),
            titleWeight: FontWeight.w500,
            height: 56,
            trailing: VivaStepper(
              key: maxStepperKey,
              value: formatCompact(max),
              onDecrease: maxDown ? () => edit(min, rule.decrease(max)) : null,
              onIncrease: maxUp ? () => edit(min, rule.increase(max)) : null,
            ),
          ),
        ]),
        EnvSettingFootnote('env_range_usage_note'.tr()),
        const SizedBox(height: 24),
        EnvSettingSectionTitle(kind._guideTitle),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: glass.surfaceHeader,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, line) in kind._guide.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                Text(line,
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

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SkeletonLoading(
              width: double.infinity, height: 167, borderRadius: 16),
          SizedBox(height: 24),
          SkeletonLoading(
              width: double.infinity, height: 137, borderRadius: 16),
        ]),
      );

  Widget _error(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          Text('env_range_load_failed'.tr(),
              textAlign: TextAlign.center,
              style: envSettingText(context,
                  size: 16,
                  weight: FontWeight.w500,
                  lineHeight: 19.1,
                  color: context.glass.textTertiary)),
          InlineRetry(
              onRetry: () => ref.invalidate(deviceSettingsProvider(deviceId))),
        ]),
      );

  Future<void> _save(
      BuildContext context, WidgetRef ref, EnvRange range) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(envRangeDraftProvider((deviceId, kind)).notifier);
    try {
      final saved = await notifier.save(range);
      // PopScope(저장 중 막음)는 다음 프레임에 풀린다 — pop은 그와 무관하게
      // 바로 한다(maybePop이 아니라 pop).
      if (saved && context.mounted && navigator.canPop()) navigator.pop();
    } catch (_) {
      if (!context.mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('env_range_save_failed'.tr())));
    }
  }
}

/// 변경 사항 취소(S10 TextButton 369×56 r12) — 18/600 행간 28 `#C00306`.
class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        key: EnvRangeSettingScreen.discardKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
            foregroundColor: glass.navSelected,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: Text('env_range_discard'.tr(),
            style: envSettingText(context,
                size: 18,
                weight: FontWeight.w600,
                lineHeight: 28,
                color: glass.navSelected)),
      ),
    );
  }
}
