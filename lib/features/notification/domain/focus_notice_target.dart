/// 카메라 렌즈 초점 안내를 알림함에서 열 때 갈 카메라 상세 경로.
///
/// 안내가 카메라를 가리키면([targetCameraId], 기획 2026-11-11 카메라 단위) 그
/// 카메라가 내 목록에 있을 때 그 상세, 없으면(연결 해제·이관) null.
/// 가리키지 않는 v1(사람 단위) 행은 카메라 탭에서 고른 카메라가 내 목록에 있으면
/// 그것, 없으면 첫 카메라. null이면 호출한 쪽이 카메라 탭으로 `go`한다(셸 탭
/// 경로라 push하면 셸이 겹친다).
String? focusNoticeCameraPath({
  required List<String> myCameraIds,
  required String? selectedCameraId,
  String? targetCameraId,
}) {
  if (targetCameraId != null) {
    return myCameraIds.contains(targetCameraId)
        ? '/crecam/cameras/$targetCameraId/live'
        : null;
  }
  if (myCameraIds.isEmpty) return null;
  final id = selectedCameraId != null && myCameraIds.contains(selectedCameraId)
      ? selectedCameraId
      : myCameraIds.first;
  return '/crecam/cameras/$id/live';
}
