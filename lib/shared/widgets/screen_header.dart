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

  /// 모든 탭이 공유하는 헤더 높이.
  ///
  /// 액션이 1개인 탭(통계·커뮤니티)과 3개인 탭(홈)의 높이가 달라지지 않게
  /// 못박는다. [HeaderAction]의 `IconButton`이 48이므로 그보다 커야 한다.
  static const double height = 56;

  /// 선택기의 누를 자리 여백. 좌우 패딩 계산에서 되돌려야 하므로 상수로 둔다.
  static const double _pickerInset = AppStyles.spacing8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // **폭이 모자라면 보조부터 줄고 제목은 마지막까지 버틴다.**
        // 둘에 같은 flex를 주면 주인공까지 같이 깎이고(`크랑이` → `크...`),
        // 제목을 아예 안 감싸면 이름이 긴 개체에서 Row가 넘친다. 2:1로 나눠
        // 제목에 우선권을 준다 — 둘 다 짧으면 각자 실제 폭만 쓴다.
        Flexible(
          flex: 2,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.36,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: AppStyles.spacing4),
          Flexible(
            flex: 1,
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

    // **높이를 고정한다.** 액션 개수나 선택기 유무로 높이가 달라지면, 탭을
    // 옮길 때마다 아래 내용이 위아래로 튄다.
    return SizedBox(
      height: height,
      // 선택기는 누를 자리를 넓히려고 [_pickerInset]만큼 안쪽 여백을 갖는다.
      // 그만큼 왼쪽을 당겨줘야 **제목 글자가 탭마다 같은 x에서 시작한다.**
      // 안 그러면 선택기가 있는 탭(홈·통계)만 8pt 오른쪽으로 밀린다.
      child: Padding(
        padding: EdgeInsets.only(
          left: onPick == null
              ? AppStyles.spacing16
              : AppStyles.spacing16 - _pickerInset,
          right: AppStyles.spacing16,
        ),
        child: Row(
          children: [
            // `Flexible` + `Spacer`로 두지 않는다. 둘 다 flex라 남은 폭을 반씩
            // 나눠 갖고, 액션이 하나 늘면 라벨 몫이 부족해져 **보조가 통째로
            // 사라진다**(아바타를 붙이자 `테스트`가 없어졌다).
            // Expanded로 라벨이 남은 폭을 전부 갖고, Align이 실제 폭만 쓰게 한다.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: onPick == null
                    ? label
                    : InkWell(
                        onTap: onPick,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _pickerInset,
                            vertical: AppStyles.spacing4,
                          ),
                          child: label,
                        ),
                      ),
              ),
            ),
            ...actions,
          ],
        ),
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
