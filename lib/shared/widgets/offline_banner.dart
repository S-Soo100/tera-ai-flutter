import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass_palette.dart';

/// 인터넷 연결이 없을 때 화면 위쪽에 뜨는 작은 안내(UX-05, 2026-10-01).
///
/// 전엔 앱 전체를 불투명하게 덮어(구 `OfflineOverlay`) 보던 정보·쓰던 입력·탭
/// 이동까지 막았다. 이제 안내만 띄우고 아래 화면은 그대로 보고 조작할 수 있다.
/// 서버 작업의 실패는 각 화면이 작업별로 알린다(사육장 제어는 연결 판정·
/// 제어 확인 대기가 그대로 막고, 연결이 돌아와도 명령을 다시 보내지 않는다).
/// 연결 판정은 네트워크 인터페이스 유무라, Wi-Fi는 붙었는데 인터넷이 안 되는
/// 경우엔 이 안내가 뜨지 않고 작업별 오류가 알린다.
///
/// 안내 영역 밖 터치는 아래 화면으로 그대로 간다([onRetry]만 받는다).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.onRetry});

  static const retryKey = Key('offline_banner_retry');

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              key: const Key('offline_banner'),
              color: glass.textPrimary,
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                key: retryKey,
                borderRadius: BorderRadius.circular(24),
                onTap: onRetry,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 18, color: glass.surfaceHeader),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('offline_banner'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: glass.surfaceHeader,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Text('offline_retry'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: glass.surfaceHeader,
                              decoration: TextDecoration.underline,
                              decorationColor: glass.surfaceHeader)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
