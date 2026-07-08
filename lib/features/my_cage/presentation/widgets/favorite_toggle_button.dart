import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../my_cage_providers.dart';

/// 클립 즐겨찾기 토글 버튼. 추가 시 motion_clip 메타 + presigned URL을 받아
/// 로컬 다운로드(+클라우드 push는 repo가 처리). 리포트 카드 등 공용.
/// clipId = motion_clips.id (하이라이트 미러도 동일 UUID).
class FavoriteToggleButton extends ConsumerStatefulWidget {
  const FavoriteToggleButton({super.key, required this.clipId, this.color});

  final String clipId;
  final Color? color;

  @override
  ConsumerState<FavoriteToggleButton> createState() =>
      _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends ConsumerState<FavoriteToggleButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(favoriteClipRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (repo.isFavorite(widget.clipId)) {
        final cameraId = await repo.remove(widget.clipId);
        if (!mounted) return;
        ref.invalidate(isFavoriteProvider(widget.clipId));
        if (cameraId != null) ref.invalidate(favoriteClipsProvider(cameraId));
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_removed'.tr())));
      } else {
        final clip = await ref.read(motionClipProvider(widget.clipId).future);
        if (clip == null) {
          if (mounted) {
            messenger.showSnackBar(
                SnackBar(content: Text('clip_save_failed'.tr())));
          }
          return;
        }
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_saving'.tr())));
        final url =
            await ref.read(motionClipUrlProvider(widget.clipId).future);
        await repo.add(clip, url);
        if (!mounted) return;
        ref.invalidate(isFavoriteProvider(widget.clipId));
        ref.invalidate(favoriteClipsProvider(clip.cameraId));
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_added'.tr())));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFav = ref.watch(isFavoriteProvider(widget.clipId));
    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav
            ? Colors.redAccent
            : (widget.color ?? Theme.of(context).colorScheme.outline),
      ),
      tooltip: 'clip_favorite_add'.tr(),
      onPressed: _busy ? null : _toggle,
    );
  }
}
