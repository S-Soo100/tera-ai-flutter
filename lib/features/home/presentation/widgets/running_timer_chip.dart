import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../domain/running_timer.dart';
import '../home_control_providers.dart';

/// 1초 tick. autoDispose라 홈을 떠나면 타이머가 멈춘다.
final _secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// 현재 세트 제어기의 진행 중 팬 타이머 (A안 — `commands`에서 계산).
///
/// `issued_at + duration_ms`로 종료 시각을 만든다(2026-08-14 핸드오프 §1.3).
/// 서버에 타이머 상태를 따로 두지 않아 다기기에서 같은 값이 나온다.
/// 타이머 발행·취소 직후에는 발행부(`cage_control_actions.dart`)가 이 provider를
/// invalidate해 칩을 깨운다.
///
/// 조회 실패는 빈 목록으로 흡수한다 — 칩 하나 때문에 제어 탭 전체를 에러
/// 화면으로 만들지 않는다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  try {
    final rows = await client
        .from('commands')
        .select('id, device_id, action, status, payload, issued_at')
        .eq('device_id', deviceId)
        .inFilter('action', ['fan_on', 'fan_off', 'fan_toggle'])
        .order('issued_at', ascending: false)
        .limit(10);
    final t = RunningTimer.fanTimerFrom(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      DateTime.now(),
    );
    return t == null ? const [] : [t];
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
    // 타이머 목록을 **먼저** 본다. 비어 있으면 tick을 구독하지 않고 빠진다 —
    // 반대로 하면 표시할 타이머가 없어도(현재 device_timers 부재로 항상 없다)
    // 홈이 떠 있는 내내 매초 리빌드가 돈다.
    final timers = ref.watch(runningTimersProvider).valueOrNull ?? const [];
    if (timers.isEmpty) return const SizedBox.shrink();

    final now = ref.watch(_secondTickProvider).valueOrNull ?? DateTime.now();
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
