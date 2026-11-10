/// 카메라 렌즈 초점 안내를 알림함에서 열 때 갈 카메라 상세 경로.
///
/// 안내는 사람 단위라 카메라 id가 없다(2026-11-10 사용자 결정). 카메라 탭에서
/// 고른 카메라가 내 목록에 있으면 그것, 없으면 첫 카메라. 카메라가 없으면
/// null — 호출한 쪽이 카메라 탭으로 `go`한다(셸 탭 경로라 push하면 셸이 겹친다).
String? focusNoticeCameraPath({
  required List<String> myCameraIds,
  required String? selectedCameraId,
}) {
  if (myCameraIds.isEmpty) return null;
  final id = selectedCameraId != null && myCameraIds.contains(selectedCameraId)
      ? selectedCameraId
      : myCameraIds.first;
  return '/crecam/cameras/$id/live';
}
