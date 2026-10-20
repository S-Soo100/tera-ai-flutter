# IoT 기기(사육장 보드) 원격 재부팅 — 앱 사용 가이드

> **대상**: 앱(Flutter, vivanaut) 개발
> **작성**: terra-server 백엔드, 2026-10-03
> **기준 코드**: terra-server `main` (`a118ea9`). 서버 변경 없이 현재 API 그대로 사용
> **정본**: `docs/API.md` §3.7-b · 상세 배경은 [APP_DEVICE_REBOOT_SYS_STATE_2026-09-28.md](APP_DEVICE_REBOOT_SYS_STATE_2026-09-28.md)
> **대상 기기**: terra-iot-nano / supermini (조명·팬·펌프 붙은 사육장 보드). 카메라는 [GUIDE_CAMERA_REBOOT_APP_WEB_2026-10-03.md](GUIDE_CAMERA_REBOOT_APP_WEB_2026-10-03.md)
> **10/3 서버 버그와 무관**: 오늘 고친 "발행 성공을 실패로 처리하던 버그"(`d25151d`)는 카메라 경로에만 해당합니다. IoT 기기 재부팅은 `commands` 큐 + dispatcher 경로라 9/28부터 정상이었습니다.

---

## 0. 한눈에

| 항목 | 내용 |
|---|---|
| API | `POST https://api.terra-server.uk/devices/{device_uuid}/reboot` |
| 인증 | `Authorization: Bearer <Supabase access_token>` |
| 본문 | 없음 |
| 동작 | 서버가 `commands` 에 `action: "reboot"` 1건을 `pending` 으로 넣음(TTL 60초) → 브리지가 1초 안에 발행 |
| 기기 | 신 펌웨어: ack(`result: "ok"`) 를 먼저 보내고 **1.5초 뒤 재부팅**. 펌프·팬·조명은 전부 OFF 로 켜짐 |
| 자동 복원 | 재부팅 후 첫 telemetry 에서 서버가 예약상 지금 켜져 있어야 할 조명·팬·냉각팬을 다시 켬(§5) |
| 완료 판정 | `commands.result == "ok"` → `devices.sys_state.reset == "SW:mqtt_reboot"` + `uptime_s` 작아짐 |
| 쓰는 상황 | 온라인인데 명령에 반응이 없거나 동작이 이상한 기기 |

> `device_uuid` 는 `devices.id`(UUID) 입니다. `device_id`(`terra-xxxx` 같은 문자열)가 아닙니다.

---

## 1. API 계약

```
POST /devices/{device_uuid}/reboot
Authorization: Bearer <JWT>
(본문 없음)

201 { "id": "<commands.id>", "action": "reboot", "status": "pending" }   → 큐잉됨
401                                                                        → 토큰 없음/만료
404 { "detail": "device not found" }                                       → 타인 기기 · 등록 해제된 기기 · 없는 UUID
500 { "detail": "command INSERT 실패" }                                    → DB 순간 장애 (드묾). 잠시 후 재시도
```

- 응답 모양은 `POST /devices/{id}/mist` 와 같습니다(`CommandOut`).
- 응답의 `id` 로 **`commands` Realtime 을 구독**해 결과를 봅니다. 분무 결과 보는 방식과 같습니다.
- `201` 은 "큐에 들어갔다"는 뜻이지 "기기가 받았다"는 뜻이 아닙니다.

### 카메라 재부팅과 다른 점

| | IoT 기기 | 카메라 |
|---|---|---|
| 경로 | `commands` 테이블 → dispatcher | MQTT 직접 1회 발행 |
| 응답 | `201` + `commands.id` | `200` + `published` / `msg_id` |
| 결과 추적 | **가능** — `commands` Realtime 으로 `acked`/`no_ack` + `result` | 불가 — 하트비트로만 판정 |
| 상태 필드 | `devices.sys_state` | `cameras.clip_stats.sys` |
| 신 펌웨어 판별 | `sys_state != null` | `firmware_ver ≥ 0.2.0` |

---

## 2. 결과 판정 (`commands` Realtime)

명령 행은 `pending → sent → acked` 또는 `→ no_ack` 로 흐릅니다.

| 관측 | 뜻 | 앱 처리 |
|---|---|---|
| `status: "acked"`, `result: "ok"` | 기기가 받았고 1.5초 뒤 재부팅함 | "재시작 중…" 유지, §3 완료 신호 대기 |
| `status: "acked"`, `result: "unknown_action"` | **구 펌웨어**. 재부팅 안 됨 | "기기 펌웨어 업데이트가 필요해요" |
| `status: "no_ack"` | 30초 동안 응답 없음(오프라인·WiFi 끊김) | "기기가 응답하지 않아요. 전원과 WiFi 를 확인해 주세요" |

⚠️ **`status == "acked"` 만 보고 성공 처리하지 마세요.** 구 펌웨어도 `acked` 로 옵니다. 성공은 반드시 `result == "ok"` 입니다.

- 재부팅 명령은 `source: "manual"` 이라 **실패 푸시(`device.action.failed`)는 나가지 않습니다**. 실패 안내는 앱이 화면에서 직접 합니다.
- 서버는 **온라인 여부를 확인하지 않고** 큐잉합니다(오프라인 스킵은 예약 명령에만 적용). 오프라인 기기에 누르면 30초 뒤 `no_ack` 가 됩니다.
- **연타 방지도 서버가 하지 않습니다.** 누를 때마다 명령이 1건씩 쌓입니다.

---

## 3. 완료 판정 (`devices` Realtime)

ack 후 기기가 재부팅하고 다시 telemetry 를 보내면 `devices` 행이 UPDATE 됩니다.

```json
"sys_state": { "uptime_s": 8, "reset": "SW:mqtt_reboot", "heap": 190000, "rssi": -62 }
```

- **`sys_state.reset == "SW:mqtt_reboot"` 이고 `uptime_s` 가 직전 값보다 작으면** 재부팅 완료.
- 소요 시간: ack 후 1.5초 + 부팅·WiFi·MQTT 재접속. 카메라 실측(약 12초)과 같은 경로라 **10~20초**로 예상합니다(실기 측정값 아직 없음).
- 오프라인 판정 임계는 180초라 정상 재부팅 중에 `is_online` 이 `false` 로 바뀌지 않습니다.

---

## 4. 사용자 체험 흐름 (9/28 앱 회신으로 확정된 UX)

```
[화면]  기기 상세 — 온라인, "기기 재시작" 버튼
[조작]  버튼 탭
[반응]  확인 다이얼로그
        "기기가 약 20초 동안 꺼졌다 켜집니다. 켜져 있던 펌프·팬·조명은 모두 꺼집니다."
        [취소] [재시작]
[조작]  [재시작]
[반응]  POST 201 → 버튼 "재시작 중…" (비활성, 스피너)
[대기]  약 1초 — commands Realtime: acked + result=ok
[대기]  약 10~20초
[반응]  devices Realtime: sys_state.reset=SW:mqtt_reboot + uptime_s 감소
        → 토스트 "기기가 다시 켜졌어요" · 버튼 원상복귀
[반응]  곧이어 예약으로 켜져 있어야 할 조명·팬이 자동으로 다시 켜짐(§5)
[예외]  result=unknown_action → "기기 펌웨어 업데이트가 필요해요" (버튼 즉시 활성화)
[예외]  no_ack → "기기가 응답하지 않아요. 전원과 WiFi 를 확인해 주세요" (버튼 즉시 활성화)
[예외]  ack 후 60초 지나도 완료 신호 없음 → "재시작 확인이 늦어지고 있어요. 잠시 후 상태를 확인해 주세요."
[예외]  404/500 → "잠시 후 다시 시도해 주세요" (버튼 즉시 활성화)
```

### 버튼 상태 규칙

| 조건 | 버튼 |
|---|---|
| `is_online == false` | 숨김 또는 비활성 ("기기가 오프라인이에요") |
| `sys_state == null` (구 펌웨어) | 숨김 — 눌러도 반응이 없어 혼란 |
| 요청 후 ~ 완료 감지 / 실패 / 60초 | 비활성 "재시작 중…" |
| 그 외 | 활성 |

- 구 펌웨어 판별은 **`sys_state == null`** 로 하세요. 기기는 `firmware_ver` 를 페어링 때만 보내서 버전 문자열로는 판별할 수 없습니다.
- `is_online == false` 면 `sys_state` 는 마지막 값이 그대로 남아 있습니다.

---

## 5. 재부팅 후 예약 상태 자동 복원 (앱 할 일 없음)

재부팅하면 액추에이터가 전부 OFF 로 켜집니다. 서버가 재부팅을 감지하면 활성 예약을 보고 **지금 켜져 있어야 할 것만** ON 명령을 1회 넣습니다. 원격 재부팅뿐 아니라 정전·브라운아웃·크래시 재부팅에도 동작합니다.

| 복원함 | 복원 안 함 |
|---|---|
| 조명(`led_on`, 밝기 포함) · 팬(`fan_on`) · 냉각팬(`fan2_on`) | 분무(1회성) · 펌프(`relay_on`, 침수 위험) · 토글 예약 · 타이머(`duration_ms`) 예약 · 히터 |

- 예약의 `skip_when_*` 조건은 복원에도 적용됩니다. 원래 시각에 스킵됐을 조건이면 지금도 켜지 않습니다.
- 복원 명령은 `commands.source == "restore"`, `reason == "reboot_restore"` 로 이력에 보입니다. "재부팅 후 자동 복원"으로 표시하면 좋고 그냥 두어도 됩니다. 푸시는 나가지 않습니다.
- **수동으로 켠 것(예약 아닌 것)은 복원되지 않습니다.** 필요하면 다이얼로그 문구에 "직접 켠 장치는 다시 켜 주세요"를 넣어도 됩니다.

---

## 6. 테스트 체크리스트

| # | 시나리오 | 기대 |
|:---:|---|---|
| 1 | 신 펌웨어 · 온라인 기기에서 재시작 | 201 → `acked`/`ok` → 10~20초 뒤 `reset=SW:mqtt_reboot` |
| 2 | 예약으로 조명 켜진 시간대에 재시작 | 재부팅 후 조명 자동 ON, 이력에 `source=restore` 행 |
| 3 | 구 펌웨어 기기 | 버튼 숨김. 직접 API 호출 시 `acked`/`unknown_action`, 재부팅 안 됨 |
| 4 | 전원 뽑은 기기 (`is_online` 이 아직 true 인 3분 안) | 30초 뒤 `no_ack` → 응답 없음 안내 |
| 5 | 연타 | 첫 요청 후 버튼 비활성, 두 번째 요청 안 나감 |
| 6 | 타인 기기 UUID | 404 |

신 펌웨어 기기 목록이 필요하면 백엔드에 요청해 주세요. 웹 콘솔 기기 목록에서 `sys_state` 가 찍히는 기기가 신 펌웨어입니다.
