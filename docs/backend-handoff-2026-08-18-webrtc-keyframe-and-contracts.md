# 백엔드/펌웨어 핸드오프 — 카메라 첫 프레임 지연 + 제어 계약 보강 (2026-08-18)

> ## 📌 회신 받음 — 같은 날 §2~§6 백엔드 구현·배포 완료, 앱 반영 완료 (2026-08-18)
> 회신 원문: `docs/backend-reply-2026-08-18-app-delivery.md`. 결정: §2 `devices.capabilities` JSONB(`board`/`led_dimmable`, 구 행은 relay 백필·펌웨어 보고는 미구현), §3 `schedules.pair_id`(앱 UUID, 한 건 삭제 시 짝 삭제), §4 `telemetry.led`/`led_brightness`, §5 `GET/PATCH /devices/{id}/settings`(미설정=전부 null 200), §6 예약 `*_toggle` 400 + **추가로 off+guard 400**. §1 카메라는 **보류** — esp_video 2.2.0이 force-key-frame 컨트롤 미지원, 선택지(esp_video 업그레이드 / GOP 축소 / 라이브 인코더 분리)는 하드웨어 담당 결정 대기.
> 앱 반영 커밋: `5a16bf1`(§2·§4) · `598c9a4`(§3) · `0c83a74`(§5). 원문 §0~§8은 요청 그대로 둔다.

> **대상**: terra-server / ESP32-P4 카메라 펌웨어(`FB2_P4_CAM`) / terra-iot-nano 담당자
> **배경**: 2026-08-14 핸드오프(`docs/backend-handoff-2026-08-14-summary.md`)로 받은 계약(on/off 절대 명령·팬 타이머·구간 예약·스킵형 가드·LCD·`commands.source`)은 **앱에 전부 반영 완료**했습니다. 그 위에서 앱 쪽 코드로는 풀 수 없고 백엔드·펌웨어 변경이 있어야 하는 항목만 추립니다.
> **근거**: 앱 코드 정적 분석 + `[webrtc-timing]` 실측 로그(2026-07-19) + Supabase 실 DB 스키마(`docs/supabase-schema.md`)
> 관련 문서: `APP_WEBRTC.md`, `APP_INTEGRATION.md`, `APP_TIMER_MIST.md`, 앱 기획서 `docs/prd-vivnanaut-app.md`
>
> ⚠️ **이 문서에서 다루지 않는 것**: nano 펌웨어 플래시(물분무 duration·팬 타이머·LED 밝기·LCD), 정지형 가드, 히터 타이머 — 별도 트랙으로 진행 중이라 제외. 한글 LCD 폰트도 제외.

---

## 0. 요약 (TL;DR)

| # | 요청 | 담당 | 없으면 생기는 일 | 우선순위 |
|---|---|---|---|---|
| 1 | **카메라 연결 시 IDR 키프레임 즉시 송출** (택1: IDR-on-connect / PLI·FIR 존중 / GOP 단축) | P4 카메라 펌웨어 | 라이브 연결은 1.3초인데 **첫 화면까지 18초 검은 화면**. 사용자는 "매우 느림"으로 인식 | **최상** |
| 2 | **`devices`에 보드 타입 필드** (릴레이 / MOSFET) | 백엔드 | `led_on`+`brightness` 계약이 있어도 앱이 어느 기기에 밝기 UI를 켤지 몰라 **전부 on/off로 묶어둠** | 높음 |
| 3 | **구간 예약의 쌍 개념** (`end_time_of_day` 또는 `pair_id`) | 백엔드 | 앱이 on/off 2건으로 만들지만 서버엔 쌍이 없어 목록에 낱개로 뜨고, 한쪽만 지우면 **고아 예약**(켜지기만 하고 안 꺼짐) | 높음 |
| 4 | **액추에이터 실행 상태 피드백** — 특히 LED 상태 텔레메트리 | 백엔드 + nano 펌웨어 | `acked`는 "받았다"지 "켜졌다"가 아님. LED는 상태 컬럼 자체가 없어 앱이 **로컬 추측**으로 표시 중 | 중간 |
| 5 | **`device_settings` setpoint 계약 + 시딩** | 백엔드 | 전 디바이스 비어 있어 목표 온습도가 **앱 하드코딩 상수** | 중간 |
| 6 | **예약 화이트리스트에서 `*_toggle` 제거** | 백엔드 | 무인 실행에서 toggle은 상태 어긋남 → 히터면 과열. 앱은 이미 선택 불가로 막았으나 서버가 거부하는 게 안전 | 낮음(방어) |

---

## 1. 요청 1 — 카메라 첫 프레임 18초 (P4 카메라 펌웨어)

### 현상 (실측)

`webrtc_live_controller.dart`의 `[webrtc-timing]` 로그, 2026-07-19, 같은 Wi-Fi P2P:

| 구간 | 실측 | 판정 |
|---|---|---|
| `config` (REST) | 15~238ms | 정상 |
| `answer` (시그널링) | 787~918ms | 정상 |
| `connected` (ICE) | **1.24~1.36초** | 정상 — TURN 불필요 |
| `firstFrame` (첫 디코딩) | **19,573ms** | ⚠️ connected 후 **약 18초** 검은 화면 |

연결 자체는 빠릅니다. 문제는 **연결 후 첫 그림이 나오기까지**입니다.

### 원인

새 WebRTC peer가 붙을 때 카메라가 **IDR(키프레임)을 즉시 보내지 않습니다.** 뷰어는 다음 정기 키프레임까지 P-프레임만 받고, P-프레임은 참조 프레임 없이는 디코드가 안 되므로 그때까지 화면이 검습니다. 실측 18초 = 현재 GOP 길이로 추정됩니다.

`APP_WEBRTC.md` 계약에는 **keyframe-on-connect 의무 자체가 없습니다** — 빠진 조항입니다.

### 앱에서 못 하는 이유

- flutter_webrtc 수신측은 RTCP **PLI/FIR을 자동 전송**하지만, 송신측(카메라)이 무시하면 방법이 없습니다.
- 수신측에 "강제 키프레임 요청" 공개 API가 없습니다.
- 앱이 할 수 있는 건 체감 완화뿐 — 이미 적용됨: 첫 프레임 전 포스터(motion_clips 최신 썸네일)·config 캐시·renderer 병렬화.

### 요청 (택1, 위가 정공법 — ①+② 겸하면 이상적)

| 안 | 내용 | 효과 | 비고 |
|---|---|---|---|
| **① IDR-on-connect** | 새 `webrtc_offer` 처리 또는 peer `connected` 시점에 인코더에 IDR 1회 강제 | 첫 프레임 ~0.1초. 대역폭 영향 없음 | ESP32-P4 H.264 HW 인코더는 IDR 강제 API가 있음(esp_h264 계열 force-IDR/GOP 설정) |
| **② RTCP PLI/FIR 존중** | 뷰어가 보내는 PLI/FIR 수신 시 IDR 생성 | 표준 방식. 패킷 손실 복구도 같이 개선 | 다중 뷰어에서 IDR 폭주 방지용 최소 간격(예: 1초) 권장 |
| ③ GOP 단축 | 키프레임 주기 1~2초 | 최악 대기 1~2초. 대역폭 소폭 증가 | 근본 해결은 아님. ①②가 어려울 때 임시 |

### 계약 요청

`APP_WEBRTC.md`에 다음 조항 명문화 부탁드립니다:
> 카메라는 새 peer 연결 완료 시 **1초 이내 IDR을 송출**하고, RTCP PLI/FIR을 존중한다.

### 검증 기준

앱 계측 코드는 상주해 있습니다. 반영 후 `[webrtc-timing] ... firstFrame=` 값에서 **`firstFrame − connected < 1000ms`** 이면 해결로 봅니다. 재현 시 4값(config/answer/connected/firstFrame)으로 앱·펌웨어·NAT 어디 문제인지 바로 갈립니다.

---

## 2. 요청 2 — 보드 타입 구분 필드 (백엔드)

### 현재

- 8-14 계약: `led_on` + `{brightness: 0~100}` — **MOSFET 보드만** 실제 밝기 조절, 릴레이 보드는 `brightness` 무시.
- 계약 문서도 "보드 타입 구분 필요 시 백엔드에 문의"라고 적혀 있습니다.
- `devices` 테이블 현재 컬럼: `id / owner_id / enclosure_id / name / is_online / last_seen_at` — **보드 타입을 알 수 있는 컬럼이 없습니다.**

### 앱 현재 조치

밝기 슬라이더를 걷어내고 **켜기/끄기만** 노출 중입니다. 릴레이 보드 사용자에게 효과 없는 슬라이더를 보여줄 수 없어서입니다. 필드가 생기면 MOSFET 기기에서만 슬라이더를 되살립니다.

### 요청

```sql
ALTER TABLE devices ADD COLUMN board_type TEXT;  -- 'relay' | 'mosfet'
-- 또는 capabilities JSONB: {"led_dimmable": true, "heater": false, ...}
```

- 값은 페어링/등록 시 펌웨어 또는 운영자가 세팅. 기존 행은 `'relay'`로 백필.
- `capabilities` JSONB 방식이면 **히터 미탑재 보드** 구분(§1.3 "히터 타이머 미지원")도 같은 필드로 풀립니다 — 앱이 히터 타일을 아예 숨길 수 있습니다. 이쪽을 권합니다.
- 결정되면 알려주세요. 앱은 `Device` 모델에 필드 하나 추가하는 수준입니다.

---

## 3. 요청 3 — 구간 예약의 쌍 개념 (백엔드)

### 현재

- 8-14 계약: 구간(시작~종료) 예약은 **on/off 2건으로 구성**. 앱은 이대로 구현했습니다(`ScheduleRepository.addSpan` — off 생성 실패 시 on 롤백).
- 서버에 쌍 개념이 없어 생기는 문제:
  1. `GET /schedules` 목록에 **낱개 2건**으로 뜬다 → 앱이 "구간"으로 재조립할 근거가 없음
  2. 사용자가 웹 콘솔·다른 클라이언트에서 **on만 지우면** off가 고아로 남고, **off만 지우면 켜지기만 하고 안 꺼짐** → 히터·팬에서 위험
  3. 가드를 on쪽에만 걸었는데(스킵되면 켜지지 않음) off는 무조건 나감 — 무해하지만 로그에 의미 없는 off가 쌓임

### 요청 (택1)

| 안 | 내용 | 장점 |
|---|---|---|
| **A. `end_time_of_day`** | `schedules`에 `end_time_of_day "HH:MM"` 추가. 서버가 시작에 `*_on`, 종료에 `*_off` 발행 | 1행=1구간. 삭제·토글이 원자적. UX 최선. 8-12 회신에서 백엔드도 "UX상 더 낫다" 동의 |
| B. `pair_id` | on/off 2행에 같은 `pair_id`. 한쪽 삭제 시 서버가 짝도 삭제 | 스키마 변경 최소 |

A를 권합니다. A가 되면 앱은 `addSpan`을 단건 POST로 갈아타고 목록도 구간 한 줄로 그립니다.

---

## 4. 요청 4 — 액추에이터 실행 상태 피드백 (백엔드 + nano 펌웨어)

### 현재

- 명령 흐름 `pending → sent → acked(result)` 는 잘 옵니다. 다만 `acked` + `result: ok`는 "펌웨어가 명령을 받아 처리했다"이지, **"지금 켜져 있다"는 상태**가 아닙니다.
- `telemetry`에는 `relay / fan / heater_state / heater_locked` 는 있는데 **LED 상태 컬럼이 없습니다.** 앱은 LED를 `_ledOn` 로컬 플래그(낙관적 업데이트)로 표시 중이라 앱 재시작·다기기·예약 실행 뒤에는 **실제와 어긋납니다.**
- 기획서(§5)는 "제어 결과를 사용자에게 알린다(안심용)"를 요구합니다.

### 요청

1. **`telemetry`에 `led` 상태 추가** (`ON/OFF`, MOSFET이면 `led_brightness` 0~100도). 기존 `relay/fan/heater_state`와 같은 방식이면 앱은 파서 한 줄입니다.
2. (선택) 명령 `acked` 시 `result` 옆에 **적용 후 상태 스냅샷**(`payload_result: {"fan":"ON"}` 등)이 오면 다음 텔레메트리(30초~) 기다리지 않고 즉시 확정 표시할 수 있습니다.

---

## 5. 요청 5 — `device_settings` setpoint (백엔드)

### 현재

- `device_settings`가 **전 디바이스 비어 있어**(2026-07 조회) 앱은 목표 온습도를 **하드코딩 상수**로 표시합니다(`module_status_card.dart` "setpoint 연동은 별도 후속" 주석). 안심존은 종 care_info로 자동 도출해 대체 중.
- 목표값이 서버에 없으니 정지형 가드(히터 목표온도 도달 시 OFF)가 생겨도 **비교할 목표가 없습니다.** 정지형 가드 착수 전에 이게 먼저 있어야 합니다.

### 요청

- `device_settings` 계약 확정: 최소 `target_temp_c`, `target_humidity_pct`, (권장) `temp_min/max`, `humidity_min/max`.
- 읽기/쓰기 경로 — REST(`GET/PATCH /devices/{id}/settings`) 또는 직결 + RLS. **쓰기를 REST로 두면** 서버가 값 범위를 검증하고 펌웨어에 내려보내는 걸 한 곳에서 처리할 수 있어 REST를 권합니다.
- 초기값: 사육장에 연결된 개체의 종 care_info로 시딩하면 앱과 같은 값이 됩니다.

---

## 6. 요청 6 — 예약 화이트리스트에서 `*_toggle` 제거 (백엔드, 방어)

- 8-14 계약의 `schedules.action` 허용값에 `relay_toggle / heater_toggle / led_toggle / fan_toggle`이 **아직 남아 있습니다.**
- toggle은 기기의 현재 상태를 전제하는데, 예약은 무인 실행이라 그 전제가 어긋나도 아무도 못 봅니다. 히터면 **끄려던 예약이 켜서 과열**.
- 앱은 예약 편집기에서 **절대 명령만 selectable**로 이미 막았습니다. 다만 다른 클라이언트·웹 콘솔은 못 막으니 **서버가 예약 생성 시 `*_toggle`을 400으로 거부**하는 게 안전합니다.
- 기존 DB에 toggle 예약이 있으면 알려주세요 — 앱 목록은 깨지지 않게 해뒀지만, 히터 toggle 예약이 살아 있으면 정리가 필요합니다.

---

## 7. 회신 체크리스트

- [ ] **§1** 카메라 IDR: 어느 안(①/②/③)으로, 언제 플래시되나. `APP_WEBRTC.md` 조항 추가 여부
- [ ] **§2** `devices` 보드 타입: `board_type` vs `capabilities` 택1 + 백필 값
- [ ] **§3** 구간 예약: `end_time_of_day` vs `pair_id` 택1
- [ ] **§4** `telemetry.led` 추가 여부 (+ MOSFET `led_brightness`)
- [ ] **§5** `device_settings` 컬럼·경로 확정
- [ ] **§6** 화이트리스트 toggle 제거 여부 + 기존 toggle 예약 유무

## 8. 앱 측 후속 (회신 오면 바로)

| 회신 항목 | 앱 변경 |
|---|---|
| §1 | 없음 — 계측 로그로 검증만 |
| §2 | `Device` 필드 1개 + LED 밝기 슬라이더 조건부 복원 + 히터 타일 조건부 숨김 |
| §3 | `addSpan` → 단건 POST, 목록을 구간 1행으로 |
| §4 | 텔레메트리 파서 1줄 + `_ledOn` 로컬 플래그 제거 |
| §5 | `module_status_card` 상수 → provider, 사육장 설정에 목표값 편집 |
| §6 | 없음 (이미 막아둠) |
