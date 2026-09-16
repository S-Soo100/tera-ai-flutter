# 서버 회신 전 가정 계약 원장 (2026-09-16)

사용자 지시("응답은 아직 안 왔지만, 응답이 와서 수정이 되었다고 가정하고 개발 진행")에 따라 앱이 **미리 구현한 서버·펌웨어 계약**을 한 곳에 모은다. 회신이 오면 각 줄을 대조해 "그대로 / 수정 / 되돌림"을 적는다. 아래 어느 것도 운영 서버에서 확인된 것이 아니다.

| # | 가정 계약 | 앱 구현 위치 | 회신 문서 | 미지원 시 되돌릴 것 |
|---|---|---|---|---|
| 1 | `led_on` + `payload.duration_ms`(≤ 3h) → 펌웨어 자동 OFF | `cage_control_actions.dart` LED 시트 작동 시간 칩, `FanActuator.led` 진행 칩·로컬 알림 | [9/16 요청서 §1](2026-09-16-server-request-led-timer-schedule-payload.md) | 칩·알림·`duration_ms` 제거(`FanActuator.led` 삭제) |
| 2 | `schedules.payload.brightness` 저장·수정·실행 전달 | 예약 편집기 LED 밝기 행 | 9/16 요청서 §2 | 밝기 행 제거 |
| 3 | `schedules.payload.duration_ms` → `fan2_on` 실행 시 전달 | 냉각팬 예약 단건 저장 | 9/16 요청서 §3 | pair(on/off) 방식 복귀(코드 보존) |
| 4 | `POST /devices/{uuid}/unlink`, `POST /cameras/{uuid}/unlink` body `{request_id}` — 소프트 해제(`unlinked_at`), MQTT 계정 회수, 원본 보존 | `RedesignGroupRepository.unlink`, 기기 관리 "이 기기 삭제" | [9/16 답신 §2-2](2026-09-16-lee-gwanhun-reply-groups-and-push.md) · 회신 §2.5 | 경로명만 바꾸면 됨. 미배포 동안은 "서버 미지원" 표시 |
| 5 | `devices.unlinked_at` / `cameras.unlinked_at` 컬럼 — 있으면 해제 기기 | 기기 목록·카메라 목록·기기 관리 인벤토리의 앱측 필터, SQL 초안 | 회신 §2.5 | 컬럼 없으면 무영향(전부 표시) |
| 6 | 그룹·이름·개체·그룹 삭제 RPC 5종(`redesign_*_v1`)이 초안과 같은 이름·응답·오류코드로 배포 | `RedesignGroupRepository`, `RedesignPetRepository` | 9/16 답신 §2 | 함수명·응답이 다르면 저장소 한 파일 수정 |
| 7 | 푸시 이벤트: `execution_source=schedule`만, `outcome`(succeeded/failed) + `result`(펌웨어 원문·`no_ack`), `device_id` UUID + `device_key`, `device_name` 포함, 무응답은 `failed`+`no_ack` | `supabase/functions/_shared/notification-contract.mjs`, `20260916000000_notification_device_action_copy.sql`(미적용) | 9/16 답신 §3 | 필드명만 검증기에서 되돌림 |

## 앱이 여전히 하지 않는 것

- 카메라·기기 hard DELETE 호출(구 카메라 상세 버튼 제거됨). `DELETE /clips/{id}` 호출.
- RPC가 없을 때 테이블 직접 쓰기로 우회.
- `telemetry_1m` 조회.

## 확인 시 함께 볼 것

- 기기 관리의 삭제 확인 문구 `management_delete_confirm`("기기와 연동된 데이터도 함께 삭제됩니다")는 Figma 원문이지만 소프트 해제 계약(원본 보존)과 어긋난다. 회신 확정 뒤 문구 결정 필요.
