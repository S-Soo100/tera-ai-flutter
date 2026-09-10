import 'nightly_highlight.dart';

/// 하루(20:00 KST 경계, 서버 [NightlyHighlight.dayKey]) 묶음 —
/// ⭐ 대표([featured], episode.rank 오름차순, 카메라당 최대 top_n개)와
/// 후보([candidates], startedAt 내림차순).
///
/// 구 72h 창 앱측 그룹핑(groupHighlights)의 대체(2026-09-11) — 묶음 계산이
/// 서버 `/highlights/featured`로 이관됐다.
typedef DayHighlightGroup = ({
  String dayKey,
  List<NightlyHighlight> featured,
  List<NightlyHighlight> candidates,
});

/// `/highlights/featured` 항목을 [NightlyHighlight.dayKey]로 묶는다 —
/// 최신 day_key 먼저. 각 묶음 안 대표는 episode.rank 오름차순(동순위는
/// startedAt 내림차순), 후보는 startedAt 내림차순.
List<DayHighlightGroup> groupByDay(List<NightlyHighlight> highlights) {
  final byDay = <String, List<NightlyHighlight>>{};
  for (final h in highlights) {
    byDay.putIfAbsent(h.dayKey, () => <NightlyHighlight>[]).add(h);
  }
  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      (
        dayKey: key,
        featured: List.unmodifiable(
          byDay[key]!.where((h) => h.isFeatured).toList()
            ..sort((a, b) {
              final byRank = a.episodeRank.compareTo(b.episodeRank);
              return byRank != 0
                  ? byRank
                  : b.startedAt.compareTo(a.startedAt);
            }),
        ),
        candidates: List.unmodifiable(
          byDay[key]!.where((h) => !h.isFeatured).toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
        ),
      ),
  ];
}

/// 묶음의 가장 최신 **대표** startedAt. 대표가 없으면(방어 — 서버는 클립이
/// 있는 하루엔 rank 1 대표를 항상 만든다) 후보의 최신 startedAt.
DateTime? latestFeaturedAt(DayHighlightGroup group) {
  DateTime? latest;
  for (final h in group.featured.isNotEmpty ? group.featured : group.candidates) {
    if (latest == null || h.startedAt.isAfter(latest)) latest = h.startedAt;
  }
  return latest;
}

/// 도착 배너 dismiss 저장 키 — 그 묶음의 **가장 최신 대표 startedAt** ISO
/// 문자열. day_key를 쓰면 안 된다: 진행 중인 하루에 새 대표가 도착해도
/// day_key는 그대로라 배너가 다시 안 뜬다. 최신 대표 시각은 새 대표마다
/// 바뀌므로 dismiss 의미가 "이 시점까지는 봤다"로 정확해진다(72h 시절
/// to-키 결정과 같은 논리, 리뷰 2026-09-04).
String highlightGroupKey(DayHighlightGroup group) =>
    (latestFeaturedAt(group) ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toIso8601String();

/// "YYYY-MM-DD" day_key → 그 하루의 시작 **날짜**(로컬 자정). 파싱 실패는 null.
DateTime? parseDayKey(String dayKey) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dayKey);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}
