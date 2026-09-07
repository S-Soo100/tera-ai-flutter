import 'package:easy_localization/easy_localization.dart';

/// 시각을 `오전 11:23`으로 — 12시간제 오전/오후 표기의 **단일 구현**.
///
/// 한때 같은 계산(h%12==0→12, 분 zero-pad)이 6곳에 복제돼 있었다(리뷰
/// 2026-09-04: control_log_list·env_summary_bar·플레이어·Camera Home·북마크).
/// 어순까지 통째로 l10n 키에 두는 이유: `AM 10:21`처럼 접두가 아닌 언어가
/// 생겨도 키만 고치면 전 화면이 함께 바뀐다.
///
/// intl `DateFormat('a', 'ko')`를 안 쓰는 이유: 앱이
/// `initializeDateFormatting`을 호출하지 않아 ko 심볼이 없고(throw), 문구
/// 소스를 ko.json 하나로 유지하는 프로젝트 규칙과도 맞다.
String formatAmPmTime(DateTime at) {
  final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return (at.hour < 12 ? 'time_am_fmt' : 'time_pm_fmt').tr(
    namedArgs: {'h': '$h12', 'm': at.minute.toString().padLeft(2, '0')},
  );
}
