# 서버 전달 — 숨긴(superseded) 카메라가 그룹 저장 때 그룹에서 빠집니다

> **대상**: terra-server 백엔드
> **작성**: 앱, 2026-11-10
> **관련**: `reports/APP_CAMERA_REBIND_SUPERSEDE_2026-11-10_v2.md` (PR #60·#61)
> **성격**: 알림 — 서버 수정 요청 아님. 앱은 이 동작을 그대로 받아들입니다.

## 무엇이 일어나나

1. 앱은 이번 계약대로 `superseded_at`이 있는 카메라를 목록·기기 관리에서 숨깁니다.
2. 그래서 그 카메라가 속한 그룹을 앱은 "카메라 없음"으로 봅니다.
3. 사용자가 그 그룹을 저장하면(이름만 바꿔도) 앱은 `redesign_save_group_v1`에 `p_camera_id = null`을 보냅니다.
4. RPC가 그 그룹의 다른 카메라를 떼어 내는 단계(`UPDATE public.cameras SET enclosure_id=NULL WHERE owner_id=owner AND enclosure_id=target AND id IS DISTINCT FROM p_camera_id`)에서 **숨긴 카메라의 `enclosure_id`도 NULL**이 되고, 트리거가 열린 반려동물 배정을 닫습니다.
5. 나중에 보드가 옛 자격증명으로 돌아오거나 원래 계정이 다시 등록해 `superseded_at`이 풀려도, 그 카메라는 **그룹 밖으로** 돌아옵니다.

전달 문서의 "설정·영상도 그대로"와 이 경우만 어긋납니다. 판단 근거는 앱 레포의 `supabase/drafts/20260915_redesign_groups.sql`이고, 운영 함수가 같은지는 확인하지 않았습니다.

## 앱의 결정

받아들입니다. 24시간 넘게 오프라인이고 다른 계정이 등록한 보드가 복구되는 일은 드뭅니다. 또 앱이 숨긴 카메라를 그룹 저장에 끼워 넣으면 숨긴 의미가 흐려집니다. 복구된 카메라는 사용자가 기기 관리에서 다시 그룹에 넣으면 됩니다.

## 서버에 부탁

- 수정은 필요 없습니다. 문서(스펙 `stage-u-camera-rebind-supersede.md` 또는 API.md)에 "superseded 상태에서 그룹을 저장하면 사육장 배정이 풀릴 수 있다"는 한 줄만 남겨 주세요.
- 나중에 보존이 필요해지면, RPC의 카메라 떼어 내기에서 `superseded_at IS NOT NULL` 행을 빼는 방법이 가장 간단합니다(앱 변경 없음).
