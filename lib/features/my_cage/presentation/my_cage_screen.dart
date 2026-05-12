import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import 'my_cage_providers.dart';
import 'widgets/environment_card.dart';

class MyCageScreen extends ConsumerWidget {
  const MyCageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(camerasProvider);
    final pets = ref.watch(petListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('my_cage_title'.tr()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/my-cage/cameras/add'),
        tooltip: 'my_cage_add_camera'.tr(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const EnvironmentCard(),
          Expanded(
            child: camerasAsync.when(
              loading: () => const _CameraListSkeleton(),
              error: (error, _) => _ErrorBody(
                message: error.toString(),
                onRetry: () => ref.invalidate(camerasProvider),
              ),
              data: (cameras) {
                if (cameras.isEmpty) {
                  return _EmptyBody(
                    onAdd: () => context.push('/my-cage/cameras/add'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(
                    top: AppStyles.spacing8,
                    bottom: AppStyles.spacing32 * 3,
                  ),
                  itemCount: cameras.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final camera = cameras[index];
                    final pet =
                        pets.where((p) => p.id == camera.petId).firstOrNull;
                    return ListTile(
                      leading: Icon(
                        camera.isActive
                            ? Icons.videocam
                            : Icons.videocam_off_outlined,
                        color: camera.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(camera.displayName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${camera.host}:${camera.port}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            pet?.name ?? '개체 미연결',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: pet != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/my-cage/cameras/${camera.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: AppStyles.spacing16),
            Text(
              'my_cage_empty_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text(
              'my_cage_empty_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyles.spacing24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('my_cage_add_camera'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 에러 상태 ─────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppStyles.spacing12),
            Text(
              'error_generic'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyles.spacing16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 로딩 스켈레톤 ─────────────────────────────────────────────────────────────

class _CameraListSkeleton extends StatelessWidget {
  const _CameraListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonListLoading(itemCount: 3);
  }
}
