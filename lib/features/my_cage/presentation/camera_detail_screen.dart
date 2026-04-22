import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'my_cage_providers.dart';
import 'widgets/clip_filter_bar.dart';
import 'widgets/clip_grid_card.dart';
import 'widgets/hour_chip_row.dart';

class CameraDetailScreen extends ConsumerStatefulWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<CameraDetailScreen> createState() =>
      _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  DateTime? _selectedDate; // 로컬 기준 y-m-d, 시분초=0
  int? _selectedHour; // 0~23
  bool _onlyMotion = true;
  bool _didInitialJump = false;

  // ── 초기 점프 ──────────────────────────────────────────────────────────────

  void _jumpToLatest(DateTime? latest) {
    if (_didInitialJump) return;
    final target = (latest ?? DateTime.now()).toLocal();
    if (!mounted) return;
    setState(() {
      _selectedDate = DateTime(target.year, target.month, target.day);
      _selectedHour = target.hour;
      _didInitialJump = true;
    });
  }

  // ── hourCounts 변경 시 가장 가까운 유효 hour로 자동 이동 ──────────────────

  void _maybeShiftHour(Map<int, int> counts) {
    if (_selectedHour == null) return;
    if ((counts[_selectedHour] ?? 0) > 0) return;
    int? nearest;
    int minDist = 99;
    for (final entry in counts.entries) {
      if (entry.value == 0) continue;
      final d = (entry.key - _selectedHour!).abs();
      if (d < minDist) {
        minDist = d;
        nearest = entry.key;
      }
    }
    if (nearest != null && mounted) {
      setState(() => _selectedHour = nearest);
    }
  }

  // ── 필터 토글 ──────────────────────────────────────────────────────────────

  void _setMotionOnly(bool value) {
    if (_onlyMotion == value) return;
    setState(() => _onlyMotion = value);
  }

  // ── 달력 선택 ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      helpText: 'clip_date_picker_title'.tr(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      // hour는 유지. hourCounts listen이 자동 이동 처리.
    });
  }

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

    // 초기 점프: latestClipTimeProvider 구독
    ref.listen<AsyncValue<DateTime?>>(
      latestClipTimeProvider(widget.cameraId),
      (_, next) => next.whenData(_jumpToLatest),
    );
    // cache hit 대비: 첫 build에서도 시도
    ref
        .read(latestClipTimeProvider(widget.cameraId))
        .whenData(_jumpToLatest);

    // selectedDate/Hour이 결정된 이후에만 hourCounts 구독
    if (_selectedDate != null && _selectedHour != null) {
      ref.listen<AsyncValue<Map<int, int>>>(
        hourCountsProvider((
          cameraId: widget.cameraId,
          date: _selectedDate!,
          onlyMotion: _onlyMotion,
        )),
        (_, next) => next.whenData(_maybeShiftHour),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: cameraAsync.when(
          data: (cam) => Text(cam?.displayName ?? widget.cameraId),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Text(widget.cameraId),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDate,
            tooltip: 'clip_date_picker_title'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteCamera(context),
            tooltip: 'camera_delete'.tr(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 카메라 정보 카드
          _CameraInfoCard(cameraId: widget.cameraId),

          // 필터 칩 바
          ClipFilterBar(
            motionOnly: _onlyMotion,
            onChanged: _setMotionOnly,
          ),

          // 날짜+시간 선택 영역 + 그리드
          Expanded(
            child: _selectedDate == null || _selectedHour == null
                ? _buildInitialLoading()
                : _buildDateTimeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialLoading() {
    return Padding(
      padding: AppStyles.pagePadding,
      child: Column(
        children: List.generate(
          2,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: AppStyles.spacing12),
            child: SkeletonCard(lineCount: 3, height: 100),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeContent() {
    final date = _selectedDate!;
    final hour = _selectedHour!;
    final hourCountsKey = (
      cameraId: widget.cameraId,
      date: date,
      onlyMotion: _onlyMotion,
    );
    final clipsKey = (
      cameraId: widget.cameraId,
      date: date,
      hour: hour,
      onlyMotion: _onlyMotion,
    );

    final hourCountsAsync = ref.watch(hourCountsProvider(hourCountsKey));
    final clipsAsync = ref.watch(clipsForHourProvider(clipsKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 선택된 날짜 텍스트
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyles.spacing16,
            vertical: AppStyles.spacing8,
          ),
          child: Text(
            DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),

        // HourChipRow
        hourCountsAsync.when(
          data: (counts) => HourChipRow(
            selectedHour: hour,
            counts: counts,
            onChanged: (h) => setState(() => _selectedHour = h),
          ),
          loading: () => const SizedBox(
            height: 64,
            child: Center(
              child: SkeletonCard(lineCount: 1, height: 48),
            ),
          ),
          error: (_, __) => const SizedBox(height: 64),
        ),

        const Divider(height: 1),

        // 그리드 영역
        Expanded(
          child: clipsAsync.when(
            data: (clips) => clips.isEmpty
                ? _buildEmptyDateState(hourCountsAsync)
                : GridView.builder(
                    padding: const EdgeInsets.all(AppStyles.spacing8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 16 / 9,
                    ),
                    itemCount: clips.length,
                    itemBuilder: (context, index) {
                      final clip = clips[index];
                      return ClipGridCard(
                        clip: clip,
                        onTap: () =>
                            context.push('/my-cage/clips/${clip.id}'),
                      );
                    },
                  ),
            loading: () => _buildGridSkeleton(),
            error: (e, _) => _buildError(e),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDateState(AsyncValue<Map<int, int>> hourCountsAsync) {
    // 해당 날짜 전체 0건인지 확인
    final isEntireDateEmpty = hourCountsAsync.whenOrNull(
          data: (counts) => counts.values.every((v) => v == 0),
        ) ??
        false;

    if (isEntireDateEmpty) {
      return Center(
        child: Padding(
          padding: AppStyles.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppStyles.spacing12),
              Text(
                'my_cage_no_clips_this_date'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppStyles.spacing16),
              FilledButton.tonal(
                onPressed: _pickDate,
                child: Text('my_cage_select_another_date'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // 해당 시간만 0건 (다른 시간에는 데이터 있음)
    return Center(
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text(
              'clip_empty_date'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppStyles.spacing8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: AppStyles.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text('error_generic'.tr()),
            const SizedBox(height: AppStyles.spacing8),
            OutlinedButton(
              onPressed: () => setState(() {}),
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 카메라 정보 카드 (별도 위젯으로 분리해 rebuild 격리) ──────────────────────

class _CameraInfoCard extends ConsumerWidget {
  const _CameraInfoCard({required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraAsync = ref.watch(cameraProvider(cameraId));

    return Padding(
      padding: AppStyles.pagePadding,
      child: cameraAsync.when(
        loading: () => const SkeletonCard(lineCount: 4, height: 120),
        error: (e, _) => Text(e.toString()),
        data: (camera) {
          if (camera == null) {
            return Center(child: Text('error_generic'.tr()));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'camera_detail_info'.tr()),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: Text('${camera.host}:${camera.port}'),
                      subtitle: Text('rtsp:///${camera.path}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(camera.username),
                    ),
                    if (camera.lastConnectedAt != null)
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text('camera_detail_last_connected'.tr()),
                        subtitle: Text(
                          DateFormat('yyyy.MM.dd HH:mm').format(
                            camera.lastConnectedAt!.toLocal(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
