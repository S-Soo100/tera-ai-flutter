import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../thumbnail_cache_providers.dart';

/// motion_clips 썸네일 한 장 — 로컬 파일 우선, miss에서만 presign 조회 +
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
    this.cameraId = '',
    this.thumbnailVersion = 'original',
    this.fallbackIcon = Icons.movie_outlined,
    this.fallbackIconSize = 20,
    this.fallbackColor,
  });

  final String clipId;
  final String cameraId;
  final String thumbnailVersion;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  /// null이면 [GlassPalette.surfaceTint].
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(motionThumbnailFileProvider(
        (clipId: clipId, cameraId: cameraId, version: thumbnailVersion)));

    final fallback = ClipThumbFallback(
      icon: fallbackIcon,
      iconSize: fallbackIconSize,
      color: fallbackColor,
    );
    const skeleton = SkeletonLoading(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
    );

    return thumbAsync.when(
      data: (file) => file != null
          ? Image.file(file,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          : fallback,
      loading: () => skeleton,
      error: (_, __) => fallback,
    );
  }
}

/// 썸네일 없음·실패 폴백 — 면 + 가운데 아이콘. 움직임 영상과 직접 녹화
/// 썸네일이 같은 모양을 쓴다.
class ClipThumbFallback extends StatelessWidget {
  const ClipThumbFallback({
    super.key,
    this.icon = Icons.movie_outlined,
    this.iconSize = 20,
    this.color,
  });

  final IconData icon;
  final double iconSize;

  /// null이면 [GlassPalette.surfaceTint].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ColoredBox(
      color: color ?? glass.surfaceTint,
      child: Center(
        child: Icon(icon, size: iconSize, color: glass.textTertiary),
      ),
    );
  }
}
