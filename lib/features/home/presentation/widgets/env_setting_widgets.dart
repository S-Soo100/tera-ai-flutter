import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';

/// 온습도 설정 묶음(Figma 1635:6166 — S04·S05·S08·S10·S11·S13) 공용 조각.
///
/// 393×852 기준 수치: 바닥 `#F4F4F4`(surfaceTint), 헤더 106(상태바 62 + 44)
/// `#FAFAFA`(appBar) + 하단선 `#E3E3E3`(border). 본문은 헤더 아래 24, 좌우 24.
/// 섹션 제목 16/600 행간 19.1 `#949090` 왼쪽 12 → 8 → 흰 면 r16 카드(행 사이
/// 1px 선 `#E3E3E3`, 바깥 테두리 없음) → 8 → 각주 14/500 행간 18 `#949090`
/// 왼쪽 12. 섹션 사이 24.

/// Figma 글자 규칙(자간 −2%, 행간 px 고정)대로 만든 글꼴.
TextStyle envSettingText(BuildContext context,
        {required double size,
        required FontWeight weight,
        required double lineHeight,
        required Color color}) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: -size * .02,
        color: color);

/// 헤더 + 스크롤 본문 + (있으면) 하단 고정 버튼.
///
/// 하단 버튼은 콘텐츠 위에 떠 있다(CLAUDE.md "공통 하단 CTA"). 저장 버튼 위쪽
/// y695 = 화면 아래에서 101(안전영역 34 + 67) — 안전영역이 더 크면 그 위 67.
/// [secondary](변경 사항 취소, S10)는 저장 바로 아래 56 칸에 그린다 — 나타나도
/// 저장 버튼 자리는 움직이지 않는다.
class EnvSettingScaffold extends StatelessWidget {
  const EnvSettingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.cta,
    this.secondary,
  });

  final String title;
  final Widget child;
  final Widget? cta;
  final Widget? secondary;

  static const double _ctaHeight = 56;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final inset = MediaQuery.paddingOf(context).bottom;
    final ctaBottom = math.max(101.0, inset + 67);
    return Scaffold(
      backgroundColor: glass.surfaceTint,
      body: Stack(children: [
        Column(children: [
          Container(
            color: glass.appBar,
            foregroundDecoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: glass.border))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ManagementTopBar(
                    title: title,
                    onBack: () => Navigator.of(context).maybePop()),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              // 버튼이 있으면 마지막 항목이 저장·취소 버튼 밑에 깔리지 않게
              // 버튼 두 칸(저장 + 취소 자리)만큼 더 비운다.
              padding: EdgeInsets.only(
                  top: 24,
                  bottom:
                      cta == null ? 24 + inset : ctaBottom + _ctaHeight + 24),
              child: child,
            ),
          ),
        ]),
        if (cta != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: ctaBottom - _ctaHeight,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              cta!,
              SizedBox(height: _ctaHeight, child: secondary),
            ]),
          ),
      ]),
    );
  }
}

/// 섹션 제목 16/600 `#949090` — 왼쪽 12, 아래 8.
class EnvSettingSectionTitle extends StatelessWidget {
  const EnvSettingSectionTitle(this.text, {super.key, this.bottom = 8});
  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom),
        child: Text(text,
            style: envSettingText(context,
                size: 16,
                weight: FontWeight.w600,
                lineHeight: 19.1,
                color: context.glass.textTertiary)),
      );
}

/// 카드 아래 각주 14/500 행간 18 `#949090` — 위 8, 왼쪽 12.
class EnvSettingFootnote extends StatelessWidget {
  const EnvSettingFootnote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 12),
        child: Text(text,
            style: envSettingText(context,
                size: 14,
                weight: FontWeight.w500,
                lineHeight: 18,
                color: context.glass.textTertiary)),
      );
}

/// 흰 면 r16 카드. 행 사이에 1px 선(`#E3E3E3`)을 넣는다 — 바깥 테두리는 없다.
class EnvSettingCard extends StatelessWidget {
  const EnvSettingCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: glass.surfaceHeader,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                ColoredBox(
                    color: glass.border, child: const SizedBox(height: 1)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// 카드 안 한 행 — 제목 18/[titleWeight] 행간 21.5 `#3C3C3C` 왼쪽 12.
///
/// [height]는 최소 높이다(글자를 키우면 늘어난다). [onTap]이 있으면 행 전체가
/// 눌린다.
class EnvSettingRow extends StatelessWidget {
  const EnvSettingRow({
    super.key,
    required this.title,
    this.trailing,
    this.height = 48,
    this.rightPadding = 12,
    this.titleWeight = FontWeight.w600,
    this.onTap,
  });

  final String title;
  final Widget? trailing;
  final double height;
  final double rightPadding;
  final FontWeight titleWeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: rightPadding),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(title,
                  style: envSettingText(context,
                      size: 18,
                      weight: titleWeight,
                      lineHeight: 21.5,
                      color: context.glass.textSecondary)),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ]),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// 이동 행 오른쪽: 값 16/500 행간 19.1 `#949090` + 4 + arrow_forward_ios 18
/// `#3C3C3C`.
class EnvSettingLinkTrailing extends StatelessWidget {
  const EnvSettingLinkTrailing({super.key, required this.value});

  /// 값 자리. 보통 [Text] — 로딩 중엔 스켈레톤.
  final Widget value;

  static TextStyle valueStyle(BuildContext context) => envSettingText(context,
      size: 16,
      weight: FontWeight.w500,
      lineHeight: 19.1,
      color: context.glass.textTertiary);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DefaultTextStyle.merge(style: valueStyle(context), child: value),
          const SizedBox(width: 4),
          FigmaIcon.tinted(FigmaIcons.arrowNext,
              size: 18, color: context.glass.textSecondary),
        ],
      );
}
