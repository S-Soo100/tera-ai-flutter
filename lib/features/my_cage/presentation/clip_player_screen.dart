import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/app_tag.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip.dart';
import 'my_cage_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final repo = ref.read(clipRepositoryProvider);
      final clip = await repo.getById(widget.clipId);
      if (clip == null) {
        if (mounted) {
          setState(() => _error = 'error_generic'.tr());
        }
        return;
      }
      final headers = await repo.authHeaders();
      final url = repo.fileUrl(widget.clipId);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _clip = clip;
        _initialized = true;
      });
      _controller!.play();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  void dispose() {
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
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

          // 컨트롤
          if (_initialized && _controller != null)
            _VideoControls(controller: _controller!),

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
                ],
              ),
            ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ── 비디오 컨트롤 위젯 ────────────────────────────────────────────────────────

class _VideoControls extends StatefulWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isPlaying = ctrl.value.isPlaying;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            ctrl,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).colorScheme.primary,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final pos = ctrl.value.position -
                      const Duration(seconds: 10);
                  ctrl.seekTo(pos < Duration.zero ? Duration.zero : pos);
                },
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () =>
                    isPlaying ? ctrl.pause() : ctrl.play(),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final pos = ctrl.value.position +
                      const Duration(seconds: 10);
                  final dur = ctrl.value.duration;
                  ctrl.seekTo(pos > dur ? dur : pos);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
