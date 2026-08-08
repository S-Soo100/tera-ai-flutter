import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';

/// 화면 상단 헤더. 디자인 시스템 `Components / ScreenHeader`.
///
/// 무엇을 보고 있는지(제목 + 보조) + 액션 아이콘들. **개체 선택기가 붙는 탭이
/// 공유한다** — 기획안 §4.3.1이 통계 탭에도 같은 개체 드롭다운을 요구한다.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onPick,
    this.pickerArrowKey,
    this.actions = const [],
  });

  /// 주인공. 개체 이름.
  final String title;

  /// 보조. 어느 사육장인지.
  ///
  /// 제목과 **한 덩어리로 합치지 않는다** — `크랑이 (테스트)`처럼 붙이면
  /// 뭐가 주인공인지 읽는 사람이 매번 판단해야 한다.
  final String? subtitle;

  /// 선택기로 동작할 때만 준다. null이면 **누를 수 없는 제목**이 된다 —
  /// 화살표만 숨기는 게 아니라 눌리는 느낌 자체를 없앤다(기획안 §4.1.1 예외).
  final VoidCallback? onPick;

  /// 드롭다운 화살표에 붙일 키. 탭 대상이라 화면 쪽에서 잡을 수 있어야 한다.
  final Key? pickerArrowKey;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 제목은 Flexible로 감싸지 않는다. 보조와 나란히 Flexible을 두면 둘이
        // 남는 폭을 나눠 갖느라 **주인공까지 같이 깎인다**(`크랑이` → `크...`).
        // 폭이 모자라면 보조부터 줄고, 제목은 마지막까지 버틴다.
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.36,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(width: AppStyles.spacing4),
          Flexible(
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (onPick != null)
          Icon(Icons.expand_more,
              key: pickerArrowKey,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Row(
        children: [
          Flexible(
            child: onPick == null
                ? label
                : InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppStyles.spacing8,
                        vertical: AppStyles.spacing4,
                      ),
                      child: label,
                    ),
                  ),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// 헤더 액션 아이콘. 미읽음 등 알림 점을 붙일 수 있다.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
    this.dotKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// 주의를 끌 일이 있는가(미읽음 알림 등).
  final bool showDot;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (showDot)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              key: dotKey,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                // 시스템 색을 쓴다. 예전엔 Colors.red 하드코딩이었다.
                color: AppTheme.subRed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
