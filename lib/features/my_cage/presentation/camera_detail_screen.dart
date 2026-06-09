import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';
import 'widgets/live_mjpeg_view.dart';

enum _ActivityRange { yesterday, today }

enum _VideoFilter { highlight, motion, all }

class CameraDetailScreen extends ConsumerStatefulWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<CameraDetailScreen> createState() =>
      _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  _ActivityRange _activityRange = _ActivityRange.today;
  _VideoFilter _videoFilter = _VideoFilter.highlight;

  // ── 카메라 삭제 ────────────────────────────────────────────────────────────

  Future<void> _deleteCamera(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('camera_delete'.tr()),
        content: Text('camera_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('camera_delete_confirm_no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text('camera_delete_confirm_yes'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(cameraRepositoryProvider).delete(widget.cameraId);
      if (!mounted) return;
      ref.invalidate(camerasProvider);
      router.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${'error_generic'.tr()}: ${e.toString()}'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraAsync = ref.watch(cameraProvider(widget.cameraId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        title: cameraAsync.when(
          data: (cam) => Text(
            cam?.displayName ?? widget.cameraId,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Text(widget.cameraId),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _deleteCamera(context),
            tooltip: 'camera_delete'.tr(),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _LiveSection(cameraId: widget.cameraId),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SimpleActivityCard(
              range: _activityRange,
              onRangeChanged: (r) => setState(() => _activityRange = r),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VideoLogSection(
              cameraId: widget.cameraId,
              filter: _videoFilter,
              onFilterChanged: (f) => setState(() => _videoFilter = f),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── 라이브 영역 (오버레이 포함) ──────────────────────────────────────────────

class _LiveSection extends StatelessWidget {
  const _LiveSection({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeText =
        DateFormat('yyyy.MM.dd HH:mm:ss').format(now.toLocal());

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          // 라이브 스트림
          Positioned.fill(
            child: LiveMjpegView(
              url: AppConstants.tempLiveStreamUrl,
              username: AppConstants.tempLiveStreamUser,
              password: AppConstants.tempLiveStreamPass,
            ),
          ),
          // 상단 우측: 온도 / 습도 배지 (실데이터)
          const Positioned(
            top: 12,
            right: 12,
            child: _LiveEnvBadge(),
          ),
          // 하단 우측: 타임스탬프 + Live
          Positioned(
            right: 12,
            bottom: 12,
            child: Text(
              '$timeText (${'crecam_detail_live_label'.tr()})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 실데이터 환경 배지 — Supabase telemetryStreamProvider를 watch.
class _LiveEnvBadge extends ConsumerWidget {
  const _LiveEnvBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(currentDeviceProvider);

    String tempText = '—°';
    String humText = '—%';

    final deviceId = deviceAsync.valueOrNull?.id;
    if (deviceId != null) {
      final telemetryAsync = ref.watch(telemetryStreamProvider(deviceId));
      if (telemetryAsync.hasValue && telemetryAsync.value != null) {
        final t = telemetryAsync.value!;
        if (t.aOk && t.tA != null) {
          tempText = '${t.tA!.toStringAsFixed(1)}°';
          humText = t.hA != null ? '${t.hA!.toStringAsFixed(0)}%' : '—%';
        }
      }
    }

    return _EnvBadgeView(temp: tempText, humidity: humText);
  }
}

class _EnvBadgeView extends StatelessWidget {
  const _EnvBadgeView({required this.temp, required this.humidity});

  final String temp;
  final String humidity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.thermostat, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            temp,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.water_drop_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            humidity,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 간단 활동량 카드 ─────────────────────────────────────────────────────────

class _SimpleActivityCard extends StatelessWidget {
  const _SimpleActivityCard({
    required this.range,
    required this.onRangeChanged,
  });

  final _ActivityRange range;
  final ValueChanged<_ActivityRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'crecam_detail_activity_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _RangeToggle(range: range, onChanged: onRangeChanged),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'crecam_detail_activity_baseline'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActivityStatBox(
                  label: 'crecam_detail_stat_motion'.tr(),
                  value: range == _ActivityRange.today ? '2h 15m' : '1h 48m',
                  valueColor: const Color(0xFF222222),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActivityStatBox(
                  label: 'crecam_detail_stat_drinking'.tr(),
                  value: 'crecam_detail_count_times'
                      .tr(namedArgs: {'n': range == _ActivityRange.today ? '3' : '2'}),
                  valueColor: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActivityStatBox(
                  label: 'crecam_detail_stat_feeding'.tr(),
                  value: 'crecam_detail_count_times'
                      .tr(namedArgs: {'n': range == _ActivityRange.today ? '1' : '2'}),
                  valueColor: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.range, required this.onChanged});

  final _ActivityRange range;
  final ValueChanged<_ActivityRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip(context, 'clip_date_yesterday'.tr(),
              range == _ActivityRange.yesterday, _ActivityRange.yesterday),
          _toggleChip(context, 'clip_date_today'.tr(),
              range == _ActivityRange.today, _ActivityRange.today),
        ],
      ),
    );
  }

  Widget _toggleChip(
      BuildContext context, String label, bool selected, _ActivityRange r) {
    return GestureDetector(
      onTap: () => onChanged(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActivityStatBox extends StatelessWidget {
  const _ActivityStatBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 비디오 기록 섹션 ────────────────────────────────────────────────────────

class _VideoLogSection extends ConsumerWidget {
  const _VideoLogSection({
    required this.cameraId,
    required this.filter,
    required this.onFilterChanged,
  });

  final String cameraId;
  final _VideoFilter filter;
  final ValueChanged<_VideoFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latestAsync = ref.watch(latestClipTimeProvider(cameraId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'crecam_detail_video_log'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _FilterChips(filter: filter, onChanged: onFilterChanged),
        const SizedBox(height: 14),
        latestAsync.when(
          loading: () => _buildSkeletonList(),
          error: (e, _) => _buildError(context),
          data: (latest) {
            if (latest == null) {
              return _buildEmpty(context);
            }
            return _ClipListByDay(
              cameraId: cameraId,
              date: DateTime(latest.year, latest.month, latest.day),
              filter: filter,
              onFilterChanged: onFilterChanged,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        3,
        (i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(lineCount: 2, height: 80),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'camera_detail_clips_empty'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'error_generic'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filter, required this.onChanged});

  final _VideoFilter filter;
  final ValueChanged<_VideoFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'crecam_detail_filter_highlight'.tr(),
            filter == _VideoFilter.highlight, _VideoFilter.highlight),
        const SizedBox(width: 8),
        _chip(context, 'crecam_detail_filter_motion'.tr(),
            filter == _VideoFilter.motion, _VideoFilter.motion),
        const SizedBox(width: 8),
        _chip(context, 'crecam_detail_filter_all'.tr(),
            filter == _VideoFilter.all, _VideoFilter.all),
      ],
    );
  }

  Widget _chip(
      BuildContext context, String label, bool selected, _VideoFilter f) {
    const blackColor = Color(0xFF222222);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? blackColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? blackColor
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── 클립 리스트 (해당 날짜 hourCounts → 클립 평탄화) ─────────────────────────

class _ClipListByDay extends ConsumerWidget {
  const _ClipListByDay({
    required this.cameraId,
    required this.date,
    required this.filter,
    required this.onFilterChanged,
  });

  final String cameraId;
  final DateTime date;
  final _VideoFilter filter;
  final ValueChanged<_VideoFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hourCountsAsync = ref.watch(hourCountsProvider((
      cameraId: cameraId,
      date: date,
    )));

    return hourCountsAsync.when(
      loading: () => Column(
        children: List.generate(
          3,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonCard(lineCount: 2, height: 80),
          ),
        ),
      ),
      error: (e, _) => _buildErrorCard(context),
      data: (counts) {
        final hoursWithClips = counts.entries
            .where((e) => e.value > 0)
            .map((e) => e.key)
            .toList()
          ..sort((a, b) => b.compareTo(a));

        if (hoursWithClips.isEmpty) {
          return _buildEmptyCard(context);
        }

        return Column(
          children: hoursWithClips
              .map((h) => _HourClips(
                    cameraId: cameraId,
                    date: date,
                    hour: h,
                    filter: filter,
                    onFilterChanged: onFilterChanged,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'camera_detail_clips_empty'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'error_generic'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _HourClips extends ConsumerWidget {
  const _HourClips({
    required this.cameraId,
    required this.date,
    required this.hour,
    required this.filter,
    required this.onFilterChanged,
  });

  final String cameraId;
  final DateTime date;
  final int hour;
  final _VideoFilter filter;
  final ValueChanged<_VideoFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipsAsync = ref.watch(clipsForHourProvider((
      cameraId: cameraId,
      date: date,
      hour: hour,
    )));

    return clipsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clips) {
        final filtered = _applyFilter(clips);
        if (filtered.isEmpty) return const SizedBox.shrink();
        return Column(
          children: filtered
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ClipRow(clip: c),
                  ))
              .toList(),
        );
      },
    );
  }

  List<Clip> _applyFilter(List<Clip> clips) {
    switch (filter) {
      case _VideoFilter.highlight:
        return clips.where((c) => c.hasMotion).toList();
      case _VideoFilter.motion:
        return clips.where((c) => c.hasMotion).toList();
      case _VideoFilter.all:
        return clips;
    }
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.clip});

  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = DateFormat('hh:mm a').format(clip.startedAt.toLocal());

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/crecam/clips/${clip.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 썸네일
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 28,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 12),
            // 본문
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'crecam_detail_stat_drinking'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'crecam_detail_behavior_drinking'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
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
