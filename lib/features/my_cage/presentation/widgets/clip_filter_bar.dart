import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';

/// 클립 리스트 상단 필터 칩 바.
///
/// [motionOnly] : true = "움직임만" 활성, false = "전체" 활성.
/// [onChanged]  : 사용자가 다른 칩을 탭했을 때만 호출됨.
class ClipFilterBar extends StatelessWidget {
  const ClipFilterBar({
    super.key,
    required this.motionOnly,
    required this.onChanged,
  });

  final bool motionOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Wrap(
        spacing: AppStyles.spacing8,
        children: [
          FilterChip(
            label: Text('clip_filter_motion_only'.tr()),
            selected: motionOnly,
            onSelected: (selected) {
              if (selected) onChanged(true);
            },
          ),
          FilterChip(
            label: Text('clip_filter_all'.tr()),
            selected: !motionOnly,
            onSelected: (selected) {
              if (selected) onChanged(false);
            },
          ),
        ],
      ),
    );
  }
}
