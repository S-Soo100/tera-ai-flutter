import 'nightly_highlight.dart';

/// 하이라이트 묶음 — [from](가장 오래된 항목)~[to](가장 최신 항목) 구간과
/// 항목 목록(startedAt 내림차순).
typedef HighlightGroup = ({
  DateTime from,
  DateTime to,
  List<NightlyHighlight> items,
});

/// 묶음 창 크기. 정책 노트 "2-3일 하이라이트를 묶어서 제공"의 앱측 근사 —
/// 백엔드 묶음 계약이 생기면 이 로직 전체가 교체된다(계획서 §5).
const kHighlightGroupWindow = Duration(hours: 72);

/// 하이라이트를 **최신부터 72시간 창**으로 그룹핑한다.
///
/// 정렬(startedAt 내림차순) 후, 각 그룹의 **가장 최신 항목을 앵커**로 삼아
/// 앵커에서 72시간 미만 이내의 항목을 같은 그룹에 담는다. 창을 벗어나는
/// 첫 항목이 다음 그룹의 새 앵커가 된다.
/// (경계: 앵커-71h는 같은 그룹, 앵커-73h는 다음 그룹.)
List<HighlightGroup> groupHighlights(List<NightlyHighlight> highlights) {
  if (highlights.isEmpty) return const [];
  final sorted = [...highlights]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final groups = <HighlightGroup>[];
  var current = <NightlyHighlight>[sorted.first];
  var anchor = sorted.first.startedAt;
  for (final h in sorted.skip(1)) {
    if (anchor.difference(h.startedAt) < kHighlightGroupWindow) {
      current.add(h);
    } else {
      groups.add(_toGroup(current));
      current = [h];
      anchor = h.startedAt;
    }
  }
  groups.add(_toGroup(current));
  return groups;
}

HighlightGroup _toGroup(List<NightlyHighlight> items) => (
      // items는 내림차순 — last가 가장 오래됨(from), first가 최신(to).
      from: items.last.startedAt,
      to: items.first.startedAt,
      items: List.unmodifiable(items),
    );

/// 도착 배너 dismiss 저장 키 — 그룹의 from(가장 오래된 항목 시각) ISO 문자열.
/// 같은 그룹이면 재방문에도 숨기고, 새 그룹(from이 다름)이 오면 다시 보인다.
String highlightGroupKey(HighlightGroup group) => group.from.toIso8601String();
