import 'package:easy_localization/easy_localization.dart';

/// 초 → "Xh Ym" / "Xh" / "Ym" 표기. 분은 반올림하되, 활동이 조금이라도(>0)
/// 있으면 최소 1분으로 올려 미세 활동을 무활동(0m)과 구분한다. h>0·m==0이면 "Xh".
/// 홈 '활동량 분석 요약'과 크레캠 '간단 활동량'이 공용으로 쓰는 움직임 시간 표기.
String formatMotionDuration(int seconds) {
  var totalMin = (seconds / 60).round();
  if (totalMin == 0 && seconds > 0) totalMin = 1;
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h > 0) {
    return m == 0
        ? 'crecam_detail_duration_h'.tr(namedArgs: {'h': '$h'})
        : 'crecam_detail_duration_hm'.tr(namedArgs: {'h': '$h', 'm': '$m'});
  }
  return 'crecam_detail_duration_m'.tr(namedArgs: {'m': '$m'});
}
