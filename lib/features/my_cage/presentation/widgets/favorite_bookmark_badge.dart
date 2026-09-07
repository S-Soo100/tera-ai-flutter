import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../my_cage_providers.dart';

/// 클립 셀 좌하단 북마크(즐겨찾기) 표시 — Figma 668:373/679 (32×32,
/// 2026-09-07 정밀 대조에서 누락 발견). 즐겨찾기가 아니면 아무것도 그리지
/// 않는다. 소비처는 셀 Stack에 `Positioned(left: 0, bottom: 0)`으로 얹는다
/// (카메라 홈 시간대 그리드 + 하이라이트 상세 — 북마크 상세는 전부
/// 북마크라 불필요).
class FavoriteBookmarkBadge extends ConsumerWidget {
  const FavoriteBookmarkBadge({super.key, required this.clipId});

  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isFavoriteProvider(clipId))) {
      return const SizedBox.shrink();
    }
    return const SizedBox(
      width: 32,
      height: 32,
      child: Center(
        // 썸네일(밝기 미상) 위라 테마 무관 흰색 + 그림자 — 라이브 오버레이
        // 문법(AppTheme.liveOnDark)과 같은 이유.
        child: Icon(
          Icons.bookmark,
          size: 24,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }
}
