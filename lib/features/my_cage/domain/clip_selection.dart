/// 영상 여러 개 선택 상태 (Figma '영상 선택' 1497:14225).
///
/// 선택 모드는 화면 우상단 선택 버튼(카메라 탭은 [영상 선택])이나 영상을
/// 꾹 눌러 들어간다. 고른 순서를 지켜 두어 저장·공유가 사용자가 고른
/// 순서대로 진행된다.
///
/// 한 번에 [maxCount]개까지(2026-10-20 사용자 결정) — 저장은 영상마다
/// 내려받기라 많으면 오래 걸린다.
class ClipSelection {
  const ClipSelection({this.active = false, this.ids = const []});

  static const int maxCount = 20;

  final bool active;

  /// 고른 순서.
  final List<String> ids;

  int get count => ids.length;
  bool contains(String id) => ids.contains(id);

  /// 선택 모드 진입. [first]가 있으면(꾹 누르기) 그 영상을 고른 채로 시작.
  ClipSelection enter([String? first]) =>
      ClipSelection(active: true, ids: first == null ? const [] : [first]);

  /// 하나 넣거나 뺀다. 상한이면 그대로 돌려준다(호출자가 안내).
  ClipSelection toggle(String id) {
    if (ids.contains(id)) {
      return ClipSelection(active: active, ids: [...ids]..remove(id));
    }
    if (ids.length >= maxCount) return this;
    return ClipSelection(active: active, ids: [...ids, id]);
  }

  /// 묶음(날짜·시간 머리) 전체 — 묶음이 전부 골라져 있으면 모두 빼고, 아니면
  /// 남은 자리만큼 앞에서부터 채운다. [ClipSelectionChange.limited]면 일부만 들어갔다.
  ClipSelectionChange setGroup(List<String> group) {
    if (group.isNotEmpty && group.every(ids.contains)) {
      return ClipSelectionChange(
          ClipSelection(active: active, ids: [
            for (final id in ids)
              if (!group.contains(id)) id
          ]),
          limited: false);
    }
    final next = [...ids];
    var limited = false;
    for (final id in group) {
      if (next.contains(id)) continue;
      if (next.length >= maxCount) {
        limited = true;
        break;
      }
      next.add(id);
    }
    return ClipSelectionChange(ClipSelection(active: active, ids: next),
        limited: limited);
  }

  /// 더보기 "전체 선택" — 지금 목록 순서대로 앞에서부터 [maxCount]개.
  ClipSelectionChange selectAll(List<String> all) {
    final next = [...ids];
    var limited = false;
    for (final id in all) {
      if (next.contains(id)) continue;
      if (next.length >= maxCount) {
        limited = true;
        break;
      }
      next.add(id);
    }
    return ClipSelectionChange(ClipSelection(active: active, ids: next),
        limited: limited);
  }

  /// 작업 뒤 일부가 실패하면 실패한 것만 골라진 채로 남긴다.
  ClipSelection keepOnly(Iterable<String> keep) =>
      ClipSelection(active: active, ids: [
        for (final id in ids)
          if (keep.contains(id)) id
      ]);
}

class ClipSelectionChange {
  const ClipSelectionChange(this.selection, {required this.limited});
  final ClipSelection selection;
  final bool limited;
}

/// 묶음 머리 체크박스 상태 — 전부 골라졌을 때만 켬.
bool groupFullySelected(ClipSelection s, List<String> group) =>
    group.isNotEmpty && group.every(s.contains);
