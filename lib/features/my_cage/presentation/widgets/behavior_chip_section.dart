import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../my_cage_providers.dart';

/// 클립 상세 하단에 표시하는 라벨/추론 chip 섹션 (read-only).
///
/// - 두 provider 중 하나라도 데이터가 있으면 섹션 노출.
/// - 둘 다 loading/error/empty → [SizedBox.shrink()] (silent fail).
/// - 탭/수정 UI 없음.
class BehaviorChipSection extends ConsumerWidget {
  const BehaviorChipSection({super.key, required this.clipId});

  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(clipLabelsProvider(clipId));
    final inferenceAsync = ref.watch(clipInferenceProvider(clipId));

    final labels = labelsAsync.valueOrNull ?? const [];
    final inference = inferenceAsync.valueOrNull;

    // 둘 다 비어있으면(로딩/에러/빈 배열+null) 섹션 숨김
    if (labels.isEmpty && inference == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── human label 섹션 ─────────────────────────────────────────────────
        if (labels.isNotEmpty) ...[
          Text(
            'clip_label_section_title'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppStyles.spacing8),
          Wrap(
            spacing: AppStyles.spacing8,
            runSpacing: AppStyles.spacing8,
            children: labels.map((label) {
              final actionText = label.action.localizationKey.tr();
              final lickTarget = label.lickTarget;
              final chipLabel = lickTarget != null
                  ? '$actionText → ${lickTarget.localizationKey.tr()}'
                  : actionText;
              return AppTag(label: chipLabel, color: colorScheme.primary);
            }).toList(),
          ),
        ],

        // 섹션 간격 (둘 다 있을 때)
        if (labels.isNotEmpty && inference != null)
          const SizedBox(height: AppStyles.spacing8),

        // ── AI 추론 섹션 ─────────────────────────────────────────────────────
        if (inference != null) ...[
          Text(
            'clip_inference_section_title'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppStyles.spacing8),
          AppTag(
            label: inference.action.localizationKey.tr(),
            color: colorScheme.outline,
          ),
        ],
      ],
    );
  }
}
