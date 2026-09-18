import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/schedule.dart';
import 'schedule_providers.dart';
import 'widgets/schedule_editor_sheet.dart';

/// 편집기 초안([ScheduleDraft])을 서버 CRUD로 옮긴다 — 예약 설정 화면과 홈
/// 제어 시트의 예약 탭이 같은 분기를 쓴다(구간=addSpan/updateSpanTiming,
/// 시점·duration 단건=add/updateTiming). 실패는 그대로 던진다 — 호출자가
/// 스낵바로 알린다(예약은 "됐겠지"로 넘길 수 있는 동작이 아니다).
Future<void> applyScheduleDraft(
  WidgetRef ref,
  ScheduleDraft draft, {
  Schedule? editing,
  SchedulePair? editingPair,
}) async {
  final notifier = ref.read(schedulesProvider.notifier);
  if (editingPair != null) {
    await notifier.updateSpanTiming(
      editingPair,
      kind: draft.kind,
      startHour: draft.hour,
      startMinute: draft.minute,
      endHour: draft.endHour!,
      endMinute: draft.endMinute!,
      daysOfWeek: draft.daysOfWeek,
      guard: draft.guard,
      clearGuard: draft.clearGuard,
      payload: draft.payload,
    );
    return;
  }
  if (editing != null) {
    // `action`은 서버가 수정을 안 받는다. 편집기는 타이밍만 바꾸고 가드는
    // 손대지 않는다(PATCH에 guard 키 생략 → 서버 값 유지).
    await notifier.updateTiming(
      editing,
      kind: draft.kind,
      hour: draft.hour,
      minute: draft.minute,
      daysOfWeek: draft.daysOfWeek,
      payload: draft.payload,
      guard: draft.guard,
      clearGuard: draft.clearGuard,
    );
    return;
  }
  if (draft.isSpan) {
    await notifier.addSpan(
      onAction: draft.action,
      offAction: draft.offAction!,
      kind: draft.kind,
      startHour: draft.hour,
      startMinute: draft.minute,
      endHour: draft.endHour!,
      endMinute: draft.endMinute!,
      daysOfWeek: draft.daysOfWeek,
      guard: draft.guard,
      payload: draft.payload,
    );
  } else {
    await notifier.add(
      action: draft.action,
      kind: draft.kind,
      hour: draft.hour,
      minute: draft.minute,
      daysOfWeek: draft.daysOfWeek,
      payload: draft.payload,
      guard: draft.guard,
    );
  }
}
