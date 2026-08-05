import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../my_cage/presentation/supabase_module_providers.dart';

/// PRD §3.2 라이브 영역의 "현재 시각 오버레이".
///
/// **별도 위젯으로 분리한 이유가 둘 있다.**
/// 1) `DateTime.now()`를 부모 build에서 읽으면 위젯이 재빌드될 때만 갱신돼
///    시계가 멈춘 것처럼 보인다. 라이브 화면에서 시각이 멎으면 "지금 화면이
///    맞나"를 판단할 근거가 사라진다. 1분 tick을 구독해 스스로 갱신한다.
/// 2) 그 구독을 부모가 하면 매분 라이브 비디오 서브트리까지 재빌드된다.
///    여기서만 구독해 재빌드 범위를 이 텍스트로 가둔다.
class LiveClockOverlay extends ConsumerWidget {
  const LiveClockOverlay({super.key});

  static const clockKey = Key('live_clock_overlay');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
    return Container(
      key: clockKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // 밝은 사육장 영상 위에서도 읽히도록 어두운 판을 깐다.
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        DateFormat('yyyy.MM.dd HH:mm').format(now),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
