import 'highlight_publication.dart';
import 'nightly_highlight.dart';

/// 하이라이트 정책 v2(2026-09-19 사용자 확정) — 밤 구간만, D+2일 08:00 KST 공개.
///
/// 공개 시각이 날짜만의 함수라 서버 상태 없이 앱이 계산한다(검수가 늦어도
/// 기다리지 않는다). **KST = UTC+9 고정**이므로 전부 UTC로 계산한다 — 기기
/// 시간대·시계 설정과 무관하게 같은 순간에 열린다.
typedef NightWindow = ({
  DateTime captureStart,
  DateTime captureEnd,
  DateTime publishedAt,
});

final _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// day_key(밤이 시작한 날짜 D) → 촬영 D 20:00~D+1 08:00 KST, 공개 D+2 08:00 KST.
/// 형식이 깨졌으면 null.
NightWindow? nightWindowFor(String dayKey) {
  final m = _dayKeyPattern.firstMatch(dayKey);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  return (
    captureStart: DateTime.utc(y, mo, d, 11), // D 20:00 KST
    captureEnd: DateTime.utc(y, mo, d, 23), // D+1 08:00 KST
    publishedAt: DateTime.utc(y, mo, d + 1, 23), // D+2 08:00 KST
  );
}

/// 서버 목록에 정책을 입힌다: ① 밤 구간 밖(낮) 촬영분 제거 ② publication이
/// 없으면 day_key로 합성 ③ 아직 공개 시각 전인 항목 제거.
///
/// 서버가 publication을 주면 그 값을 그대로 쓴다(공개 시각·구간 모두).
/// day_key를 못 읽는 항목은 공개 시각을 알 수 없으므로 버린다.
List<NightlyHighlight> applyNightPolicy(
    List<NightlyHighlight> highlights, DateTime now) {
  final result = <NightlyHighlight>[];
  for (final h in highlights) {
    final server = h.publication;
    if (server != null) {
      if (server.availableAt(now)) result.add(h);
      continue;
    }
    final window = nightWindowFor(h.dayKey);
    if (window == null) continue;
    final at = h.startedAt.toUtc();
    if (at.isBefore(window.captureStart) || !at.isBefore(window.captureEnd)) {
      continue;
    }
    final publication = HighlightPublication(
      batchId: 'night:${h.dayKey}',
      captureStart: window.captureStart,
      captureEnd: window.captureEnd,
      publishedAt: window.publishedAt,
      status: 'ready',
    );
    if (publication.availableAt(now)) {
      result.add(h.withPublication(publication));
    }
  }
  return result;
}

/// [now] **이후** 처음 오는 08:00 KST(=23:00 UTC). 화면이 켜진 채 공개 시각을
/// 넘길 때 목록을 다시 계산하는 타이머용.
DateTime nextPublishAfter(DateTime now) {
  final utc = now.toUtc();
  final today = DateTime.utc(utc.year, utc.month, utc.day, 23);
  return utc.isBefore(today) ? today : today.add(const Duration(days: 1));
}
