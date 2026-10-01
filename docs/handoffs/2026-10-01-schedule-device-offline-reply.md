# [앱 → 백엔드] 예약 실패 `device_offline` 회신 (terra-server#16)

원 요청: `docs/references/2026-10-01-schedule-device-offline.md`
앱 반영: 0.149.0+374 (2026-10-01, main)

## 앱이 반영한 것
- `device.action.failed` + `result == "device_offline"`이면 **앱 안에서 그리는 곳**의 문구를 바꿔요.
  - 앱을 쓰는 중 받은 알림, 받은 알림 목록: 요청서의 제목·본문 그대로. `device_name`이 없으면 "예약이 실행되지 않았어요".
  - 예약 목록의 마지막 실행: `commands`가 `status='skipped'`·`result='device_offline'`·`source='schedule'`이면 "실행 실패(기기 오프라인으로 건너뜀)".
- `result`·`device_name`·`action`은 알림 행 `data` 바로 아래, 또는 `data.payload` 아래에서 찾아요.

## 요청 1 — 푸시 제목·본문은 서버가 넣어 주세요
앱이 꺼져 있거나 백그라운드일 때는 **휴대폰이 FCM `notification`의 제목·본문을 그대로 띄우고, 앱 코드는 실행되지 않아요.** 그래서 앱 분기만으로는 대부분의 푸시가 일반 "실행 실패" 문구로 나가요.
`device_offline`일 때 서버가 아래 문구로 FCM `notification.title/body`와 알림 행 `title/body`를 채워 주세요.

| 항목 | 문구 |
|---|---|
| 제목 | `{device_name}` 예약이 실행되지 않았어요 (이름이 없으면 "예약이 실행되지 않았어요") |
| 본문 | 기기가 꺼져 있거나 연결이 끊겨 `{action_label}` 예약을 실행하지 못했어요. 전원과 Wi-Fi를 확인해 주세요. |

`action_label`(앱과 같은 이름):

| action | 이름 |
|---|---|
| mist | 분무 |
| fan_on / fan_off | 환기 켜기 / 환기 끄기 |
| fan2_on / fan2_off | 냉각팬 켜기 / 냉각팬 끄기 |
| heater_on / heater_off | 히터 켜기 / 히터 끄기 |
| led_on / led_off | 조명 켜기 / 조명 끄기 |

모르는 action이면 "`{action_label}` " 부분을 빼고 "…연결이 끊겨 예약을 실행하지 못했어요."로 써 주세요.

## 요청 2 — 묶지 말고 예약마다 보내 주세요
같은 기기라도 **예약 1건당 푸시 1건**으로 보내 주세요(앱 결정, 2026-10-01). 어떤 예약이 빠졌는지 하나씩 알아야 하기 때문이에요. 앱도 묶지 않고 받은 그대로 보여줘요.

## 요청 3 — 알림 행 `data`에 필드를 남겨 주세요
알림 목록에서 문구를 맞추려면 알림 행 `data`에 `result`·`device_name`·`action`이 있어야 해요(요청 1을 반영하면 서버 문구가 맞으니 필수는 아니에요).

## 확인 부탁
- 위 문구로 반영되면 배포 시점을 알려 주세요. 앱은 추가 배포 없이 그대로 맞아요.
