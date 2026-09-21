import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/glass_palette.dart';

/// 영상 시크바 — 크레캠 세로 플레이어·커뮤니티 확대 재생 공용(2026-09-21 추출).
/// 컨트롤러를 직접 listen해 position을 따라간다(VideoControls 패턴).
/// [controller]가 null이면(로딩/에러) 비활성 트랙만 그린다.
class VideoSeekBar extends StatefulWidget {
  const VideoSeekBar(
      {super.key, required this.controller, required this.onSeek});
  final Future<void> Function(Duration) onSeek;

  final VideoPlayerController? controller;

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> {
  /// 트랙을 탭/드래그로 조작 중인지 — 원형 커서(썸)는 이때만 그린다.
  /// 재생 중 상시 노출하지 않는다(사용자 지시 2026-09-12, 전 플레이어 공통
  /// 규칙 — VideoControls도 동일).
  bool _interacting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant VideoSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onUpdate);
      widget.controller?.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  double _value() {
    final v = widget.controller?.value;
    if (v == null) return 0;
    final dur = v.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (v.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        thumbShape: _interacting
            ? const RoundSliderThumbShape(enabledThumbRadius: 6)
            : SliderComponentShape.noThumb,
        activeTrackColor: glass.envTempPeak,
        // 연회색 트랙 — #E1E3E4 (T2에서 outline 토큰으로 정착)
        inactiveTrackColor: glass.outline,
        disabledActiveTrackColor: glass.outline,
        disabledInactiveTrackColor: glass.outline,
        thumbColor: glass.envTempPeak,
      ),
      child: Slider(
        value: _value(),
        onChangeStart: widget.controller == null
            ? null
            : (_) => setState(() => _interacting = true),
        onChangeEnd: widget.controller == null
            ? null
            : (_) => setState(() => _interacting = false),
        onChanged: widget.controller == null
            ? null
            : (val) {
                final ctrl = widget.controller!;
                final dur = ctrl.value.duration.inMilliseconds;
                if (dur > 0) {
                  unawaited(widget
                      .onSeek(Duration(milliseconds: (val * dur).round())));
                }
              },
      ),
    );
  }
}
