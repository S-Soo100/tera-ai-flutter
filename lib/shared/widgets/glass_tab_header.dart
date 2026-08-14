import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import 'glass_chip.dart';

/// 탭 상단 유리 헤더. 디자인 시스템 `Components / GlassTabHeader` (A안).
///
/// 홈 `HomeHeaderBar`가 세운 문법을 **홈 포함 모든 탭**이 공유한다 —
/// **대형 타이틀이 주인공**, 보조 정보는 유리 캡슐([GlassChip]), 액션
/// 아이콘은 항상 밝다(표면이 테마와 무관하게 어두운 월페이퍼라 테마
/// 기본색에 맡기지 않는다).
///
/// 홈도 렌더링은 여기에 위임한다 — 세트 분기·알림 점 같은 로직만
/// `HomeHeaderBar`에 남는다. 구 `ScreenHeader`(56pt 고정)는 참조가 0이 되어
/// 삭제했다(`screen_header.dart`에는 [HeaderAction]만 남았다).
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

  /// 제목 줄 슬롯 — [AppTheme.glassHeaderTitle] 실높이(28 × 1.15).
  static const double _titleSlot = 28 * 1.15;

  /// 캡슐 줄 슬롯 — 캡슐(글자 13 + 세로 패딩 5×2 + 테두리)이 앉는 높이.
  /// **캡슐이 없어도 이 줄을 예약한다** — 탭마다 캡슐 유무가 달라서, 내용에
  /// 맡기면 4탭을 오갈 때 제목 베이스라인이 위아래로 튄다.
  static const double _capsuleSlot = 30;

  /// 헤더 전체 높이. 캡슐 유무·액션 개수와 무관하게 항상 이 값이다.
  static const double height = AppStyles.spacing8 +
      _titleSlot +
      AppStyles.spacing4 +
      _capsuleSlot +
      AppStyles.spacing12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
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
                children: [
                  SizedBox(
                    height: _titleSlot,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: AppTheme.glassHeaderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppStyles.spacing4),
                  SizedBox(
                    height: _capsuleSlot,
                    child: capsuleLabel == null
                        ? null
                        : Align(
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
                  ),
                ],
              ),
            ),
            IconTheme.merge(
              data: const IconThemeData(color: AppTheme.glassTextPrimary),
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}
