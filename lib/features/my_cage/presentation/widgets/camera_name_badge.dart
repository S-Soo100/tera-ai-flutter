import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 라이브 면 좌하단 카메라 이름 배지 — 확장 버튼과 같은 스크림 캡슐.
///
/// 카메라 탭(`CameraLiveArea`)에서 시작해 홈(`TopFixedArea`)에도 달았다
/// (2026-09-08 사용성 리뷰 7번 — 점 인디케이터만으론 어느 캠인지 알 수 없다).
class CameraNameBadge extends StatelessWidget {
  const CameraNameBadge({super.key, required this.name});

  final String name;

  static const badgeKey = Key('crecam_live_camera_name');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: badgeKey,
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.liveScrim,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 12 * -0.02,
          color: AppTheme.liveOnDark,
        ),
      ),
    );
  }
}
