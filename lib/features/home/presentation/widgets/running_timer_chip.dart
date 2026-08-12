import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// **아직 배선할 곳이 없다.** 한때 `device_timers` 테이블(B안)을 조회했으나,
/// 2026-08-12 일회성 타이머를 **A안(`fan_on` + `duration_ms`, 펌웨어 자동 OFF)**
/// 으로 정하면서 그 테이블은 만들어지지 않는다. 없는 테이블을 매번 조회해
/// 실패를 삼키던 코드라 걷어냈다.
///
/// A안이 열리면 여기를 이렇게 채운다 — `commands`에서 `duration_ms`가 붙은
/// 최근 `*_on`(status='acked')을 찾아 `issued_at + duration_ms`로 종료 시각을
/// 계산한다. 서버에 상태를 따로 두지 않아도 다기기에서 같은 값이 나온다.
/// 확인 대기 항목은 `docs/backend-handoff-timer-mist.md` §10.5.
///
/// 그때까지 빈 목록을 돌려 칩만 안 뜨게 한다. throw하면 제어 탭 전체가
/// 에러 화면이 된다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  await ref.watch(currentSetProvider.future);
  return const [];
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
