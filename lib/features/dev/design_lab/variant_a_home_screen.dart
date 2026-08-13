import 'package:flutter/material.dart';

import 'tokens/variant_a_tokens.dart';

/// A안 — Apple Home (iOS 26, Liquid Glass) 스타일 홈 체험.
class VariantAHomeScreen extends StatelessWidget {
  const VariantAHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantATokens.wallpaperTop,
      body: Center(
        child: Text('A안 — Liquid Glass', style: VariantATokens.tileTitle),
      ),
    );
  }
}
