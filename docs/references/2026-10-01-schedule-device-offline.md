# [백엔드 → 앱] 예약 실패 사유 `device_offline` 추가 (terra-server#16)

## 언제 오나
예약 시각에 기기가 오프라인(`devices.is_online = false`)이면, 서버는 명령을 보내지 않고 바로 실패 푸시를 보내요.
지금까지는 명령을 보낸 뒤 30초 동안 응답이 없어 `no_ack`로 실패 처리됐어요. 앞으로 이 경우에는 `no_ack` 푸시가 따로 오지 않아요.

## 이벤트
기존 `device.action.failed` 그대로이고, 새 필드는 없어요.

```json
{
  "type": "device.action.failed",
  "payload": {
    "execution_source": "schedule",
    "execution_phase": "failed",
    "outcome": "failed",
    "result": "device_offline",
    "action": "mist",
    "device_name": "거실 사육장",
    "schedule_id": "…", "command_id": "…", "device_id": "…", "enclosure_id": "…"
  }
}
```

## 요청
`result == "device_offline"`일 때 아래 문구로 분기해 주세요.

| 위치 | 문구 |
|---|---|
| 푸시 제목 | `{device_name}` 예약이 실행되지 않았어요 |
| 푸시 본문 | 기기가 꺼져 있거나 연결이 끊겨 `{action_label}` 예약을 실행하지 못했어요. 전원과 Wi-Fi를 확인해 주세요. |
| 실행 기록(감사 로그) 한 줄 | 기기 오프라인으로 건너뜀 |

- `{action_label}`은 앱에서 이미 쓰는 액션 이름(분무, 조명 켜기 등)을 그대로 써 주세요.
- `device_name`이 없으면 제목을 "예약이 실행되지 않았어요"로 써 주세요.
- 실행 기록에는 `commands` 행이 `status='skipped'`, `result='device_offline'`, `source='schedule'`로 남아요. 가드로 건너뛴 기록은 `source='guard'`이니 그걸로 구분하면 돼요.

## 참고
- 기기가 오프라인이 되면 오프라인 알림이 이미 한 번 가요. 그다음 예약 시각마다 이 푸시가 예약 1건당 1개씩 와요. 묶어서 보여줄지는 앱에서 정해 주세요. 예를 들어 같은 기기는 최근 N분 동안 1건만 보여줄 수 있어요.
- 이 분기가 들어가기 전까지는 일반 "실행 실패" 문구로 보여요. 그래서 앱 배포와 상관없이 서버를 먼저 반영해도 괜찮아요.
