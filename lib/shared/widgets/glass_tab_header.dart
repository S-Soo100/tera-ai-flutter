import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import 'glass_chip.dart';

/// 탭 상단 헤더. 디자인 시스템 `Components / GlassTabHeader` (A안 — 이름은
/// 역사적, 2차부터 솔리드).
///
/// 홈 `HomeHeaderBar`가 세운 문법을 **홈 포함 모든 탭**이 공유한다 —
/// **대형 타이틀이 주인공**, 보조 정보는 캡슐([GlassChip]), 액션
/// 아이콘은 항상 밝다(바닥이 테마와 무관하게 어두워 테마 기본색에
/// 맡기지 않는다).
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

  /// 액션 하나가 차지하는 폭(아이콘 버튼 48pt) — 제목이 액션 밑으로 깔리지
  /// 않게 **양옆 대칭**으로 비운다. 한쪽만 비우면 제목이 화면 중앙에서 밀린다.
  static const double _actionSlotWidth = 48;

  @override
  Widget build(BuildContext context) {
    // 제목·캡슐은 **화면 기준 가운데**(2026-08-14 사용자 결정 — 랩 A안과 통일).
    // 액션이 우측에 있어 Row로 두면 제목이 왼쪽으로 밀리므로, 제목 열을 Stack
    // 바닥에 화면 폭 전체로 깔고 액션은 우측 오버레이로 얹는다.
    final actionsWidth = _actionSlotWidth * actions.length.clamp(0, 3);
    final rightInset = AppStyles.spacing8 + actionsWidth;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppStyles.spacing8,
          AppStyles.spacing8,
          AppStyles.spacing8,
          AppStyles.spacing12,
        ),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: _titleSlot,
                      child: _CenteredTitle(
                        title: title,
                        rightInset: rightInset,
                        maxWidth: c.maxWidth,
                      ),
                    ),
                    const SizedBox(height: AppStyles.spacing4),
                    SizedBox(
                      height: _capsuleSlot,
                      child: capsuleLabel == null
                          ? null
                          : Center(
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
              // 액션은 우측 상단(제목 줄 높이)에 얹는다.
              if (actions.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  height: _titleSlot,
                  child: IconTheme.merge(
                    data:
                        const IconThemeData(color: AppTheme.glassTextPrimary),
                    child:
                        Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목 한 줄 — 화면 정중앙 우선, 공간이 모자라면 읽히는 쪽 우선.
///
/// 우측 인셋은 액션 폭 그대로(제목이 액션 밑으로 절대 안 들어간다). 좌측
/// 인셋은 우측과 **같게** 두어 대칭 → 정중앙인데, 액션 3개(144pt)면 대칭
/// 인셋만으로 제목 폭이 ~90pt까지 줄어 긴 제목이 "사…"로 뭉개진다. 그때만
/// 좌측 인셋을 풀어(0까지) 텍스트에 폭을 준다 — 짧은 제목은 정중앙, 긴 제목은
/// 살짝 좌측으로 무게가 실리더라도 읽힌다.
class _CenteredTitle extends StatelessWidget {
  const _CenteredTitle({
    required this.title,
    required this.rightInset,
    required this.maxWidth,
  });

  final String title;
  final double rightInset;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: AppTheme.glassHeaderTitle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final needed = painter.width;
    // 대칭일 때 남는 폭. 모자라면 좌측 인셋을 줄여 보충한다.
    final symmetricRoom = maxWidth - rightInset * 2;
    final leftInset = needed <= symmetricRoom
        ? rightInset
        : (maxWidth - rightInset - needed).clamp(0.0, rightInset);

    return Padding(
      padding: EdgeInsets.only(left: leftInset, right: rightInset),
      child: Center(
        child: Text(
          title,
          style: AppTheme.glassHeaderTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
