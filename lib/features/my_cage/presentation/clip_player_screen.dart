import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/app_tag.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip.dart';
import '../domain/clip_media_url.dart';
import 'my_cage_providers.dart';
import 'widgets/behavior_chip_section.dart';
import 'widgets/video_controls.dart';

class ClipPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlayerScreen({super.key, required this.clipId});

  final String clipId;

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen> {
  VideoPlayerController? _controller;
  Clip? _clip;
  String? _error;
  bool _initialized = false;
  bool _didRetryUrl = false;
  VoidCallback? _errorListener;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer({bool isRetry = false}) async {
    VideoPlayerController? controller;
    try {
      final repo = ref.read(clipRepositoryProvider);
      final cacheRepo = ref.read(videoCacheRepositoryProvider);
      final clip = await repo.getById(widget.clipId);
      if (clip == null) {
        if (mounted) {
          setState(() => _error = 'error_generic'.tr());
        }
        return;
      }

      // Cache hit 시도 (retry 진입 시는 skip — 만료된 URL이 캐시된 거 아니라 미러링)
      File? cachedFile;
      if (!isRetry) {
        cachedFile = await cacheRepo.getCached(widget.clipId);
      }

      if (cachedFile != null) {
        controller = VideoPlayerController.file(cachedFile);
      } else {
        // Cache miss → presigned URL → 다운로드 후 file 재생
        final ClipMediaUrl media;
        if (isRetry) {
          ref.invalidate(clipFileUrlProvider(widget.clipId));
        }
        media = await ref.read(clipFileUrlProvider(widget.clipId).future);

        final downloadedFile =
            await cacheRepo.downloadAndCache(widget.clipId, media.url);
        controller = VideoPlayerController.file(downloadedFile);
      }

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final c = controller; // 클로저 캡처용 non-null 참조
      _errorListener = () {
        final ctrlValue = c.value;
        if (ctrlValue.hasError && !_didRetryUrl && mounted) {
          _didRetryUrl = true;
          c.removeListener(_errorListener!);
          c.dispose();
          setState(() {
            _controller = null;
            _initialized = false;
          });
          _initPlayer(isRetry: true);
        }
      };
      c.addListener(_errorListener!);

      setState(() {
        _controller = controller;
        _clip = clip;
        _initialized = true;
      });
      _controller!.play();
    } catch (e) {
      await controller?.dispose();
      if (!isRetry && mounted) {
        _didRetryUrl = true;
        await _initPlayer(isRetry: true);
        return;
      }
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null && _errorListener != null) {
      _controller!.removeListener(_errorListener!);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: AppStyles.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                const SizedBox(height: AppStyles.spacing12),
                Text('error_generic'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppStyles.spacing8),
                Text(_error!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppStyles.spacing16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final clip = _clip;

    return Scaffold(
      appBar: AppBar(
        title: clip != null
            ? Text(DateFormat('yyyy.MM.dd HH:mm')
                .format(clip.startedAt.toLocal()))
            : const SizedBox.shrink(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 비디오 영역
          if (!_initialized)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            )
          else
            () {
              final ar = _controller!.value.aspectRatio;
              return AspectRatio(
                aspectRatio: ar.isFinite && ar > 0 ? ar : 16 / 9,
                child: VideoPlayer(_controller!),
              );
            }(),

          // 컨트롤
          if (_initialized && _controller != null)
            VideoControls(controller: _controller!),

          // 하단 메타
          if (clip != null)
            Container(
              color: Colors.black87,
              padding: AppStyles.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('yyyy년 MM월 dd일 HH:mm:ss')
                            .format(clip.startedAt.toLocal()),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      if (clip.hasMotion)
                        AppTag(
                          label: 'clip_motion_badge'.tr(),
                          color: colorScheme.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppStyles.spacing4),
                  Text(
                    'clip_duration_seconds'.tr(
                      namedArgs: {
                        'seconds': clip.durationSec.round().toString()
                      },
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppStyles.spacing8),
                  BehaviorChipSection(clipId: widget.clipId),
                ],
              ),
            ),

          const Spacer(),
        ],
      ),
    );
  }
}
