import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/glass_page_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/camera_presence.dart';
import '../domain/terra_camera.dart';
import 'my_cage_providers.dart';
import 'widgets/wifi_reconfigure_menu.dart';

enum _CrecamView { grid, list }

/// last_seen 상대 시각 ("방금 전"/"N분 전"/...). 기존 time_* 키 재사용.
String _timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inMinutes < 1) return 'time_just_now'.tr();
  if (diff.inMinutes < 60) {
    return 'time_minutes_ago'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'time_hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
  }
  return 'time_days_ago'.tr(namedArgs: {'n': '${diff.inDays}'});
}

class CrecamScreen extends ConsumerStatefulWidget {
  const CrecamScreen({super.key});

  @override
  ConsumerState<CrecamScreen> createState() => _CrecamScreenState();
}

class _CrecamScreenState extends ConsumerState<CrecamScreen>
    with WidgetsBindingObserver {
  _CrecamView _view = _CrecamView.grid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 백그라운드에서 Realtime 소켓이 죽으면 이벤트가 다시 오지 않으므로,
  // 복귀 시 provider를 재생성(재구독+재조회)해 stale 상태를 끊는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(camerasProvider);
    }
  }

  void _openPairing() {
    context.push('/crecam/cameras/pair');
  }

  Future<void> _refresh() async {
    ref.invalidate(camerasProvider);
    await ref.read(camerasProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(camerasProvider);

    // A안 경량 전환 — 배경·표면 톤만 유리 문법으로. 카메라/페어링 로직 불변.
    return GlassPageShell(
        child: Scaffold(
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
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
        onPressed: _openPairing,
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
            return _EmptyBody(onAdd: _openPairing);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _view == _CrecamView.grid
                ? _CameraGrid(
                    cameras: cameras,
                    onAddTap: _openPairing,
                  )
                : _CameraList(cameras: cameras),
          );
        },
      ),
    ));
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

class _CameraGrid extends StatelessWidget {
  const _CameraGrid({required this.cameras, required this.onAddTap});

  final List<TerraCamera> cameras;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
          return _AddCameraCard(onTap: onAddTap);
        }
        return _CameraGridCard(camera: cameras[index]);
      },
    );
  }
}

class _CameraGridCard extends StatelessWidget {
  const _CameraGridCard({required this.camera});
  final TerraCamera camera;

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
              child: _CameraThumbnail(camera: camera),
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
                          camera.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final scheme = Theme.of(context).colorScheme;
                          final presence = cameraPresence(
                            isOnline: camera.isOnline,
                            lastSeenAt: camera.lastSeenAt,
                            now: DateTime.now(),
                          );
                          final (label, color) = switch (presence) {
                            CameraPresence.online => (
                                camera.lastSeenAt == null
                                    ? 'crecam_camera_online'.tr()
                                    : '${'crecam_camera_online'.tr()} · '
                                        '${_timeAgo(camera.lastSeenAt!)}',
                                scheme.primary,
                              ),
                            CameraPresence.stale => (
                                'crecam_camera_stale'.tr(),
                                scheme.secondary,
                              ),
                            CameraPresence.offline => (
                                'crecam_camera_offline'.tr(),
                                scheme.outline,
                              ),
                          };
                          return Text(
                            label,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ],
                    ),
                  ),
                  WifiReconfigureMenu(
                    icon: Icons.more_horiz,
                    iconSize: 18,
                    onSelected: () => context.push('/crecam/cameras/pair'),
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

// ── 카메라 썸네일 (상태별) ─────────────────────────────────────────────────────
//  온라인 → 최근 클립 썸네일을 포스터로 표시 / 오프라인 → "연결 안 됨" 표시.
class _CameraThumbnail extends ConsumerWidget {
  const _CameraThumbnail({required this.camera});
  final TerraCamera camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!camera.isOnline) {
      return const _ThumbnailState(
        icon: Icons.videocam_off_rounded,
        labelKey: 'crecam_thumbnail_offline',
      );
    }

    // 클립은 cameras.id(UUID)로 연결됨 — camera.cameraId(text) 아님.
    final latest = ref.watch(latestMotionClipProvider(camera.id));
    return latest.when(
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      error: (_, __) => const _ThumbnailState(
        icon: Icons.videocam_rounded,
        labelKey: 'crecam_thumbnail_no_preview',
        online: true,
      ),
      data: (clip) {
        if (clip == null) {
          return const _ThumbnailState(
            icon: Icons.videocam_rounded,
            labelKey: 'crecam_thumbnail_no_preview',
            online: true,
          );
        }
        // 온라인 + 최근 모션 클립 → 썸네일을 포스터로, 좌상단 온라인 점.
        return Stack(
          fit: StackFit.expand,
          children: [
            _MotionClipPoster(clipId: clip.id),
            const Positioned(top: 8, left: 8, child: _OnlineDot()),
          ],
        );
      },
    );
  }
}

/// motion_clips 썸네일 포스터 (terra-api presigned). 없음(404→null)/실패 시
/// 온라인 톤 placeholder 폴백.
class _MotionClipPoster extends ConsumerWidget {
  const _MotionClipPoster({required this.clipId});
  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(motionThumbnailProvider(clipId));
    const noPreview = _ThumbnailState(
      icon: Icons.videocam_rounded,
      labelKey: 'crecam_thumbnail_no_preview',
      online: true,
    );
    return thumbAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SkeletonLoading(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, __, ___) => noPreview,
            )
          : noPreview,
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      error: (_, __) => noPreview,
    );
  }
}

/// 썸네일 placeholder (오프라인 / 미리보기 없음 공용). online이면 녹색 톤.
class _ThumbnailState extends StatelessWidget {
  const _ThumbnailState({
    required this.icon,
    required this.labelKey,
    this.online = false,
  });

  final IconData icon;
  final String labelKey;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = online ? AppTheme.success : scheme.outline;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 30),
          const SizedBox(height: 6),
          Text(
            labelKey.tr(),
            style:
                Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// 온라인 표시용 초록 점.
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppTheme.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
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

class _CameraList extends StatelessWidget {
  const _CameraList({required this.cameras});
  final List<TerraCamera> cameras;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppStyles.spacing8,
        bottom: AppStyles.spacing32 * 3,
      ),
      itemCount: cameras.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final camera = cameras[index];
        return ListTile(
          leading: Icon(
            camera.isOnline ? Icons.videocam : Icons.videocam_off_outlined,
            color: camera.isOnline
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(camera.name),
          subtitle: Text(
            camera.isOnline && camera.lastSeenAt != null
                ? '${camera.model ?? camera.cameraId} · '
                    '${_timeAgo(camera.lastSeenAt!)}'
                : (camera.model ?? camera.cameraId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: WifiReconfigureMenu(
            onSelected: () => context.push('/crecam/cameras/pair'),
          ),
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
