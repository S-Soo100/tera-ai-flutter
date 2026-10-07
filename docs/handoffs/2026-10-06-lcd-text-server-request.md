# LCD 문구 원문을 서버에 저장·조회할 수 있게 해 주세요 (terra-server 요청)

> **회신(2026-10-07):** `devices.lcd_text`·`lcd_text_updated_at` 추가, 기기 ok ACK 때 확정(terra-server `docs/BACKEND_HANDOFF_REPLY_LCD_TEXT_2026-10-07.md`). 운영 DB 마이그레이션 적용 확인, 서버 배포 완료(2026-10-07 사용자 확인, terra-server #18 `d84e1a7`). 앱 0.154.0에서 서버 값 우선 표시 반영. **실기기 검증 대기** — 배포 뒤 LCD 전송이 아직 없어 `lcd_text` 채워짐을 운영에서 못 봤다.

> 작성 2026-10-06 · 앱 비바나트 0.153.3 (389) · 계기: 고객 문의

## 현상 (고객 문의)

> "아까 바꿔놨었는데 LCD에는 아까 바꾼 이름이 나오는데 앱 표시창에는 다른 이름이 써있음"

LCD 자체는 기기에 저장돼 재부팅해도 유지되는데, 앱 홈 "LCD 표시" 줄은 기기 ID(`terra-…`)를 보여 줬습니다.

## 원인

서버에 **지금 LCD에 떠 있는 문구를 읽을 곳이 없습니다.**

- `POST /devices/{id}/lcd` `{text}` → 서버가 비트맵으로 렌더해 `commands`에 `lcd_bitmap`으로 넣습니다. payload는 `{h, w, enc, data}`뿐이고 **원문 텍스트가 남지 않습니다**(2026-10-06 운영 DB 최근 8건 확인).
- `devices`·`device_settings`에도 LCD 문구 컬럼이 없습니다.

앱은 보낸 문구를 앱 메모리에만 들고 있어서 앱을 다시 켜면 잊었습니다.

## 앱 임시 조치 (0.153.3, 배포 예정)

전송 성공한 문구를 **이 휴대폰에** 기기·계정별로 저장합니다(로그아웃 시 삭제). 같은 휴대폰에서는 재시작해도 맞게 보입니다.

남는 한계:
- 다른 휴대폰·웹 콘솔에서 바꾸면 이 휴대폰은 옛 문구를 보입니다.
- 앱 재설치·로그아웃 뒤엔 다시 기기 ID가 보입니다.
- 기기에 실제로 표시됐는지(`acked`)가 아니라 서버가 받았는지 기준입니다.

## 요청

1. **`/lcd` 요청 때 원문 텍스트를 저장해 주세요.** 위치는 서버 판단에 맡깁니다. 예: `devices.lcd_text`(text, nullable) + `lcd_text_updated_at`(timestamptz), 또는 `device_settings.lcd_text`.
   - `POST /devices/{id}/lcd/clear`이면 `null`로 바꿔 주세요.
   - 가능하면 기기가 ACK한 뒤(`commands.status = acked`) 값을 확정해 주세요. 어렵다면 요청 접수 시점이라도 괜찮습니다. 어느 쪽인지 알려 주세요.
2. **앱이 읽을 수 있게 해 주세요.** `devices`면 소유자 SELECT RLS가 이미 있으니 컬럼만 추가하면 되고, 앱은 기존 `devices` Realtime 구독으로 바로 반영합니다. `device_settings`면 `GET /devices/{id}/settings` 응답에 넣어 주세요.
3. 배포되면 알려 주세요. 앱은 서버 값을 우선 쓰고, 서버 값이 없을 때만 휴대폰 저장값 → 기기 ID 순으로 보이도록 바꾸겠습니다.

## 참고

- 앱 코드: `lib/features/my_cage/data/lcd_text_store.dart`(휴대폰 저장), `lib/features/my_cage/presentation/widgets/lcd_setting_tile.dart`(`lastLcdTextProvider`), 홈 줄 `HomeLcdRow`(`lib/features/home/presentation/home_screen.dart`).
- 입력 상한: 앱 20자, 서버 64자.
