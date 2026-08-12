import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/domain/time_ago.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../home_control_providers.dart';

/// 기기 연결이 끊겼을 때 제어 서브탭 맨 위에 뜨는 안내.
///
/// **없으면 퀵 제어 4종이 이유 없이 회색으로 죽어 있다.** 실제로 기기가 8시간
/// 오프라인이던 날 화면에는 아무 설명이 없었고, 처음 보는 사람에게는 고장난
/// 앱으로 읽혔다. 차트와 현재값도 같이 멈춰 있으므로 그 이유까지 여기서 밝힌다.
///
/// 온라인이면 아무것도 그리지 않는다 — 정상일 때 자리를 먹는 배너는 곧 안 읽힌다.
class DeviceOfflineNotice extends ConsumerWidget {
  const DeviceOfflineNotice({super.key});

  static const noticeKey = Key('device_offline_notice');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();
    if (ref.watch(moduleOnlineProvider(deviceId))) {
      return const SizedBox.shrink();
    }

    final device = ref.watch(currentDeviceProvider).valueOrNull;
    // 1분 틱에 맞춰 다시 그린다. 안 그러면 "8시간 전"이 그대로 멈춘다.
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
    final lastSeen = device?.lastSeenAt;

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        0,
      ),
      child: Container(
        key: noticeKey,
        padding: const EdgeInsets.all(AppStyles.spacing12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 18, color: AppTheme.warning),
            const SizedBox(width: AppStyles.spacing8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_device_offline_title'.tr(),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastSeen == null
                        ? 'home_device_offline_body_unknown'.tr()
                        : 'home_device_offline_body'
                            .tr(args: [timeAgo(lastSeen, now: now)]),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
