import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_styles.dart';

/// `Duration` → `m:ss`(분:초, 초 2자리). 재생 시간 라벨용 순수함수.
String formatClipPosition(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 영상 재생 컨트롤 — 진행바(스크럽) + 현재/총 시간 + 10초 앞뒤 + 재생/일시정지.
/// ClipPlayerScreen·MotionClipPlayerScreen 공용.
class VideoControls extends StatefulWidget {
  const VideoControls({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  double _sliderValue(VideoPlayerValue v) {
    final dur = v.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (v.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final v = ctrl.value;
    final isPlaying = v.isPlaying;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _sliderValue(v),
              onChanged: (val) {
                final dur = v.duration.inMilliseconds;
                if (dur > 0) {
                  ctrl.seekTo(Duration(milliseconds: (val * dur).round()));
                }
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(formatClipPosition(v.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(formatClipPosition(v.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final pos = v.position - const Duration(seconds: 10);
                  ctrl.seekTo(pos < Duration.zero ? Duration.zero : pos);
                },
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 36),
                onPressed: () => isPlaying ? ctrl.pause() : ctrl.play(),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final pos = v.position + const Duration(seconds: 10);
                  final dur = v.duration;
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
