import 'package:flutter/material.dart';

/// 영상 우하단 워터마크(반투명 로고 + 앱 이름). 재생 화면 Stack 오버레이 전용.
/// Stack의 직접 자식으로 배치해야 한다(Positioned).
class VideoWatermark extends StatelessWidget {
  const VideoWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 18),
              const SizedBox(width: 4),
              const Text(
                'Tera AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
