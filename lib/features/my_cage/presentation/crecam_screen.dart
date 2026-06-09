import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../domain/camera.dart';
import 'my_cage_providers.dart';

enum _CrecamView { grid, list }

class CrecamScreen extends ConsumerStatefulWidget {
  const CrecamScreen({super.key});

  @override
  ConsumerState<CrecamScreen> createState() => _CrecamScreenState();
}

class _CrecamScreenState extends ConsumerState<CrecamScreen> {
  _CrecamView _view = _CrecamView.grid;

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(camerasProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'crecam_title'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ViewToggle(
              view: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        onPressed: () => context.push('/crecam/cameras/add'),
        tooltip: 'my_cage_add_camera'.tr(),
        child: const Icon(Icons.add),
      ),
      body: camerasAsync.when(
        loading: () => const _CrecamSkeleton(),
        error: (err, _) => _ErrorBody(
          message: err.toString(),
          onRetry: () => ref.invalidate(camerasProvider),
        ),
        data: (cameras) {
          if (cameras.isEmpty) {
            return _EmptyBody(onAdd: () => context.push('/crecam/cameras/add'));
          }
          return _view == _CrecamView.grid
              ? _CameraGrid(cameras: cameras)
              : _CameraList(cameras: cameras);
        },
      ),
    );
  }
}

// ── 그리드/리스트 토글 ─────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final _CrecamView view;
  final ValueChanged<_CrecamView> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
            context: context,
            icon: Icons.grid_view_rounded,
            active: view == _CrecamView.grid,
            onTap: () => onChanged(_CrecamView.grid),
          ),
          _toggleButton(
            context: context,
            icon: Icons.view_list_rounded,
            active: view == _CrecamView.list,
            onTap: () => onChanged(_CrecamView.list),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required BuildContext context,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.surface : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

// ── 그리드 뷰 ──────────────────────────────────────────────────────────────────

class _CameraGrid extends ConsumerWidget {
  const _CameraGrid({required this.cameras});
  final List<Camera> cameras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: cameras.length + 1,
      itemBuilder: (context, index) {
        if (index == cameras.length) {
          return _AddCameraCard(
            onTap: () => context.push('/crecam/cameras/add'),
          );
        }
        return _CameraGridCard(camera: cameras[index]);
      },
    );
  }
}

class _CameraGridCard extends StatelessWidget {
  const _CameraGridCard({required this.camera});
  final Camera camera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/crecam/cameras/${camera.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF263238), Color(0xFF455A64)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('24°C',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                          SizedBox(width: 6),
                          Text('70%',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          camera.isActive
                              ? 'crecam_status_good'.tr()
                              : 'crecam_status_bad'.tr(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: camera.isActive
                                ? const Color(0xFF2E7D32)
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: theme.colorScheme.outline,
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

class _AddCameraCard extends StatelessWidget {
  const _AddCameraCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_outlined,
                size: 36,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'crecam_find_new'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 리스트 뷰 ──────────────────────────────────────────────────────────────────

class _CameraList extends ConsumerWidget {
  const _CameraList({required this.cameras});
  final List<Camera> cameras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);
    return ListView.separated(
      padding: const EdgeInsets.only(
        top: AppStyles.spacing8,
        bottom: AppStyles.spacing32 * 3,
      ),
      itemCount: cameras.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final camera = cameras[index];
        final pet = pets.where((p) => p.id == camera.petId).firstOrNull;
        return ListTile(
          leading: Icon(
            camera.isActive ? Icons.videocam : Icons.videocam_off_outlined,
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
                pet?.name ?? 'crecam_pet_unlinked'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: pet != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/crecam/cameras/${camera.id}'),
        );
      },
    );
  }
}

// ── 빈 상태 / 에러 / 스켈레톤 ─────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 64, color: scheme.outline),
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
                    color: scheme.outline,
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

class _CrecamSkeleton extends StatelessWidget {
  const _CrecamSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const SkeletonCard(lineCount: 2, height: 180),
    );
  }
}
