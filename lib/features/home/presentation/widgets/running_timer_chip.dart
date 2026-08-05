import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/theme/app_styles.dart';
import '../../domain/running_timer.dart';
import '../home_set_providers.dart';

/// 1초 tick. autoDispose라 홈을 떠나면 타이머가 멈춘다.
final _secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// 현재 세트 제어기의 진행 중 타이머.
///
/// `device_timers`(BE4)가 없으면 조회가 실패한다 — 빈 목록으로 흡수해서
/// 칩만 안 뜨게 한다. 여기서 throw하면 제어 탭 전체가 에러 화면이 된다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  final deviceId = set?.device?.id;
  if (deviceId == null) return const [];
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('device_timers')
        .select()
        .eq('device_id', deviceId)
        .order('ends_at', ascending: true);
    return (rows as List)
        .map((r) => RunningTimer.fromJson(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
});

/// PRD §3.4 진행 중 타이머 칩. 가동 중 타이머가 있을 때만 노출.
class RunningTimerChip extends ConsumerWidget {
  const RunningTimerChip({super.key});

  static const chipKey = Key('running_timer_chip');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_secondTickProvider).valueOrNull ?? DateTime.now();
    final timers = ref.watch(runningTimersProvider).valueOrNull ?? const [];
    final active = timers.where((t) => t.isActive(now)).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final t = active.first;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      key: chipKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.spacing12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppStyles.chipRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16),
            const SizedBox(width: AppStyles.spacing8),
            Expanded(
              child: Text(
                'home_timer_running'.tr(args: [
                  t.actuatorLabelKey.tr(),
                  '${t.durationMinutes}',
                  formatRemaining(t.remaining(now)),
                ]),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
