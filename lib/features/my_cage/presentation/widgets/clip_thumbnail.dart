import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip.dart';
import '../my_cage_providers.dart';

class ClipThumbnail extends ConsumerWidget {
  const ClipThumbnail({
    super.key,
    required this.clip,
    this.fit = BoxFit.cover,
  });

  final Clip clip;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (clip.thumbnailPath == null) {
      return _buildPlaceholder(colorScheme);
    }

    final urlAsync = ref.watch(clipThumbnailUrlProvider(clip.id));

    return urlAsync.when(
      data: (media) => CachedNetworkImage(
        imageUrl: media.url,
        fit: fit,
        placeholder: (_, __) => const SkeletonLoading(
          width: double.infinity,
          height: double.infinity,
        ),
        errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
      ),
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      error: (_, __) => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colorScheme.outline,
        size: 28,
      ),
    );
  }
}
