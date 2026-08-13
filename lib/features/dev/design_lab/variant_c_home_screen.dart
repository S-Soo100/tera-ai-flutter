import 'package:flutter/material.dart';

import 'tokens/variant_c_tokens.dart';

/// C안 — Copilot Money (프리미엄 데이터 시각화) 스타일 홈 체험.
class VariantCHomeScreen extends StatelessWidget {
  const VariantCHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantCTokens.background,
      body: Center(
        child: Text('C안 — Copilot', style: VariantCTokens.body),
      ),
    );
  }
}
