import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../my_cage_providers.dart';

/// motion_clips 썸네일 한 장 — presign URL 조회([motionThumbnailProvider]) +
/// 캐시 키([clipId] 고정 — 서명 쿼리가 매번 달라도 디스크 캐시 유지) +
/// 로딩 shimmer + 실패/없음 폴백까지의 **단일 구현**.
///
/// 같은 블록이 Camera Home 셀·하이라이트 셀·북마크 카드에 3벌 복제돼
/// 폴백 모양이 화면마다 표류했다(리뷰 2026-09-04). 폴백의 아이콘·크기·
/// 배경만 파라미터다.
class MotionClipThumb extends ConsumerWidget {
  const MotionClipThumb({
    super.key,
    required this.clipId,
    this.fallbackIcon = Icons.movie_outlined,
    this.fallbackIconSize = 20,
    this.fallbackColor,
  });

  final String clipId;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  /// null이면 [GlassPalette.surfaceTint].
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final thumbAsync = ref.watch(motionThumbnailProvider(clipId));

    final fallback = ColoredBox(
      color: fallbackColor ?? glass.surfaceTint,
      child: Center(
        child: Icon(fallbackIcon,
            size: fallbackIconSize, color: glass.textTertiary),
      ),
    );
    const skeleton = SkeletonLoading(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
    );

    return thumbAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              cacheKey: 'thumb_$clipId',
              fit: BoxFit.cover,
              placeholder: (_, __) => skeleton,
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
      loading: () => skeleton,
      error: (_, __) => fallback,
    );
  }
}
