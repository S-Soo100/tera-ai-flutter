import 'package:flutter/material.dart';
import '../../core/theme/glass_palette.dart';

/// Figma empty 765:3541 / 1846: 345x227 at y250, 16px gaps, CTA142x56.
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
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      height: 1.193359375,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.32,
                      color: glass.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                  width: 142,
                  height: 56,
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: glass.navSelected,
                          foregroundColor: glass.deviceGlyph,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: onPressed,
                      child: Text(buttonText,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)))),
            ])),
      ),
    ));
  }
}
