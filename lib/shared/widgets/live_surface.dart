import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';

/// 영상이 놓이는 **어두운 관측 면**. 디자인 시스템 `Components / LiveSurface`.
///
/// 라이트/다크 무관하게 항상 어둡다 — 밝은 회색으로 두면 연결 전 화면이 죽은
/// 공백이 된다(실기기에서 상단 40%가 그랬다).
///
/// **오버레이 슬롯 3곳을 고정한다.** 화면마다 다른 자리에 두면 사용자가 매번
/// 다시 찾아야 한다.
///
/// ```
/// ┌──────────────────────────────┐
/// │ [status]            [corner] │  ← 상태 배지 / 시각
/// │                              │
/// │           child              │  ← 영상 또는 안내
/// │                              │
/// │           [footer]           │  ← 페이지 인디케이터
/// └──────────────────────────────┘
/// ```
class LiveSurface extends StatelessWidget {
  const LiveSurface({
    super.key,
    required this.child,
    this.status,
    this.corner,
    this.footer,
    this.aspectRatio = 16 / 9,
  });

  /// 영상 또는 안내 화면.
  final Widget child;

  /// 좌상단 — 상태 배지. **연결 상태를 말하는 유일한 자리**다.
  final Widget? status;

  /// 우상단 — 현재 시각 등.
  final Widget? corner;

  /// 하단 중앙 — 페이지 인디케이터. 면 **안에** 둔다. 밖으로 빼면 라이브와
  /// 제어 바 사이에 떠 있는 조각이 된다.
  final Widget? footer;

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (status != null)
              Positioned(
                left: AppStyles.spacing8,
                top: AppStyles.spacing8,
                child: status!,
              ),
            if (corner != null)
              Positioned(
                right: AppStyles.spacing8,
                top: AppStyles.spacing8,
                child: corner!,
              ),
            if (footer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppStyles.spacing8,
                child: Center(child: footer!),
              ),
          ],
        ),
      ),
    );
  }
}

/// 라이브 면 위 안내 화면 — 연결 실패·오프라인.
///
/// **빈 화면을 두지 않는다.** 무엇이 잘못됐고 무엇을 할 수 있는지 말한다.
class LiveSurfaceNotice extends StatelessWidget {
  const LiveSurfaceNotice({
    super.key,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppStyles.spacing12),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing16),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
