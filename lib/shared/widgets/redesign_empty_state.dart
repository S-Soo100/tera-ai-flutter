import 'package:flutter/material.dart';
import '../../core/theme/glass_palette.dart';
import 'figma_icon.dart';

/// Figma empty CTA (1043:5063/5110/5161, 1107:9719): 56pt pill, `#C00306`
/// fill, 24pt horizontal padding, 24pt add glyph + 4pt gap + 18/600 label in
/// `#FAFAFA`. Width follows the label (142 for '기기 추가', 172 for
/// '개체 추가하기', 218 for '카메라와 그룹만들기').
class RedesignPillCta extends StatelessWidget {
  const RedesignPillCta(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
            backgroundColor: glass.navSelected,
            foregroundColor: glass.buttonForeground,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // 56 at the default text scale; a wrapped label grows the pill
            // instead of clipping it.
            minimumSize: const Size(0, 56),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder()),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FigmaIcon.tinted(FigmaIcons.add,
              size: 24, color: glass.buttonForeground),
          const SizedBox(width: 4),
          Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      height: 28 / 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.36,
                      color: glass.buttonForeground))),
        ]));
  }
}

/// Figma empty 765:3541 / 1846: 345x227 at y250, 16px gaps, pill CTA.
class RedesignEmptyState extends StatelessWidget {
  const RedesignEmptyState(
      {super.key,
      required this.image,
      required this.message,
      required this.buttonText,
      required this.onPressed});
  final ImageProvider image;
  final String message, buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 132, 24, 24),
      child: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 345),
            child: Column(children: [
              Image(image: image, width: 345, height: 227, fit: BoxFit.contain),
              const SizedBox(height: 16),
              // Figma: 16/500/19.09/-0.32 #626262 (Labels/Tertiary).
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      height: 1.193359375,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.32,
                      color: glass.bodySecondary)),
              const SizedBox(height: 16),
              RedesignPillCta(label: buttonText, onPressed: onPressed),
            ])),
      ),
    ));
  }
}
