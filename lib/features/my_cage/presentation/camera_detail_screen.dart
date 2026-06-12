import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/action_type.dart';
import '../domain/clip.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';
import 'widgets/clip_card.dart';
import 'widgets/webrtc_live_view.dart';

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

// ── 시연용 데모 행동 매핑 (DB 무수정) ────────────────────────────────────────
// 실제 behavior_logs 연동 시 actionForClip 함수만 교체하면 된다.
const Map<String, ActionType> kDemoClipActions = {
  'a1d5f7b0-b187-48af-8953-9d891989a38c': ActionType.moving,
  '54e39c68-b557-4ed7-b525-3b072b0c7672': ActionType.moving,
  '14160742-97b7-4491-a373-7ea6ab16ab2f': ActionType.moving,
  '2a052abf-ff0b-4f3c-9835-7474ae14ff28': ActionType.drinking,
  'c45d3754-a9ad-4053-87f8-3bbf50268c5a': ActionType.drinking,
  '664eb936-05e3-4bd9-abf6-1f7abe31165c': ActionType.eatingPaste,
  '3eb899c0-d978-428d-89c7-67dfdb30915d': ActionType.eatingPaste,
  'b72bf88d-ec8e-4089-a6c9-3da8f9e3de93': ActionType.eatingPrey,
  'fe420ce8-1e49-44b2-b121-12abb3b0d488': ActionType.shedding,
  '9f6512c1-ef4c-4431-b456-f3cc056ef918': ActionType.defecating,
};

/// 나중에 실제 behavior_logs 연동 자리: 지금은 데모 매핑만.
ActionType? actionForClip(Clip c) => kDemoClipActions[c.id];

/// 행동 탭에 표시할 고정 순서 (demo 기준).
const List<ActionType> kBehaviorTabOrder = [
  ActionType.moving,
  ActionType.drinking,
  ActionType.eatingPaste,
  ActionType.eatingPrey,
  ActionType.shedding,
  ActionType.defecating,
];

/// 현재 카메라 클립 전체 (최신순 50개). 행동 탭 필터에 사용.
final _cameraClipsProvider =
    FutureProvider.autoDispose.family<List<Clip>, String>((ref, cameraId) async {
  final repo = ref.watch(clipRepositoryProvider);
  final page = await repo.listPage(cameraId: cameraId, limit: 50);
  return page.items;
});
// ────────────────────────────────────────────────────────────────────────────

enum _ActivityRange { yesterday, today }

class CameraDetailScreen extends ConsumerStatefulWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<CameraDetailScreen> createState() =>
      _CameraDetailScreenState();
}

class _CameraDetailScreenState extends ConsumerState<CameraDetailScreen> {
  _ActivityRange _activityRange = _ActivityRange.today;
  ActionType _selectedAction = ActionType.moving;

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
              selectedAction: _selectedAction,
              onActionChanged: (a) => setState(() => _selectedAction = a),
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
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          // 라이브 스트림 (WebRTC)
          Positioned.fill(
            child: WebRtcLiveView(cameraUuid: cameraId),
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
    required this.selectedAction,
    required this.onActionChanged,
  });

  final String cameraId;
  final ActionType selectedAction;
  final ValueChanged<ActionType> onActionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clipsAsync = ref.watch(_cameraClipsProvider(cameraId));

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
        if (kShowVerifyClip) ...[
          _VerifyClipsSection(ref: ref),
          const SizedBox(height: 12),
        ],
        clipsAsync.when(
          loading: () => _buildSkeletonList(),
          error: (e, _) => _buildError(context),
          data: (clips) {
            // 행동별 개수 계산
            final countByAction = <ActionType, int>{};
            for (final action in kBehaviorTabOrder) {
              countByAction[action] =
                  clips.where((c) => actionForClip(c) == action).length;
            }

            final filtered = clips
                .where((c) => actionForClip(c) == selectedAction)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActionTabs(
                  selected: selectedAction,
                  countByAction: countByAction,
                  onChanged: onActionChanged,
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  _buildEmptyAction(context)
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                    children: filtered
                        .map(
                          (c) => ClipCard(
                            clip: c,
                            onTap: () =>
                                context.push('/crecam/clips/${c.id}'),
                          ),
                        )
                        .toList(),
                  ),
              ],
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

// ── 행동 탭 (가로 스크롤 ChoiceChip) ─────────────────────────────────────────

class _ActionTabs extends StatelessWidget {
  const _ActionTabs({
    required this.selected,
    required this.countByAction,
    required this.onChanged,
  });

  final ActionType selected;
  final Map<ActionType, int> countByAction;
  final ValueChanged<ActionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kBehaviorTabOrder
            .map((action) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ActionChip(
                    action: action,
                    count: countByAction[action] ?? 0,
                    selected: selected == action,
                    onTap: () => onChanged(action),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.action,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ActionType action;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final label = count > 0
        ? '${action.localizationKey.tr()} $count'
        : action.localizationKey.tr();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
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

// ── 실제 클립 행 ─────────────────────────────────────────────────────────────

