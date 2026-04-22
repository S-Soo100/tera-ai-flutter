import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip.dart';
import '../my_cage_providers.dart';

/// 3열 그리드용 클립 카드.
///
/// - 16:9 AspectRatio 썸네일
/// - 우상단: "HH:mm" 오버레이 (검정 반투명 배경)
/// - 좌상단: hasMotion이면 주황 8px dot
class ClipGridCard extends ConsumerStatefulWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onTap,
  });

  final Clip clip;
  final VoidCallback onTap;

  @override
  ConsumerState<ClipGridCard> createState() => _ClipGridCardState();
}

class _ClipGridCardState extends ConsumerState<ClipGridCard> {
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
    final timeLabel = DateFormat('HH:mm').format(clip.startedAt.toLocal());

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 썸네일
              clip.thumbnailPath != null
                  ? _buildThumbnail(repo.thumbnailUrl(clip.id), colorScheme)
                  : _buildPlaceholder(colorScheme),

              // 시간 오버레이 (우상단)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // 움직임 dot (좌상단)
              if (clip.hasMotion)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String url, ColorScheme colorScheme) {
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
      errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
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
