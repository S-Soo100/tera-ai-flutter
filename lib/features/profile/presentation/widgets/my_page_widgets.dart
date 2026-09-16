import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../my_cage/presentation/management_colors.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';

/// Figma 마이페이지 계열(1142:8859) 공용 조각.
///
/// 섹션 제목 16/500 `#949090`(왼쪽 12) → 8 → 행. 목록 행 369×64 흰색 r12
/// 선 `#E3E3E3`: 아이콘 원 36(`#3C3C3C`, 글리프 24 `#FAFAFA`) 왼쪽 16 → 12 →
/// 제목 16/600 `#3C3C3C` + 부제 14/500 `#949090`, 오른쪽 값 14/500 + 4 +
/// arrow_forward_ios 18, 오른쪽 16.

/// Figma에서 SVG를 못 받아 4배 PNG로 보관한 글리프(person_cancel·notifications·
/// info_i — `assets/icons/redesign_v2/png/`). 디자이너 SVG 전달 시 [FigmaIcon]
/// 으로 교체한다(RESULTS §C 자산).
class MyPageRasterIcon extends StatelessWidget {
  const MyPageRasterIcon(this.name,
      {super.key, this.size = 24, required this.color});
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Image.asset(
      'assets/icons/redesign_v2/png/$name.png',
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.medium);
}

class MyPageSectionTitle extends StatelessWidget {
  const MyPageSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(text,
          style:
              managementStyle(context, color: context.glass.textTertiary)));
}

/// 목록 행. [icon]은 36 원 안에 그릴 24 위젯. [subtitle]이 없으면 제목만
/// 세로 가운데(내 계정 행 문법 1134:7760).
class MyPageRow extends StatelessWidget {
  const MyPageRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.trailingText,
      this.showArrow = true,
      this.onTap,
      this.badge});
  final String title;
  final String? subtitle;
  final Widget? icon;
  final String? trailingText;
  final bool showArrow;
  final VoidCallback? onTap;

  /// 아이콘 오른쪽 위 8 빨간 점(받은 알림 미읽음).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
        color: glass.surfaceHeader,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: glass.border)),
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
                height: 64,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      if (icon != null) ...[
                        Stack(clipBehavior: Clip.none, children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: glass.textSecondary,
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: icon),
                          if (badge != null)
                            Positioned(top: -1, right: -1, child: badge!),
                        ]),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    weight: FontWeight.w600)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: managementStyle(context,
                                      size: 14, color: glass.textTertiary)),
                            ],
                          ])),
                      if (trailingText != null) ...[
                        const SizedBox(width: 4),
                        Text(trailingText!,
                            style: managementStyle(context,
                                size: 14, color: glass.textTertiary)),
                      ],
                      if (showArrow) ...[
                        const SizedBox(width: 4),
                        FigmaIcon.tinted(FigmaIcons.arrowNext,
                            size: 18, color: glass.textSecondary),
                      ],
                    ])))));
  }
}

/// 사람 아이콘 원(Figma person 52/160 `#B4AEAE`) — 사진이 있으면 사진.
class MyPageAvatar extends StatelessWidget {
  const MyPageAvatar({super.key, required this.size, this.imageUrl});
  final double size;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipOval(
        child: SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
                color: glass.deviceOff,
                child: imageUrl != null
                    ? Image.network(imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _person(context))
                    : _person(context))));
  }

  Widget _person(BuildContext context) => Center(
      child: FigmaIcon.tinted(FigmaIcons.person,
          size: size * 0.5, color: ManagementColors.buttonForeground(context)));
}

/// 상단바 + 표준 배경의 마이페이지 계열 스캐폴드. 본문은 x12, 헤더 아래 16.
class MyPageScaffold extends StatelessWidget {
  const MyPageScaffold(
      {super.key,
      required this.title,
      required this.child,
      this.floating,
      this.white = false,
      this.padding = const EdgeInsets.fromLTRB(12, 16, 12, 24)});
  final String title;
  final Widget child;

  /// 플로팅 CTA(y696 규칙 — 하단 100 = 안전영역 34 + 66).
  final Widget? floating;
  final bool white;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
        backgroundColor: white ? glass.surfaceHeader : glass.surfaceTint,
        body: Stack(children: [
          SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ManagementTopBar(
                        title: title,
                        onBack: () => Navigator.of(context).maybePop())),
                Expanded(
                    child: SingleChildScrollView(
                        padding: floating == null
                            ? padding
                            : padding.copyWith(
                                bottom: padding.bottom + bottom + 66 + 56),
                        child: child)),
              ])),
          if (floating != null)
            Positioned(
                left: 12,
                right: 12,
                // Figma y696 → 하단 100(안전영역 34 + 66). 안전영역이 더 크면 66 유지.
                bottom: math.max(100.0, bottom + 66),
                child: floating!),
        ]));
  }
}

/// 플로팅 CTA 369×56 r12 18/600 — 활성 `#1E1E1E`(또는 [color]), 비활성 `#E3E3E3`.
class MyPageCta extends StatelessWidget {
  const MyPageCta(
      {super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;

  /// 활성 색. null이면 `#1E1E1E`(textPrimary). 로그아웃·탈퇴는 `#C00306`.
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SizedBox(
        height: 56,
        child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
                backgroundColor: color ?? glass.textPrimary,
                disabledBackgroundColor: glass.border,
                foregroundColor: ManagementColors.buttonForeground(context),
                disabledForegroundColor:
                    ManagementColors.buttonForeground(context),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: managementStyle(context,
                        size: 18, weight: FontWeight.w600)
                    .copyWith(height: 28 / 18, letterSpacing: -0.36)),
            child: Text(label)));
  }
}

String? experienceLabelKey(String? experience) => switch (experience) {
      'beginner' => 'commu_profile_exp_beginner',
      'intermediate' => 'commu_profile_exp_intermediate',
      'expert' => 'commu_profile_exp_expert',
      _ => null,
    };

String? experienceDescKey(String? experience) => switch (experience) {
      'beginner' => 'commu_profile_exp_beginner_desc',
      'intermediate' => 'commu_profile_exp_intermediate_desc',
      'expert' => 'commu_profile_exp_expert_desc',
      _ => null,
    };

String experienceLabel(String? experience) =>
    experienceLabelKey(experience)?.tr() ?? '';
