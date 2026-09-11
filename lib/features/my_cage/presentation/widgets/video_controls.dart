import 'package:easy_localization/easy_localization.dart';
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
  const VideoControls(
      {super.key, required this.controller, this.showFromStart = false});

  final VideoPlayerController controller;

  /// true면 "처음부터"(0초로 seek 후 재생) 버튼을 함께 그린다 — 서버
  /// 시작점(`play_from_sec`)으로 중간에서 시작한 하이라이트 재생용.
  final bool showFromStart;

  /// 테스트용 — "처음부터" 버튼 식별.
  static const fromStartKey = Key('video_controls_from_start');

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  /// 트랙을 탭/드래그로 조작 중인지 — 원형 커서(썸)는 이때만 그린다.
  /// 재생 중 상시 노출하지 않는다(사용자 지시 2026-09-12, 전 플레이어 공통
  /// 규칙 — 세로 재생목록 플레이어 _SeekBar도 동일).
  bool _interacting = false;

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
      // 영상 위에 겹쳐 놓이므로 단색 띠가 아니라 아래로 갈수록 짙어지는 그라디언트다.
      // 단색이면 영상 하단이 잘려 보인다.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0, 0.45],
        ),
      ),
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
              thumbShape: _interacting
                  ? const RoundSliderThumbShape(enabledThumbRadius: 7)
                  : SliderComponentShape.noThumb,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _sliderValue(v),
              onChangeStart: (_) => setState(() => _interacting = true),
              onChangeEnd: (_) => setState(() => _interacting = false),
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
              if (widget.showFromStart)
                IconButton(
                  key: VideoControls.fromStartKey,
                  icon: const Icon(Icons.restart_alt, color: Colors.white),
                  tooltip: 'crecam_player_from_start'.tr(),
                  onPressed: () {
                    ctrl.seekTo(Duration.zero);
                    ctrl.play();
                  },
                ),
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
