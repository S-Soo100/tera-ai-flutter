import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_selection_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_selection_flow.dart';

/// 디자이너 피드백(2026-10-21): 작업 취소 시 N≥1이면 "영상 N/전체개 … 완료",
/// N=0이면 "작업을 취소했습니다". (EasyLocalization 없이 키를 그대로 본다.)
void main() {
  test('하나도 못 했으면 작업을 취소했습니다', () {
    for (final kind in ClipBatchKind.values) {
      expect(ClipSelectionFlow.cancelledMessageKey(kind, 0),
          'clip_select_job_cancelled');
    }
  });

  test('일부 했으면 종류별 N/전체 완료 문구', () {
    expect(ClipSelectionFlow.cancelledMessageKey(ClipBatchKind.save, 3),
        'clip_select_download_partial_done');
    expect(ClipSelectionFlow.cancelledMessageKey(ClipBatchKind.bookmarkAdd, 3),
        'clip_select_bookmark_partial_done');
    expect(
        ClipSelectionFlow.cancelledMessageKey(ClipBatchKind.bookmarkRemove, 3),
        'clip_select_unbookmark_partial_done');
  });

  test('공유는 다 받기 전엔 아무것도 공유하지 않으니 늘 취소 문구', () {
    expect(ClipSelectionFlow.cancelledMessageKey(ClipBatchKind.share, 5),
        'clip_select_job_cancelled');
  });
}
