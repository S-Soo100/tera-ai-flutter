/// 배정 RPC 호출 seam. 테스트가 네트워크 없이 주입할 수 있게 분리한다
/// (`MotionClipRepository`의 ActivityRowsLoader와 같은 관례).
typedef AssignPetRpc = Future<void> Function({
  required String petId,
  required String? enclosureId,
});

/// 개체↔사육장 배정.
///
/// **쓰기 경로는 `assign_pet_to_enclosure` RPC 하나뿐이다.** 앱이 `pets`를
/// 직접 UPDATE하거나 "기존 점유 해제 → 신규 배정"을 여러 UPDATE로 흉내내지
/// 않는다 — 1:1은 부분 UNIQUE 인덱스가, 원자적 교체는 RPC가 보장한다.
///
/// **실패 전에 로컬을 먼저 바꾸지 않는다.** 낙관적 갱신 후 되돌리기는 되돌리기
/// 자체가 실패하면 로컬·서버가 영구히 어긋나고 사용자는 "배정됐다"고 믿는다.
/// RPC 성공 → 재동기화 순서를 고정한다.
class PetAssignmentService {
  final AssignPetRpc _rpc;
  final Future<void> Function() _resync;

  PetAssignmentService({
    required AssignPetRpc rpc,
    required Future<void> Function() resync,
  })  : _rpc = rpc,
        _resync = resync;

  /// [enclosureId]가 null이면 배정 해제.
  ///
  /// 성공 후 **전체** 재동기화하는 이유: RPC가 1:1 유지를 위해 대상 사육장의
  /// **기존 점유 개체도 해제**한다. 대상 1건만 로컬 반영하면 이전 개체가
  /// 배정된 채로 남아 화면에 두 개체가 같은 사육장에 보인다.
  ///
  /// RPC 실패(소유권 불일치·1:1 위반·미인증)와 재동기화 실패 모두 그대로
  /// 전파한다. 조용히 성공으로 위장하지 않는다.
  Future<void> assign({
    required String petId,
    required String? enclosureId,
  }) async {
    await _rpc(petId: petId, enclosureId: enclosureId);
    await _resync();
  }
}
