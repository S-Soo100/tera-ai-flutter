import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';

/// 인터넷 연결이 없을 때 앱 전체를 덮는 오버레이.
/// [onRetry]는 연결 상태를 재확인(provider 재구독)한다.
class OfflineOverlay extends StatelessWidget {
  const OfflineOverlay({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppStyles.spacing24),
              Text(
                'offline_title'.tr(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppStyles.spacing8),
              Text(
                'offline_subtitle'.tr(),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppStyles.spacing24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text('offline_retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
