import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';

/// 카메라 탭 계열 공용 빈 상태 — 중앙 단문(Pretendard 14 Medium textTertiary).
///
/// 북마크·하이라이트 상세에 바이트 동일 복붙 2벌로 있던 것을 승격(리뷰
/// 2026-09-04). shared `EmptyState`(테두리 박스)와 문법이 달라 — 이 계열은
/// Figma가 중앙 단문이다 — 별도 위젯으로 둔다.
class CrecamEmptyMessage extends StatelessWidget {
  const CrecamEmptyMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 14 * -0.02,
          color: glass.textTertiary,
        ),
      ),
    );
  }
}

/// 카메라 탭 계열 공용 에러+재시도 — "오류가 발생했어요" + OutlinedButton.
class CrecamErrorRetry extends StatelessWidget {
  const CrecamErrorRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'error_generic'.tr(),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: glass.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text('retry'.tr())),
        ],
      ),
    );
  }
}
