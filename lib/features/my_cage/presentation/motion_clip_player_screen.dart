import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'my_cage_providers.dart';

/// motion_clips 재생. terra-api presigned URL을 networkUrl로 직접 재생
/// (camera_clips 전용 ClipPlayerScreen과 분리 — 캐시/behavior 없음).
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool isRetry = false}) async {
    try {
      if (isRetry) ref.invalidate(motionClipUrlProvider(widget.clipId));
      final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: Center(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              iconSize: 22,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: !_initialized
            ? const AspectRatio(
                aspectRatio: 16 / 9,
                child: SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0),
              )
            : AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller!),
                    VideoProgressIndicator(_controller!, allowScrubbing: true),
                    _PlayPauseButton(controller: _controller!),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return IconButton(
      iconSize: 48,
      icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
          color: Colors.white70),
      onPressed: () =>
          playing ? widget.controller.pause() : widget.controller.play(),
    );
  }
}
