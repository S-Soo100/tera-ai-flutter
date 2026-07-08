import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 녹화 영상 좌상단 일시 오버레이(CCTV 스타일). 재생 위치에 맞춰 초 단위로 틱한다.
/// 표시값 = [startedAt](녹화 시작) + 현재 재생 위치 = 지금 보는 프레임의 실제 시각.
class VideoTimestampOverlay extends StatefulWidget {
  const VideoTimestampOverlay({
    super.key,
    required this.controller,
    required this.startedAt,
  });

  final VideoPlayerController controller;
  final DateTime startedAt;

  @override
  State<VideoTimestampOverlay> createState() => _VideoTimestampOverlayState();
}

class _VideoTimestampOverlayState extends State<VideoTimestampOverlay> {
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

  @override
  Widget build(BuildContext context) {
    final shown =
        widget.startedAt.toLocal().add(widget.controller.value.position);
    final label = DateFormat('yyyy.MM.dd HH:mm:ss').format(shown);
    return Positioned(
      left: 8,
      top: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}
