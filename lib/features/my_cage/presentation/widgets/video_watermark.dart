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
          // 가로형 lockup 한 장으로 심볼+워드마크를 대신한다.
          // 예전엔 정사각 심볼을 18px로 줄이고 옆에 'Tera AI' 텍스트를 붙였는데,
          // 그 크기에선 심볼이 뭉개져 알아볼 수 없었다.
          child: Image.asset(
            'assets/images/logo_wordmark.png',
            height: 16,
          ),
        ),
      ),
    );
  }
}
