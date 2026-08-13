import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import 'glass_chip.dart';

/// 탭 상단 유리 헤더. 디자인 시스템 `Components / GlassTabHeader` (A안).
///
/// 홈 `HomeHeaderBar`가 세운 문법을 나머지 탭이 공유한다 — **대형 타이틀이
/// 주인공**, 보조 정보는 유리 캡슐([GlassChip]), 액션 아이콘은 항상 밝다
/// (표면이 테마와 무관하게 어두운 월페이퍼라 테마 기본색에 맡기지 않는다).
///
/// 홈은 세트 분기·알림 점 등 자기 로직이 붙어 있어 자체 헤더를 유지한다 —
/// 이 위젯은 그 표면 문법만 떼어낸 것이다. 구 [ScreenHeader](56pt 고정)는
/// 전환 전 화면·테스트가 참조하므로 남겨 둔다.
class GlassTabHeader extends StatelessWidget {
  const GlassTabHeader({
    super.key,
    required this.title,
    this.capsuleLabel,
    this.onPickCapsule,
    this.capsuleArrowKey,
    this.actions = const [],
  });

  /// 주인공. 개체 이름 또는 탭 이름.
  final String title;

  /// 보조 캡슐 문구(어느 사육장인지 등). null이면 캡슐 자체가 서지 않는다.
  final String? capsuleLabel;

  /// 캡슐이 선택기로 동작할 때만 준다. null이면 눌리지 않는 캡슐이 된다.
  final VoidCallback? onPickCapsule;

  /// 캡슐 드롭다운 화살표에 붙일 키(테스트용).
  final Key? capsuleArrowKey;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing8,
        AppStyles.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.glassHeaderTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (capsuleLabel != null) ...[
                  const SizedBox(height: AppStyles.spacing4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassChip(
                      onTap: onPickCapsule,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              capsuleLabel!,
                              style: AppTheme.glassTileStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onPickCapsule != null) ...[
                            const SizedBox(width: AppStyles.spacing4),
                            Icon(
                              Icons.expand_more,
                              key: capsuleArrowKey,
                              size: 16,
                              color: AppTheme.glassTextSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconTheme.merge(
            data: const IconThemeData(color: AppTheme.glassTextPrimary),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      ),
    );
  }
}
