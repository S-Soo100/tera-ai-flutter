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

/// 꾹 눌러 끌기(드래그 선택) 한 번의 결과 — iPhone 사진 앱처럼 처음 누른
/// 영상([anchor])부터 지금 손가락 아래 영상([current])까지 목록 순서의 범위를
/// 한꺼번에 고르거나(select) 뺀다. 되돌아오면 범위가 줄어 지나쳤던 영상은
/// 끌기 시작 전 상태([base])로 돌아간다. 고르기는 [ClipSelection.maxCount]에서
/// 멈추고 [ClipSelectionChange.limited]로 알린다.
ClipSelectionChange dragSelection({
  required ClipSelection base,
  required List<String> ordered,
  required String anchor,
  required String current,
  required bool select,
}) {
  final a = ordered.indexOf(anchor);
  final c = ordered.indexOf(current);
  if (a < 0 || c < 0) return ClipSelectionChange(base, limited: false);
  final lo = a < c ? a : c;
  final hi = a < c ? c : a;
  // 처음 누른 영상부터 손가락 쪽으로 — 상한에 걸리면 손가락에서 먼 쪽이 남는다.
  final range = a <= c
      ? ordered.sublist(lo, hi + 1)
      : ordered.sublist(lo, hi + 1).reversed.toList();
  if (!select) {
    final drop = range.toSet();
    return ClipSelectionChange(
        ClipSelection(active: true, ids: [
          for (final id in base.ids)
            if (!drop.contains(id)) id
        ]),
        limited: false);
  }
  final next = [...base.ids];
  var limited = false;
  for (final id in range) {
    if (next.contains(id)) continue;
    if (next.length >= ClipSelection.maxCount) {
      limited = true;
      break;
    }
    next.add(id);
  }
  return ClipSelectionChange(ClipSelection(active: true, ids: next),
      limited: limited);
}
