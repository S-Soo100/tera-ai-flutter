import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/cage_activity.dart';
import '../domain/clip.dart';
import '../domain/clip_action.dart';
import 'activity_format.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';
import 'widgets/clip_card.dart';
import 'widgets/hourly_activity_chart.dart';
import 'widgets/motion_clip_card.dart';
import 'widgets/webrtc_live_view.dart';
import 'widgets/wifi_reconfigure_menu.dart';

// ── 검증용 클립 설정 ─────────────────────────────────────────────────────────
// 현재 camera_clips RLS("User reads own clips" = 본인 클립만)로 직결 조회가
// 0건이라 보류(false). RLS에 labeler SELECT 정책을 추가하면 true로 재활성 가능.
const bool kShowVerifyClip = false;

/// 실제 R2 클립이 71개 업로드된 검증용 카메라 ID.
const String kVerifyCameraId = '3a6cffbf-be83-4c77-9fa7-4fcc517c74a6';

/// 검증용 카메라의 클립 목록 (최신순, 최대 100개).
final _verifyClipsProvider =
    FutureProvider.autoDispose<List<Clip>>((ref) async {
  final repo = ref.watch(clipRepositoryProvider);
  final page = await repo.listPage(cameraId: kVerifyCameraId, limit: 100);
  return page.items;
});
// ────────────────────────────────────────────────────────────────────────────

/// 카메라가 속한 사육세트(enclosure)의 사육장 모듈 device id.
/// 카메라 미배정이거나 같은 사육세트에 사육장 모듈이 없으면 null → 뱃지 —/—
/// (전역 device의 엉뚱한 값을 보여주지 않는다 — 사육 데이터 정확성).
final _envDeviceIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, cameraId) async {
  final camera = await ref.watch(cameraProvider(cameraId).future);
  final enclosureId = camera?.enclosureId;
  if (enclosureId == null) return null;
  final devices = await ref.watch(deviceListProvider.future);
  final matched = devices.where((d) => d.enclosureId == enclosureId).toList();
  return matched.isEmpty ? null : matched.first.id;
});
// ────────────────────────────────────────────────────────────────────────────

class CameraDetailScreen extends ConsumerStatefulWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  ActivityRange _activityRange = ActivityRange.today;

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
            cam?.name ?? widget.cameraId,
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
          WifiReconfigureMenu(
            onSelected: () => context.push('/crecam/cameras/pair'),
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
              cameraId: widget.cameraId,
              range: _activityRange,
              onRangeChanged: (r) => setState(() => _activityRange = r),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VideoLogSection(cameraId: widget.cameraId),
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
    final timeText = DateFormat('yyyy.MM.dd HH:mm:ss').format(now.toLocal());

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          // 라이브 스트림 (WebRTC)
          Positioned.fill(
            child: WebRtcLiveView(cameraUuid: cameraId),
          ),
          // 상단 우측: 온도 / 습도 배지 (실데이터)
          Positioned(
            top: 12,
            right: 12,
            child: _LiveEnvBadge(cameraId: cameraId),
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

/// 실데이터 환경 배지 — 카메라가 속한 사육세트의 사육장 모듈 telemetry를 watch.
class _LiveEnvBadge extends ConsumerWidget {
  const _LiveEnvBadge({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceIdAsync = ref.watch(_envDeviceIdProvider(cameraId));

    String tempText = '—°';
    String humText = '—%';

    final deviceId = deviceIdAsync.valueOrNull;
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

class _SimpleActivityCard extends ConsumerWidget {
  const _SimpleActivityCard({
    required this.cameraId,
    required this.range,
    required this.onRangeChanged,
  });

  final String cameraId;
  final ActivityRange range;
  final ValueChanged<ActivityRange> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync =
        ref.watch(motionActivityProvider((cameraId: cameraId, range: range)));
    // 진행 중인 '오늘'은 아직 도래하지 않은 시각을 미래로 구분(무활동과 혼동 방지).
    // '어제'(완결일)는 24칸 모두 실제 데이터라 null.
    final activeHours = range == ActivityRange.today
        ? (DateTime.now()
                    .difference(activityRangeBounds(range, DateTime.now()).start)
                    .inHours +
                1)
            .clamp(1, 24)
        : null;
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
          activityAsync.when(
            loading: () => _statsRow(loading: true),
            error: (_, __) => InlineRetry(
              onRetry: () => ref.invalidate(
                  motionActivityProvider((cameraId: cameraId, range: range))),
            ),
            data: (seconds) =>
                _statsRow(motion: formatMotionDuration(seconds)),
          ),
          const SizedBox(height: 18),
          Text(
            'crecam_detail_activity_pattern'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ref
              .watch(hourlyActivityProvider((cameraId: cameraId, range: range)))
              .when(
                loading: () =>
                    const SkeletonLoading(width: double.infinity, height: 92),
                error: (_, __) => SizedBox(
                  height: 92,
                  child: InlineRetry(
                    onRetry: () => ref.invalidate(hourlyActivityProvider(
                        (cameraId: cameraId, range: range))),
                  ),
                ),
                data: (hourly) => HourlyActivityChart(
                  hourlySeconds: hourly,
                  dayStartHour: kCageDayStartHour,
                  activeHours: activeHours,
                ),
              ),
        ],
      ),
    );
  }

  Widget _statsRow({String motion = '', bool loading = false}) {
    return _ActivityStatBox(
      label: 'crecam_detail_stat_motion'.tr(),
      value: motion,
      loading: loading,
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.range, required this.onChanged});

  final ActivityRange range;
  final ValueChanged<ActivityRange> onChanged;

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
              range == ActivityRange.yesterday, ActivityRange.yesterday),
          _toggleChip(context, 'clip_date_today'.tr(),
              range == ActivityRange.today, ActivityRange.today),
        ],
      ),
    );
  }

  Widget _toggleChip(
      BuildContext context, String label, bool selected, ActivityRange r) {
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
    this.loading = false,
  });

  final String label;
  final String value;
  final bool loading;

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
          loading
              ? const SkeletonLoading(width: 44, height: 18)
              : Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
        ],
      ),
    );
  }
}

// ── 비디오 기록 섹션 ────────────────────────────────────────────────────────

class _VideoLogSection extends ConsumerWidget {
  const _VideoLogSection({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(clipDayFilterProvider);
    final actionFilter = ref.watch(clipActionFilterProvider);
    final clipsAsync =
        ref.watch(motionClipsProvider((cameraId: cameraId, day: day)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'crecam_detail_video_log'.tr(),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _FilterBar(cameraId: cameraId),
        const SizedBox(height: 12),
        if (kShowVerifyClip) ...[
          _VerifyClipsSection(ref: ref),
          const SizedBox(height: 12),
        ],
        clipsAsync.when(
          loading: () => _buildSkeletonList(),
          error: (e, _) => _buildError(context, ref),
          data: (clips) {
            // 분류 클라 필터: null=전체, 'unlabeled'=미분류(action null), 그 외=action 일치.
            final filtered = actionFilter == null
                ? clips
                : clips.where((c) => actionFilter == 'unlabeled'
                    ? c.action == null
                    : c.action == actionFilter).toList();
            if (filtered.isEmpty) return _buildEmptyAction(context);
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: filtered
                  .map((c) => MotionClipCard(
                        clip: c,
                        onTap: () =>
                            context.push('/crecam/motion-clips/${c.id}'),
                      ))
                  .toList(),
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

  Widget _buildEmptyAction(BuildContext context) {
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

  Widget _buildError(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'error_generic'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          InlineRetry(
            onRetry: () => ref.invalidate(motionClipsProvider(
                (cameraId: cameraId, day: ref.read(clipDayFilterProvider)))),
          ),
        ],
      ),
    );
  }
}

/// 비디오 기록 필터 바 — 분류 드롭다운 + 날짜 선택.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.cameraId});
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(clipDayFilterProvider);
    final actionFilter = ref.watch(clipActionFilterProvider);

    final dayLabel = day == null
        ? 'clip_filter_date_all'.tr()
        : DateFormat('yyyy.MM.dd').format(day);

    return Row(
      children: [
        // 분류 드롭다운
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: actionFilter,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text('clip_action_all'.tr())),
              DropdownMenuItem(
                  value: 'unlabeled',
                  child: Text('clip_action_unlabeled'.tr())),
              ...kClipActions.map((a) => DropdownMenuItem(
                  value: a, child: Text(clipActionKey(a).tr()))),
            ],
            onChanged: (v) =>
                ref.read(clipActionFilterProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        // 날짜 선택
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(dayLabel),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ref.read(clipDayFilterProvider.notifier).state = picked;
            }
          },
        ),
        if (day != null)
          IconButton(
            tooltip: 'clip_filter_date_all'.tr(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                ref.read(clipDayFilterProvider.notifier).state = null,
          ),
      ],
    );
  }
}

// ── 검증용 클립 섹션 (실제 R2 클립 그리드) ───────────────────────────────────

class _VerifyClipsSection extends StatelessWidget {
  const _VerifyClipsSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(_verifyClipsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'camera_detail_verify_clip_section'.tr()),
        clipsAsync.when(
          loading: () => Column(
            children: List.generate(
              2,
              (i) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonCard(lineCount: 2, height: 80),
              ),
            ),
          ),
          error: (_, __) {
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
          },
          data: (clips) {
            if (clips.isEmpty) {
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
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: clips
                  .map(
                    (c) => ClipCard(
                      clip: c,
                      onTap: () => context.push('/crecam/clips/${c.id}'),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
