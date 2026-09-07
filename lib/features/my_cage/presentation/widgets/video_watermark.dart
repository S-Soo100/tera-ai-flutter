import 'package:flutter/material.dart';

/// 영상 우하단 워터마크(반투명 앱 이름). 재생 화면 Stack 오버레이 전용.
/// Stack의 직접 자식으로 배치해야 한다(Positioned).
///
/// 텍스트 렌더인 이유(2026-09-07 A7): 구 이미지(`logo_wordmark.png`)에 옛
/// 브랜드 `terra.ai`가 박혀 있었다. 새 로고 에셋이 나올 때까지 워드마크를
/// 폰트로 그린다 — 저장/공유되는 영상에 옛 브랜드가 찍혀 나가면 안 된다.
/// 브랜드 문자열은 SOT가 Figma 파일명 `vivnanaut`(CLAUDE.md 이름 표)이고
/// 사용자 노출 언어와 무관한 고유명사라 l10n 키를 쓰지 않는다.
class VideoWatermark extends StatelessWidget {
  const VideoWatermark({super.key});

  static const brand = 'vivnanaut';

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: Text(
            brand,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}
