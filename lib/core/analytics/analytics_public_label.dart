import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Only audited, fixed main-navigation labels may opt out of root masking.
/// Keep this order aligned with kHomeTabLabelKeys (covered by a contract test).
enum AnalyticsPublicLabelKind {
  home('tab_home'),
  camera('tab_camera'),
  pets('tab_my_pets'),
  community('tab_community');

  const AnalyticsPublicLabelKind(this.translationKey);
  final String translationKey;
}

/// Accepts no arbitrary text or child: the unmasked subtree is one fixed Text.
class AnalyticsPublicLabel extends StatelessWidget {
  const AnalyticsPublicLabel({
    super.key,
    required this.kind,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final AnalyticsPublicLabelKind kind;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => ClarityUnmask(
        child: Text(
          kind.translationKey.tr(),
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
}
