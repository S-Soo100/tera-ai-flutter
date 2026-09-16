# 이관훈님 전달용 — 9/15 회신 2건에 대한 앱 팀 답신과 그룹 RPC 초안 전달

수신: 이관훈님 / terra-server

작성일: 2026-09-16

대상: 비바나트(vivanaut) 앱 디자인 개편 · Android 푸시 연동

관훈님 안녕하세요. 9/15에 보내주신 두 회신(기기 등록·그룹·기록 보존·온습도 계약 / 예약·타이머 푸시 이벤트) 잘 받았습니다. 두 문서 모두 "앱 팀 답이 있어야 구현 규모가 정해진다"고 하신 항목이 있어, 그 답과 함께 앱 팀 몫으로 합의된 SQL 초안을 보내드립니다.

| 구분 | 내용 |
|---|---|
| 답변 | 재설계 회신 §7 "앱 팀에 부탁드리는 것" 5건, 푸시 회신 §7 확인 요청 6건 |
| 전달 | 그룹·이름·연결 이력·개체·그룹 삭제 SQL 초안 5개 + 격리 검증 스크립트 |
| 요청 | 초안 검토·운영 적용, 이름 제약을 초안과 같은 규칙으로, 배포 후 함수명·응답·오류코드 회신 |

---

## 1. 재설계 회신 §7 답변

### 1-1. 이름 비교 규칙 — 확정

앱 검증, 개체 등록 폼, SQL 초안이 이미 같은 규칙을 씁니다. 서버 제약도 이 규칙으로 맞춰주세요.

| 항목 | 규칙 |
|---|---|
| 공백 | 앞뒤 공백만 제거(유니코드 공백 포함). **가운데 공백은 유지하고 글자 수에 포함** (`사육 환경 1`은 7자) |
| 대소문자 | **구분합니다.** 회신 §3.1의 `lower(btrim(name))` 대신 `btrim(name)` 만 써주세요. 앱·개체 폼·초안이 모두 정확 일치라 한쪽만 `lower`면 앱 사전 검사와 서버 409가 어긋납니다 |
| 길이 | 최대 10자. 앱은 grapheme(사용자가 보는 글자) 단위로 셉니다 |
| 허용 문자 | 초안은 출력 가능한 ASCII와 완성형 한글(가~힣)만 통과시키고 그 외(이모지·결합 문자·자모 단독)는 `0A000`으로 거부합니다. PostgreSQL `char_length`가 grapheme 수가 아니라서, ICU/UAX29 기준 검증기를 넣기 전까지 보수적으로 막아둔 것입니다. 이 범위로 1차 배포하고, 넓히려면 서버에서 grapheme 검증을 어떻게 할지 같이 정하면 좋겠습니다 |
| 기존 이름 | 자동 개명하지 않습니다. 이름을 안 바꾸고 구성원만 바꾸는 저장은 기존 이름이 규칙 밖이어도 통과합니다 |

### 1-2. 기기 이름 중복 범위 — 사육장 + 카메라 합산

| 대상 | 중복 검사 범위 | 초안 위치 |
|---|---|---|
| 사육장·카메라 이름 | 같은 계정의 `devices` **와** `cameras` 를 합쳐서 검사 | `redesign_rename_item_v1` |
| 그룹 이름 | 같은 계정의 `enclosures` 안에서만 | `redesign_save_group_v1` |
| 개체 이름 | 같은 계정의 `pets` 안에서만 | `redesign_save_pet_v1` |

회신 §3.1 지적대로 두 테이블에 걸친 제약은 단일 UNIQUE 인덱스로 안 되므로 RPC 안에서 소유자 행을 잠근 뒤 검사합니다. 그룹 이름에는 인덱스도 함께 거는 이중 방어에 찬성합니다. 단 인덱스 식은 1-1대로 `(owner_id, btrim(name))` 입니다.

### 1-3. `telemetry_1m` 미사용 — 확인

앱 코드에 `telemetry_1m` 참조가 0건입니다. `telemetry_30m` 만 씁니다.

### 1-4. `DELETE /clips/{id}` 미호출 — 확인

앱은 클립 삭제 API를 호출하지 않습니다. 사용자별 "영상 숨김"은 앱 전용 테이블(`supabase/drafts/20260915_clip_visibility.sql`, 앱 팀 관리)로 처리하고 원본 행·R2는 건드리지 않습니다.

### 1-5. `PAIR_OK` 로 등록 완료 판정 — 적용됨

BLE 어댑터가 `WIFI_OK`(Wi-Fi 연결)와 `PAIR_OK <device_id>`(서버 등록)를 분리해 처리합니다. 회신 §1.2 주의대로 "등록 완료"와 "온라인"도 별개로 표시합니다.

### 1-6. 정정 — `pets` 와 `assign_pet_to_enclosure` 는 운영 Supabase에 있습니다

회신 §4.1이 "없음"으로 조사한 것은 terra-server 저장소 기준이고, 그 판단은 맞습니다. 다만 **같은 Supabase 프로젝트의 `public` 스키마에는 앱 팀이 만든 `pets` 테이블과 `assign_pet_to_enclosure` RPC가 이미 있고 현재 앱이 사용 중**입니다(2026-09-16 읽기 전용 조회로 재확인). 초안은 이 둘을 전제로 작성했으니, 서버 쪽에서 새로 만들거나 덮어쓰지 말아 주세요.

---

## 2. 그룹·이름·연결 이력 SQL 초안 전달

회신 §4.3 "앱 팀이 SQL/RPC 초안을 작성하고 terra-server·웹 호출부를 거기에 맞춘다"는 분장에 따른 전달본입니다. **전부 검토용이며 운영 DB에는 적용하지 않았습니다.** 오늘 운영 `public` 스키마를 조회한 결과 `redesign_` 함수는 하나도 없습니다.

### 2-1. 파일

| 순서 | 파일 | 내용 |
|---|---|---|
| 1 | `supabase/drafts/20260915_assignment_history.sql` | `pets.deleted_at`, 개체–카메라 연결 이력 `pet_camera_assignments`, 이력 갱신 helper. 다른 초안의 선행 조건 |
| 2 | `supabase/drafts/20260915_redesign_groups.sql` | 그룹 저장·구성원 제외·이름 변경·기기 해제 RPC, 이름 검증, 기본 이름 `사육 환경 N` 자동 부여, 유형별 1개 상한, 빈 그룹 제거, 멱등 요청 기록 |
| 3 | `supabase/drafts/20260915_clip_visibility.sql` | 앱 전용 영상 숨김(서버 변경 없음, 참고) |
| 4 | `supabase/drafts/20260915_redesign_pets.sql` | 개체 저장·삭제(툼스톤) RPC, 삭제된 개체 숨김 정책 |
| 5 | `supabase/drafts/20260915_redesign_delete_group.sql` | 그룹 삭제 RPC(구성원·영상·즐겨찾기 보존, 이력 종료). 별도 문서 `2026-09-15-group-delete-atomic-contract.md` 와 같은 내용 |
| 검증 | `tools/verify_redesign_sql.py` + `test/sql/*.sql` | 네트워크 없는 임시 PostgreSQL에서 1~5를 순서대로 적용하고 계약 assertion 실행 후 ROLLBACK |

### 2-2. 앱이 호출하는 함수와 계약

소유자는 항상 `auth.uid()` 입니다. 클라이언트가 owner를 지정하지 않습니다.

| 함수 | 용도 | 성공 응답 |
|---|---|---|
| `redesign_save_group_v1(p_group_id, p_name, p_device_id, p_camera_id, p_pet_id, p_expected_members, p_request_id)` | 그룹 생성·이름 변경·구성원 교체. `p_name` null이면 서버가 빈 `사육 환경 N` 선택 | `{"group_id": uuid}` |
| `redesign_remove_group_member_v1(p_kind, p_item_id, p_expected_group_id, p_request_id)` | 구성원 하나 제외, 마지막이면 빈 그룹 제거 | `{"removed": true}` |
| `redesign_rename_item_v1(p_kind, p_item_id, p_name)` | 사육장·카메라 이름 변경 | `{"id": uuid}` |
| `redesign_delete_group_v1(p_group_id, p_request_id)` | 그룹만 삭제, 구성원 보존 | `{"group_id": uuid, "deleted": true}` |
| `redesign_save_pet_v1(...)` / 개체 삭제 | 개체 등록·수정·툼스톤 | 초안 참조 |
| `redesign_unlink_device_v1(p_kind, p_item_id, p_request_id)` | **자리만 있음.** 현재는 `0A000` 을 던집니다. 회신 §2.5 소프트 해제(`unlinked_at` 또는 `POST /devices/{id}/unlink`)가 배포되면 그 경로를 호출하도록 채웁니다 | — |

오류 코드는 앱이 그대로 사용자 문구로 매핑합니다.

| 코드 | 의미 | 앱 표시 |
|---|---|---|
| `23505` | 이름 중복 | "이미 사용 중인 이름" |
| `40001` | 화면에서 본 구성원 상태와 서버가 다름 | "목록이 바뀌었습니다, 다시 시도" + 재조회 |
| `42501` | 소유권·인증 불일치 | 재로그인 안내 |
| `22023` | 잘못된 입력(멱등 키 재사용·필수값 누락) | 일반 실패 |
| `0A000` / `42883` / `PGRST202` | 함수 없음·미지원 | "서버 미지원" — 앱은 직접 테이블 쓰기로 우회하지 않습니다 |

`p_request_id` 는 앱이 만든 UUID이고, 같은 계정·같은 키·같은 payload 재시도는 최초 결과를 돌려주며, 다른 payload에 같은 키는 거부합니다. 회신 §7의 "이동 중 오류·동일 요청 재시도" 시나리오가 이걸로 통과합니다.

### 2-3. 부탁드리는 것

1. 초안 1·2·4·5 검토와 운영 적용. 초안 머리말의 전제(모든 관계 writer가 같은 소유자 잠금·이력 helper를 경유)를 지켜야 안전합니다.
2. **terra-server의 `PATCH /devices|cameras/{id}` `enclosure_id` 변경과 웹 콘솔 `assignEnclosure()` 를 같은 트랜잭션·이력 경로로 통합.** 회신 §4.4 권장대로 DB 트리거 방식이면 초안의 helper를 트리거에서 호출하는 형태를 제안합니다.
3. 소프트 해제(§2.5)를 먼저 배포하신 뒤 `redesign_unlink_device_v1` 을 어떤 경로로 연결할지 알려주세요.
4. 배포 후 실제 함수명·응답·오류코드가 2-2와 같은지 회신. 다르면 앱 저장소 한 파일만 고치면 됩니다.

---

## 3. 푸시 회신 §7 확인 요청 6건 답변

| # | 질문 | 앱 팀 답 |
|---|---|---|
| 1 | `ended` 를 구간 예약 off 명령에만 한정(A안)해도 되는지 | **A안 수용.** one-shot(분무·팬 `duration_ms`)은 `started` 만 보내주세요. 앱 알림은 "예약이 시작됐습니다"로 성립하고, 종료 알림은 구간 예약에서만 뜹니다. B·C안은 사용자 피드백 뒤 검토 |
| 2 | `execution_source` 의 `timer` 정의 | **이번엔 보내지 않습니다.** 지속시간이 붙은 즉시 제어는 `manual` 이 맞고 요청서의 "즉시 제어 제외"에 따라 푸시 대상이 아닙니다. 발행 조건은 `source = 'schedule'` 만. 앱 수신부 허용값에서 `timer` 는 제거하겠습니다 |
| 3 | `device_id` UUID + `device_key` TEXT 병기 | **수용.** `device_id` = UUID(조인 키), `device_key` = `terra-…` |
| 4 | `outcome` / `result` 이름 분리 | **수용.** `outcome` = `succeeded`/`failed`(앱 판정값), `result` = 펌웨어 원문. 성공 판정은 `result == "ok"` 만. 앱 수신부 검증기를 이 이름으로 바꾸겠습니다 |
| 5 | 가드 스킵(`guard`)도 알릴지 | **1차에서는 제외.** `started`/`ended`/`failed` 어디에도 맞지 않아, 2차에 `device.action.skipped` 타입으로 따로 정의하겠습니다. 발행 조건은 그대로 `source = 'schedule'` |
| 6 | 응답 없음(오프라인·ACK 유실) 실패 알림 | **필요합니다. 예약 발 명령에 한정.** 무인 실행에서 히터·팬이 안 꺼진 경우가 사용자에게 가장 중요한 알림입니다. 9/7 합의한 "sent 30초 만료" P1과 묶어, 만료 시 `device.action.failed` + `result = "no_ack"`(또는 서버가 쓰는 값)로 보내주세요. 수동 즉시 제어는 앱이 15초 ACK 유예 스낵바로 이미 처리하므로 제외 |

추가 확인:

- §4.4 TTL 만료·미등록 기기(`expired`/`rejected`)는 `failed` 로 보내주세요. SELECT 컬럼 확장은 서버 몫으로 이해했습니다.
- §2.4 기기 이름 캐시 TTL 동안 옛 이름이 나갈 수 있는 점은 수용합니다.
- 발행 지점·outbox는 제안 A(브리지 내 `push_outbox` + 워커 스레드)에 동의합니다.
- `PUSH_EVENT_INGEST_SECRET` 은 구현 착수 회신을 주시면 별도 채널로 전달합니다.

앱 팀 후속(회신 확인 뒤 착수): 수신 검증기 `_shared/notification-contract.mjs` 를 `execution_source = schedule`, `outcome`/`result` 분리, `device_id`+`device_key` 로 갱신하고 스테이징 3종(started/ended/failed) 검증.

---

## 4. 회신 부탁드리는 내용

1. §1-1 이름 규칙(대소문자 구분·10자·허용 문자 범위)으로 서버 제약을 맞추는 데 이견이 없는지
2. §2 초안 검토 결과 — 그대로 적용 / 수정 필요 항목 / terra-server·웹 경로 통합 방식
3. 소프트 해제(§2.5) 배포 예정 시점과 `unlink` 연결 경로
4. §3 답변으로 푸시 구현 규모·스테이징 시점이 정해지는지

## 5. 별도 대기 중

9/16에 보내드린 [LED 작동 시간·예약 payload 확인 요청](2026-09-16-server-request-led-timer-schedule-payload.md) 3건은 이 문서와 별개로 회신을 기다리고 있습니다.
