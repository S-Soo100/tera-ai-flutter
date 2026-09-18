import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../management_colors.dart';
import 'management_widgets.dart';

/// 연결 확인 카드의 한 줄 — 36 원(#3C3C3C) 안 20 글리프, 라벨, 오른쪽 이름.
class LinkConfirmRow {
  const LinkConfirmRow(
      {required this.icon, required this.label, required this.name});
  final String icon;
  final String label;
  final String name;
}

/// 기기·개체 연결 확인 전체 화면 — Figma 990:7508("연결한 사육장과 함께
/// 사용할까요?") / 994:13307("도마뱀과 기기를 연결합니다"). 2026-09-16 사용자
/// 결정으로 둘 다 구현.
///
/// 흰 바탕, 제목 18/600 y266·부제 16/500 y295(가운데), 목록 345×(64×n) r12
/// #F4F4F4 y338, CTA 369×56 y696 + 텍스트 버튼 y752. [onPrimary]가 끝나면
/// `true`, 두 번째 버튼은 `false`로 닫힌다. 실패는 스낵바로 알리고 화면에 남는다.
class LinkConfirmScreen extends StatefulWidget {
  const LinkConfirmScreen(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.rows,
      required this.primaryLabel,
      required this.secondaryLabel,
      required this.onPrimary,
      this.primaryKey,
      this.secondaryKey,
      this.failureText});

  final String title;
  final String subtitle;
  final List<LinkConfirmRow> rows;
  final String primaryLabel;
  final String secondaryLabel;
  final Future<void> Function() onPrimary;
  final Key? primaryKey;
  final Key? secondaryKey;

  /// 실패 스낵바 문구. null이면 예외 문자열.
  final String Function(Object error)? failureText;

  @override
  State<LinkConfirmScreen> createState() => _LinkConfirmScreenState();
}

class _LinkConfirmScreenState extends State<LinkConfirmScreen> {
  bool _busy = false;

  Future<void> _primary() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPrimary();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.failureText?.call(e) ?? '$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
        backgroundColor: glass.surfaceHeader,
        body: SafeArea(
            child: Stack(children: [
          Padding(
              padding: EdgeInsets.fromLTRB(
                  24,
                  math.min(
                      266 - safeTop, MediaQuery.sizeOf(context).height * 0.31),
                  24,
                  0),
              child: Column(children: [
                Text(widget.title,
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                        size: 18, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(widget.subtitle,
                    textAlign: TextAlign.center,
                    style:
                        managementStyle(context, color: glass.bodySecondary)),
                const SizedBox(height: 24),
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(children: [
                      for (final row in widget.rows)
                        Container(
                            height: 64,
                            color: glass.surfaceTint,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [
                              Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: glass.textSecondary,
                                      shape: BoxShape.circle),
                                  child: Center(
                                      child: FigmaIcon.tinted(row.icon,
                                          size: 20,
                                          color:
                                              ManagementColors.buttonForeground(
                                                  context)))),
                              const SizedBox(width: 12),
                              Text(row.label,
                                  style: managementStyle(context,
                                      weight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(row.name,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: managementStyle(context,
                                          weight: FontWeight.w600,
                                          color: glass.textPrimary))),
                            ])),
                    ])),
              ])),
          Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ManagementButton(
                    key: widget.primaryKey,
                    label: widget.primaryLabel,
                    onPressed: _busy ? null : _primary),
                SizedBox(
                    height: 56,
                    child: TextButton(
                        key: widget.secondaryKey,
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            foregroundColor: glass.textSecondary,
                            textStyle: managementStyle(context,
                                    size: 18, weight: FontWeight.w600)
                                .copyWith(height: 28 / 18)),
                        child: Text(widget.secondaryLabel))),
              ])),
        ])));
  }
}
