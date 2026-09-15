import 'package:flutter/material.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../core/theme/viva_colors.dart';

/// Figma field 765:7432 / 765:8682: VIVA Fill/Back (#FAFAFA).
abstract final class ManagementColors {
  static Color nameField(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? VivaColors.fillBack
          : context.glass.overlay;
}
