import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip.dart';
import '../my_cage_providers.dart';

class ClipCard extends ConsumerStatefulWidget {
  const ClipCard({super.key, required this.clip, required this.onTap});

  final Clip clip;
  final VoidCallback onTap;

  @override
  ConsumerState<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends ConsumerState<ClipCard> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    final headers = await ref.read(clipRepositoryProvider).authHeaders();
    if (mounted) {
      setState(() => _headers = headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final repo = ref.read(clipRepositoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 썸네일
            AspectRatio(
              aspectRatio: 16 / 9,
              child: clip.thumbnailPath != null
                  ? _buildThumbnail(repo.thumbnailUrl(clip.id), colorScheme)
                  : _buildThumbnailPlaceholder(colorScheme),
            ),

            // 하단 메타
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (clip.hasMotion) ...[
                    AppTag(
                      label: 'clip_motion_badge'.tr(),
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    durationLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String url, ColorScheme colorScheme) {
    // 헤더 로드 전: shimmer 표시
    if (_headers == null) {
      return const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: _headers!,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      errorWidget: (_, __, ___) => _buildThumbnailPlaceholder(colorScheme),
    );
  }

  Widget _buildThumbnailPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colorScheme.outline,
        size: 36,
      ),
    );
  }
}
