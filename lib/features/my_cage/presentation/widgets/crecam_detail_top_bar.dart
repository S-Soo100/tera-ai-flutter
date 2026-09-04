import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';

/// 북마크·하이라이트 상세 공용 상단바 (Figma 668:717/600, T1 플레이어와 같은
/// 문법) — 높이 44, 좌 back 44×44, 중앙 타이틀 16 SemiBold textSecondary,
/// 우 calendar 44×44(날짜 필터).
class CrecamDetailTopBar extends StatelessWidget {
  const CrecamDetailTopBar({
    super.key,
    required this.title,
    required this.onCalendarTap,
  });

  final String title;
  final VoidCallback onCalendarTap;

  /// 테스트용 — calendar 버튼 식별.
  static const calendarButtonKey = Key('crecam_detail_calendar');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new,
                    size: 24, color: glass.textPrimary),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.pop(),
              ),
            ),
          ),
          Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 16 * -0.02,
                color: glass.textSecondary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: calendarButtonKey,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.calendar_today,
                    size: 20, color: glass.textPrimary),
                tooltip: 'crecam_home_period'.tr(),
                onPressed: onCalendarTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 날짜 필터 활성 중일 때 상단바 아래 한 줄 칩 — "2026. 8. 31 ✕".
/// 탭하면 필터 해제([onClear]).
class CrecamDateFilterChip extends StatelessWidget {
  const CrecamDateFilterChip({
    super.key,
    required this.day,
    required this.onClear,
  });

  final DateTime day;
  final VoidCallback onClear;

  /// 테스트용 — 필터 칩 식별.
  static const chipKey = Key('crecam_detail_filter_chip');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: glass.surfaceTint,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: chipKey,
          borderRadius: BorderRadius.circular(8),
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('yyyy. M. d').format(day),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 14 * -0.02,
                    color: glass.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.close, size: 16, color: glass.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 상세 화면 공용 날짜 선택 — 선택 시 자정 정규화 값을 돌려준다(취소 = null).
Future<DateTime?> showCrecamDayPicker(
    BuildContext context, DateTime? current) async {
  final now = DateTime.now();
  final initial = current == null || current.isAfter(now) ? now : current;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2024, 1, 1),
    lastDate: now,
  );
  if (picked == null) return null;
  return DateTime(picked.year, picked.month, picked.day);
}
