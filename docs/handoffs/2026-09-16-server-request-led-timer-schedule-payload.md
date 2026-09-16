# 서버·펌웨어 확인 요청 — LED 작동 시간, 예약 payload(밝기·작동 시간)

- 작성: 2026-09-16, 비바나트 앱팀 (Claude 초안, 전송은 사용자)
- 대상: 이관훈님 (terra-server · terra-iot 펌웨어)
- 배경: 2026-09-16 UI 검수 결정으로 앱이 아래 세 가지를 **서버 확인 전에 미리 구현**했습니다(앱 `0.107.50+261`). 지원되지 않으면 사용자에게 보이는 결과가 어긋나므로, 각 항목의 **지원 여부·정확한 동작·미지원 시 응답**을 회신 부탁드립니다. 회신 전까지 앱은 아래 payload를 그대로 보냅니다.

## 1. `led_on` + `payload.duration_ms` — LED 작동 시간(자동 꺼짐)

- 앱 동작: 홈 LED 시트 "작동 시간" 30분 / 1시간 / 2시간 / 3시간 / 계속. 시간을 고르고 켜면 아래처럼 보냅니다. "계속"은 `duration_ms` 없음.

```json
// commands INSERT
{ "action": "led_on", "payload": { "brightness": 60, "duration_ms": 3600000 } }   // MOSFET 보드
{ "action": "led_on", "payload": { "duration_ms": 10800000 } }                    // 릴레이 보드(밝기 없음)
```

- 기대: 팬 타이머(`fan_on` + `duration_ms`, 2026-08-14 §1.3)와 같은 구조로 **펌웨어가 시간 뒤 스스로 `led_off`** 합니다. 취소는 `led_off`.
- 확인 요청:
  1. `led_on`에서 `duration_ms`를 펌웨어가 처리합니까? 처리하면 상한(팬은 2h)은 얼마입니까? 앱은 최대 3시간(10,800,000ms)을 보냅니다.
  2. 팬 타이머가 도는 중 LED 타이머를 걸면 `busy`("이미 분무/타이머 진행 중 → 무시")에 걸립니까? 타이머 슬롯이 액추에이터별입니까, 기기당 하나입니까?
  3. 미지원이면 `result`가 `bad_request`/`unknown`으로 오는지, 아니면 `duration_ms`를 무시하고 켜기만 하는지(그러면 앱은 "시간이 지나도 안 꺼짐"을 알 수 없습니다).
  4. `telemetry.led`가 자동 OFF 뒤 `OFF`로 바뀌는지(앱은 텔레메트리로만 상태를 그립니다).

## 2. `schedules.payload.brightness` — LED 예약의 밝기

- 앱 동작: LED 예약 편집기(시작/종료)에 밝기 행(20~100%, 기본 50)이 있고 **켜기 행에만** 싣습니다.

```json
// POST /devices/{id}/schedules  (pair_id로 묶인 두 건 중 켜기 행)
{ "action": "led_on",  "kind": "daily", "time_of_day": "20:00", "pair_id": "<uuid>", "payload": { "brightness": 50 } }
{ "action": "led_off", "kind": "daily", "time_of_day": "23:00", "pair_id": "<uuid>" }
// PATCH /schedules/{id}  (밝기 수정)
{ "kind": "daily", "time_of_day": "20:00", "days_of_week": null, "payload": { "brightness": 70 } }
```

- 확인 요청:
  1. POST/PATCH가 `payload.brightness`를 저장하고 GET이 돌려줍니까? (2026-08-12 질문 4 "schedules.payload가 mist의 duration_ms 외 다른 키도 통과시킵니까?"의 후속입니다.)
  2. 예약 실행 시 `commands.payload`에 그대로 실려 `led_on` + `brightness`로 발행됩니까?
  3. 릴레이 보드(`led_dimmable=false`)에 저장된 brightness는 무시됩니까, 400입니까? 앱은 무시(켜기만)를 기대합니다.

## 3. `schedules.payload.duration_ms` — 냉각팬 예약의 작동 시간

- 앱 동작: 냉각팬 예약은 "시작 + 30분/1시간/2시간 뒤 종료"를 **`fan2_on` 한 건 + `duration_ms`** 로 저장합니다(이전 구현은 `fan2_on`/`fan2_off` pair). 기존 pair 예약은 그대로 표시·수정합니다.

```json
{ "action": "fan2_on", "kind": "weekly", "time_of_day": "12:00", "days_of_week": [6, 7], "payload": { "duration_ms": 1800000 } }
```

- 기대: 예약 실행 시 `fan2_on` + `duration_ms`로 발행되고 펌웨어가 시간 뒤 자동 OFF(팬 타이머와 동일). `fan_on`(환기팬)에도 같은 확장이 되면 앱이 환기팬 예약에도 쓸 수 있습니다.
- 확인 요청:
  1. `schedules.payload.duration_ms`를 `fan2_on`/`fan_on` 실행에 그대로 전달합니까?
  2. 미전달이면 예약이 켜기만 하고 영영 안 꺼집니다 — 그 경우 앱을 pair 방식으로 되돌려야 하니 꼭 알려주세요.

## 4. 참고 (재확인)

- 펌웨어 `devices.capabilities`(`led_dimmable`) 보고: 앱은 이 값으로 홈 LED 시트의 밝기 행을 노출합니다. 아직 전 기기가 `relay`로 백필된 상태라 MOSFET 기기도 밝기 행이 안 뜹니다(2026-08-18 회신 §2 후속).

## 5. 앱 측 대응 (회신 뒤)

| 회신 | 앱 |
|---|---|
| 1 지원 | 그대로 사용, 진행 칩(남은 시간)·로컬 알림을 팬과 같이 붙임 |
| 1 미지원 | "작동 시간" 칩 제거 또는 비활성 + 안내 |
| 2 지원 | 그대로 |
| 2 미지원 | 편집기 밝기 행 제거(예약은 켜기/끄기만) |
| 3 지원 | 그대로 |
| 3 미지원 | 냉각팬 예약을 pair 방식으로 복귀(코드 보존됨) |
