# 서버 회신 전 가정 계약 원장 (2026-09-16)

사용자 지시("응답은 아직 안 왔지만, 응답이 와서 수정이 되었다고 가정하고 개발 진행")에 따라 앱이 **미리 구현한 서버·펌웨어 계약**을 한 곳에 모은다.

**2026-09-16 통합 회신 수신** ([원문](../references/2026-09-16-backend-delivery-reply.md)). 대조 결과를 "회신 결과" 열에 적었다. **결정 답신([reply-2](2026-09-16-lee-gwanhun-reply-2-decisions.md))과 답신 1·SQL 초안 폴더는 2026-09-16 사용자가 직접 전달 완료.** secret은 사용자가 별도 채널로 전달(앱 팀 미관여). 다음 대기: 소프트 해제 배포 통보, RPC 초안 검토 결과, 히터 400 적용, skipped는 서버도 구현 완료(스위치 `PUSH_EVENT_SKIPPED_ENABLED` 꺼짐) → [발송 시작 신호](2026-09-16-lee-gwanhun-skipped-go-signal.md) **2026-09-16 Slack DM으로 전달 완료**(사용자 지시로 Claude가 발송). secret은 2026-09-16 사용자가 별도 채널로 전달 완료(값은 앱 팀 문서·채팅에 없음). 서버 활성화 완료(4종 발송 중). 스테이징 샘플 4종 재발송 수신·적재·문구·알림 센터 표시 확인 완료(2026-09-16 07:37 UTC). 단말 FCM 배달만 Android 실기기 후속. 히터는 예약 400 + 직접 INSERT `rejected/unsupported_action`으로 서버 차단 완료. 아직 사용자 결정이 필요한 줄은 굵게 표시.

| # | 회신 결과 | 앱 조치 |
|---|---|---|
| 1 | ⛔ **미지원.** 펌웨어가 `led_on`의 `duration_ms`를 읽지 않고 `ok`만 보냄. MOSFET 보드는 타이머 슬롯 없음 | **A안 확정(사용자, 2026-09-16).** 칩·진행 칩·알림·`FanActuator.led` 제거 완료(`40a55fc`, 0.108.2+267) |
| 2 | ✅ 지원. 릴레이 보드는 무시(400 아님). `brightness: 0`은 꺼짐 → 하한 20% 앱 강제 | 그대로. 앱은 이미 20~100 clamp(시트·편집기 모두) |
| 3 | ✅ 지원(상한 2h, `fan_on`도 동일). ack `state: "TIMER"`, `fan2_off`가 자동 OFF도 취소 | 그대로. pair 복귀 불필요 |
| 4 | ⏸️ **소프트 해제 미구현.** "API 동작이 바뀌므로 합의 후 진행", 서버 우선순위 1. `redesign_unlink_device_v1` 연결 경로는 설계 뒤 통보 | ✅ **배포 완료(2026-09-16 [결정 회신](../references/2026-09-16-backend-decisions-reply.md) §1)** — 경로·본문·응답·오류 그대로. 추가: `request_id` 누락/비UUID는 422(앱은 항상 UUID 전송), `unlinked_at`은 UTC. 실패 시 같은 `request_id` 재시도(앱 컨트롤러가 화면 내 재시도에 같은 키 재사용). 앱 코드 변경 없음. 실기기 해제 검증은 MQTT 계정 회수가 따라와 테스트 계정에서 하지 않음 |
| 5 | ✅ 배포 완료. `GET /devices|cameras`는 해제 기기 제외, 직결 SELECT는 컬럼 노출(RLS 변경 없음), Realtime UPDATE로 전파 | 앱 필터 그대로 동작 |
| 6 | ✅ **운영 적용 완료(최종 현황 §1.4, 함수 13개·트리거 2개·CASCADE 확인)**. 시뮬 실검증: 그룹 생성·삭제, 개체 등록·삭제(툼스톤) RPC 정상(2026-09-16). 이전 경과: 초안 5개를 처음엔 못 읽음("저장소 밖, 경로/파일 필요"). 트리거 방식 통합 동의. 그룹 이름 UNIQUE `(owner_id, btrim(name))`는 적용 완료·409 | [검토 회신](../references/2026-09-16-backend-sql-drafts-reply.md) 수신: 구조 OK, 배포 전 B1~B5·N2. 전부 반영([답신 3](2026-09-16-lee-gwanhun-reply-3-sql-drafts.md)): B2/B3 CASCADE, B4 unlinked 필터, B5 스냅샷·assertion, N2 스텁 제거, B1 트리거 `20260916_relationship_triggers.sql`(제공 SQL의 owner 계산 버그 1건 수정). 검증기 exit 0. 운영 적용은 이관훈님이 §5 순서로. B4: 사용자 승인으로 2026-09-16 `codex/figma-redesign-20260915` push 완료(답신 4·폴더는 사용자가 전달). 이관훈님 회신: 트리거 수정안 채택, 답 5건 반영 확인, **커밋 `bb430fa`(번들 `d635785`) 기준 운영 적용 예정** — Slack DM으로 통보 완료. 다음 대기: 적용 완료·함수명/오류코드 확인 회신 |
| 7 | ✅ 6건 전부 반영·배포. `no_ack` 30초(설정값), `expired`/`unknown_device`도 `failed`. secret 수령 전엔 발송 안 함 | 검증기와 일치. `PUSH_EVENT_INGEST_SECRET` 안전 채널 전달만 남음(앱 팀이 아니라 사용자) |

## 회신에서 새로 나온 앱 조치

| 항목 | 회신 | 앱 현재 상태 |
|---|---|---|
| 지표별 유효 표본 수 | `telemetry_30m.t_a_count/h_a_count/t_b_count/h_b_count` 배포. 2026-09-15 이전 버킷은 null. B센서는 전 기기 유효 0 → `t_b_avg` null. KST 일평균은 `bucket + 9h`로 묶기 | 매핑 완료(`64adbde`, 0.108.3+268). 구 이름은 폴백으로 유지 |
| 히터 | 두 보드 모두 펌웨어 미구현, 항상 `unknown_action`. UI 노출 금지. 서버 400 차단 여부 질문 | 홈 타일·예약 기기 선택은 이미 숨김. 구 사육장 탭 히터 타일 제거 완료(`43b742d`, 0.108.4+269). 서버 400 차단 요청함 |
| 냉각팬 | 릴레이 보드는 `fan2_*` 코드 없음 → `telemetry.fan2 != null`로 노출 판별 | 이미 적용(홈 타일 `--`, 탭 시 무시) |
| `busy`/`error` | 원인 구분 불가, 같은 문구. 재시도는 새 `msg_id` | 앱은 매 명령 새 UUID. 문구는 `module_command_failed` 하나 |
| 그룹 이름 409 | REST `POST/PATCH /enclosures` 위반 시 409 | 앱 그룹 저장은 RPC(23505 매핑). 구 `enclosure_repository`의 직접 insert/update는 409 아닌 23505를 받게 되며 별도 매핑 없음(일반 실패 표시) |
| `pets` | terra-server는 앱 팀 소유로 취급, 건드리지 않음 | 일치 |

| # | 가정 계약 | 앱 구현 위치 | 회신 문서 | 미지원 시 되돌릴 것 |
|---|---|---|---|---|
| 1 | `led_on` + `payload.duration_ms`(≤ 3h) → 펌웨어 자동 OFF | `cage_control_actions.dart` LED 시트 작동 시간 칩, `FanActuator.led` 진행 칩·로컬 알림 | [9/16 요청서 §1(과거 이력)](https://github.com/S-Soo100/tera-ai-flutter/blob/ba747f1606eacffdec8d14ee7da5266e2c913714/docs/handoffs/2026-09-16-server-request-led-timer-schedule-payload.md) | 칩·알림·`duration_ms` 제거(`FanActuator.led` 삭제) |
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
