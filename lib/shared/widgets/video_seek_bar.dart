import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/glass_palette.dart';

/// 영상 시크바 — 크레캠 세로 플레이어·커뮤니티 확대 재생 공용(2026-09-21 추출).
/// 컨트롤러를 직접 listen해 position을 따라간다(VideoControls 패턴).
/// [controller]가 null이면(로딩/에러) 비활성 트랙만 그린다.
class VideoSeekBar extends StatefulWidget {
  const VideoSeekBar(
      {super.key,
      required this.controller,
      required this.onSeek,
      this.figma = FigmaSeekBar.none});
  final Future<void> Function(Duration) onSeek;

  final VideoPlayerController? controller;

  /// 크레캠 플레이어 Figma 모양(1689:5305·1689:5647). [FigmaSeekBar.none]이면
  /// 예전 모양(좌우 여백 12·가운데·분홍) — 커뮤니티 확대 재생은 그대로 둔다.
  final FigmaSeekBar figma;

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
    final figma = widget.figma != FigmaSeekBar.none;
    // Figma 재생바·손잡이는 #D61619(tempAccent), 예전 모양은 분홍(envTempPeak).
    final active = figma ? glass.tempAccent : glass.envTempPeak;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        trackShape: figma ? _FigmaSeekTrackShape(widget.figma) : null,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        // 손잡이는 조작 중에만(사용자 규칙). Figma 가로 Ellipse 31은 16.
        thumbShape: _interacting
            ? RoundSliderThumbShape(enabledThumbRadius: figma ? 8 : 6)
            : SliderComponentShape.noThumb,
        activeTrackColor: active,
        // 연회색 트랙 — #E3E3E3 (outline = VIVA fillLine)
        inactiveTrackColor: glass.outline,
        disabledActiveTrackColor: glass.outline,
        disabledInactiveTrackColor: glass.outline,
        thumbColor: active,
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

/// 크레캠 플레이어 재생바 모양.
enum FigmaSeekBar {
  /// 예전 모양(Material 기본 트랙).
  none,

  /// 세로(1689:5305): 영상 바로 아래에 붙어 화면 좌우 끝까지, 바깥 끝은 각지다.
  portrait,

  /// 가로(1689:5647): 놓인 폭 그대로(조작부 여백 48 안), 양끝 둥근 막대.
  landscape,
}

/// Figma 재생바 — 두께 4, 재생한 부분 끝만 둥글다. Material 트랙의 좌우 여백
/// (overlay 반지름 12)을 없애 놓인 폭을 그대로 쓰고, 세로는 상자 위쪽에 붙인다.
class _FigmaSeekTrackShape extends SliderTrackShape {
  const _FigmaSeekTrackShape(this.kind);
  final FigmaSeekBar kind;

  @override
  Rect getPreferredRect(
      {required RenderBox parentBox,
      Offset offset = Offset.zero,
      required SliderThemeData sliderTheme,
      bool isEnabled = false,
      bool isDiscrete = false}) {
    final h = sliderTheme.trackHeight ?? 4;
    final top = kind == FigmaSeekBar.portrait
        ? offset.dy
        : offset.dy + (parentBox.size.height - h) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, h);
  }

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isEnabled = false,
      bool isDiscrete = false,
      required TextDirection textDirection}) {
    final rect = getPreferredRect(
        parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final end = Radius.circular(rect.height / 2);
    final outer = kind == FigmaSeekBar.portrait ? Radius.zero : end;
    final canvas = context.canvas;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, outer),
        Paint()
          ..color = (isEnabled
              ? sliderTheme.inactiveTrackColor
              : sliderTheme.disabledInactiveTrackColor)!);
    final played = (thumbCenter.dx - rect.left).clamp(0.0, rect.width);
    if (played <= 0) return;
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(rect.left, rect.top, played, rect.height),
            topLeft: outer,
            bottomLeft: outer,
            topRight: end,
            bottomRight: end),
        Paint()
          ..color = (isEnabled
              ? sliderTheme.activeTrackColor
              : sliderTheme.disabledActiveTrackColor)!);
  }
}
