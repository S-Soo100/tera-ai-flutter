import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/motion_clip.dart';
import 'my_cage_providers.dart';
import 'widgets/video_controls.dart';
import 'widgets/video_watermark.dart';

/// motion_clips 재생. 즐겨찾기면 로컬 파일(오프라인), 아니면 terra-api presigned URL.
class MotionClipPlayerScreen extends ConsumerStatefulWidget {
  const MotionClipPlayerScreen({super.key, required this.clipId});
  final String clipId;

  @override
  ConsumerState<MotionClipPlayerScreen> createState() =>
      _MotionClipPlayerScreenState();
}

class _MotionClipPlayerScreenState
    extends ConsumerState<MotionClipPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _initialized = false;
  bool _busy = false; // 저장/공유/즐겨찾기 진행 중

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool isRetry = false}) async {
    try {
      // 즐겨찾기(로컬 파일) 우선 — 오프라인 재생 가능
      final localFile =
          ref.read(favoriteClipRepositoryProvider).getLocalFile(widget.clipId);
      final VideoPlayerController controller;
      if (localFile != null) {
        controller = VideoPlayerController.file(localFile);
      } else {
        if (isRetry) ref.invalidate(motionClipUrlProvider(widget.clipId));
        final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      controller.play();
    } catch (e) {
      if (!isRetry && mounted) {
        await _init(isRetry: true);
        return;
      }
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 로컬 파일 있으면 그걸, 없으면 presigned URL을 확보해 저장/공유에 넘긴다.
  Future<({File? file, String? url})> _source() async {
    final f = ref.read(favoriteClipRepositoryProvider).getLocalFile(widget.clipId);
    if (f != null) return (file: f, url: null);
    final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
    return (file: null, url: url);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('clip_saving'.tr())));
    try {
      final src = await _source();
      await ref.read(videoExportServiceProvider).saveToGallery(
            widget.clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
      messenger.showSnackBar(
          SnackBar(content: Text('clip_saved_to_gallery'.tr())));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final src = await _source();
      await ref.read(videoExportServiceProvider).share(
            widget.clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
    } catch (_) {
      // 공유 취소/실패는 조용히 무시
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(MotionClip? clip) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(favoriteClipRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (repo.isFavorite(widget.clipId)) {
        final cameraId = await repo.remove(widget.clipId);
        ref.invalidate(isFavoriteProvider(widget.clipId));
        if (cameraId != null) ref.invalidate(favoriteClipsProvider(cameraId));
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_removed'.tr())));
      } else {
        if (clip == null) return; // 오프라인 등 메타 없음 → 추가 불가
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_saving'.tr())));
        final url =
            await ref.read(motionClipUrlProvider(widget.clipId).future);
        await repo.add(clip, url);
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
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: AppStyles.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error, size: 48),
                const SizedBox(height: AppStyles.spacing12),
                Text('error_generic'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    final clip = ref.watch(motionClipProvider(widget.clipId)).valueOrNull;
    final isFav = ref.watch(isFavoriteProvider(widget.clipId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.redAccent : Colors.white),
            tooltip: 'clip_favorite_add'.tr(),
            onPressed: _busy ? null : () => _toggleFavorite(clip),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'clip_save'.tr(),
            onPressed: _busy ? null : _save,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'clip_share'.tr(),
            onPressed: _busy ? null : _share,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!_initialized)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoading(
                  width: double.infinity, height: double.infinity, borderRadius: 0),
            )
          else
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(_controller!)),
                  const VideoWatermark(),
                ],
              ),
            ),
          if (_initialized && _controller != null)
            VideoControls(controller: _controller!),
          const Spacer(),
        ],
      ),
    );
  }
}
