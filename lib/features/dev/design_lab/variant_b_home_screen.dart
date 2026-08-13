import 'package:flutter/material.dart';

import 'tokens/variant_b_tokens.dart';

/// B안 — Flighty (공항 전광판 데이터 밀도) 스타일 홈 체험.
class VariantBHomeScreen extends StatelessWidget {
  const VariantBHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantBTokens.background,
      body: Center(
        child: Text('B안 — Flighty', style: VariantBTokens.body),
      ),
    );
  }
}
