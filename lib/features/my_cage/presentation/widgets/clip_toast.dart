import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';

/// Figma 1081:6803 / 6895 / 1106:3584 토스트 — 흰 60 r8(폭은 내용: 24 +
/// 28 원형 체크(#3C3C3C) + 8 + 18/500 #1E1E1E + 24 → 북마크 256, 다운로드
/// 215). 세로는 하단 212(y580), 가로는 하단 84(y249)에 가운데.
///
/// Overlay에 직접 얹어 플레이어의 Scaffold/스낵바 위치와 무관하게 원본
/// 좌표를 지킨다. 같은 화면에서 연달아 부르면 이전 토스트를 먼저 걷는다.
OverlayEntry? _current;
Timer? _timer;

/// 플레이어 밖 목록 화면의 토스트 높이 — Figma 영상 선택(1497:11720 외)·
/// 차단한 사용자(1142:9422) 모두 하단 96(y696). 플레이어는 조작 줄 위 212.
const double kScreenToastBottom = 96;

void showClipToast(BuildContext context,
    {required String text,
    String icon = 'redesign_v2/check',
    Duration duration = const Duration(seconds: 2),
    double? bottom}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  showClipToastOn(overlay,
      text: text, icon: icon, duration: duration, bottom: bottom);
}

/// [OverlayState]를 직접 받는 버전 — 루트 Navigator 자신의 context처럼 위로
/// Overlay가 없는 곳에서 쓴다. 분무 완료 토스트가 그 context로 Overlay를 찾다
/// null이라 한 번도 뜨지 않았다(2026-09-25). `Navigator.overlay`를 넘긴다.
void showClipToastOn(OverlayState overlay,
    {required String text,
    String icon = 'redesign_v2/check',
    Duration duration = const Duration(seconds: 2),
    double? bottom}) {
  if (!overlay.mounted) return;
  _timer?.cancel();
  _current?.remove();
  final entry = OverlayEntry(
      builder: (context) => _ClipToast(text: text, icon: icon, bottom: bottom));
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}

/// 막아 둔 기능을 눌렀을 때 — Figma Home 시안의 `!` 토스트 "현재는 사용할 수
/// 없는 기능입니다". 회색 칸이 탭에 무반응이면 고장으로 읽힌다.
void showFeatureUnavailableToast(BuildContext context) => showClipToast(context,
    text: 'feature_unavailable_toast'.tr(), icon: 'redesign_v2/priority_high');

/// 테스트·화면 이탈용 즉시 제거.
void dismissClipToast() {
  _timer?.cancel();
  _timer = null;
  _current?.remove();
  _current = null;
}

class _ClipToast extends StatelessWidget {
  const _ClipToast({required this.text, required this.icon, this.bottom});
  final String text;
  final String icon;

  /// 세로 화면 하단 거리. null이면 플레이어 기준 212.
  final double? bottom;

  static const toastKey = Key('clip_toast');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    return Positioned(
      left: 0,
      right: 0,
      bottom: landscape ? 84 : bottom ?? 212,
      child: IgnorePointer(
        child: Center(
          child: Material(
            key: toastKey,
            color: glass.surfaceHeader,
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: glass.textSecondary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: FigmaIcon.tinted(icon,
                        size: 16, color: glass.surfaceHeader),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.36,
                            color: glass.textPrimary)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
