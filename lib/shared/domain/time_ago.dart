import 'package:easy_localization/easy_localization.dart';

/// "방금 전" / "N분 전" / "N시간 전" / "N일 전".
///
/// 기존 `time_*` 키를 그대로 쓴다. 같은 함수가 화면마다 복사돼 있어(커뮤니티·
/// 크레캠) 표현이 갈릴 수 있으니, 새로 쓰는 곳은 여기를 부른다.
///
/// [now]를 받는 이유는 테스트 때문만이 아니다 — 1분 틱(`nowTickProvider`)에
/// 맞춰 다시 그려야 "3분 전"이 멈춰 있지 않다.
String timeAgo(DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).toUtc().difference(at.toUtc());
  if (diff.inMinutes < 1) return 'time_just_now'.tr();
  if (diff.inMinutes < 60) {
    return 'time_minutes_ago'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'time_hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
  }
  return 'time_days_ago'.tr(namedArgs: {'n': '${diff.inDays}'});
}
