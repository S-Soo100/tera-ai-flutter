import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 사육장·카메라 공용 "Wi-Fi 재설정" 오버플로 메뉴.
///
/// 기기가 위치를 옮겨 공유기가 바뀌면 이 메뉴로 기존 페어링 화면에 진입해
/// Wi-Fi를 다시 붙인다. 앱은 BLE로 기기를 특정하지 않으므로 라우트만 다르다.
///
/// 기본 [PopupMenuButton] 최소 탭 타겟(48px)을 유지해, 좁은 카드 안에서도
/// 아이콘을 살짝 빗나간 탭이 부모 제스처(카드 InkWell → 상세 이동)로 새는 것을
/// 막는다.
class WifiReconfigureMenu extends StatelessWidget {
  const WifiReconfigureMenu({
    super.key,
    required this.onSelected,
    this.icon = Icons.more_vert,
    this.iconSize = 24,
  });

  /// 메뉴 항목 선택 시 실행(보통 페어링 라우트로 push).
  final VoidCallback onSelected;

  /// 트리거 아이콘. 카드에서는 `more_horiz`, AppBar에서는 기본 `more_vert`.
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<void>(
      icon: Icon(icon, size: iconSize, color: theme.colorScheme.outline),
      tooltip: 'wifi_reconfigure'.tr(),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: onSelected,
          child: Row(
            children: [
              const Icon(Icons.wifi_rounded, size: 18),
              const SizedBox(width: 8),
              Text('wifi_reconfigure'.tr()),
            ],
          ),
        ),
      ],
    );
  }
}
