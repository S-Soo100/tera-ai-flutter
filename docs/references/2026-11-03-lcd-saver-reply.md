# 회신 — LCD 요청서 (이관훈님, 2026-11-03)

- 질의: [`docs/handoffs/2026-11-03-lcd-quiet-manual-override-request.md`](../handoffs/2026-11-03-lcd-quiet-manual-override-request.md) — Slack DM으로 보냄(2026-11-03)
- 앱 반영: 기획서 `docs/superpowers/specs/2026-11-03-lcd-screen-settings-design.md` §12

## 1. 꺼짐 예약 중 수동 전원 조작

제안 규칙("예약 있으면 켜기/끄기는 다음 경계까지만, 없으면 sticky, 재부팅 유지")을 그대로 따르기로 함. 요청서 표의 4개 시나리오(21시 켬 / 21시 켬→22시 끔 / 23시 다시 끔 / 15시 예약 밖 끔) 모두 그대로 동작.

- **가능 여부·일정:** 가능. 펌웨어 OTA 필요. 대상은 **nano만** — 허브는 11/3부로 개발 중단이라 override가 허브에 안 들어간다. 작업 1~3일, Stage N 실기 검증이 끝나는 대로 시작.
- **API:** `PUT /lcd/power`는 `{on}` 그대로이고 의미만 바뀐다. 예약이 있으면 기기가 알아서 "다음 경계까지"로 처리하므로 `until_next_boundary` 같은 필드는 필요 없다. 구분은 `capabilities.lcd_override: true`, 없으면 지금 규칙(sticky).
- **실제 화면 상태:** 기기가 telemetry(3초)에 `lcd: {on, override_until}`을 싣고, 서버가 값이 바뀔 때만 `devices.lcd_screen_on` / `lcd_override_until`에 반영 → devices Realtime으로 받는다. 경계에서 자동으로 바뀌는 건 ack로 못 따라가서 telemetry로 간다. 오프라인이면 마지막 보고값이 남으니 "서버가 마지막으로 확인한 값"으로 그린다.
- **낮(예약 밖)에 끈 걸 아침 경계에서 켜도 되는지:** 표대로(20:00 경계에서 예약 규칙 → 08:00 켜짐)를 권함 — 규칙이 하나라 단순. 디자이너가 "낮에 끈 건 계속 꺼짐"을 원하면 "예약 밖 끄기만 sticky"로도 가능. 결론을 주면 맞춘다.

## 2. 확인 사항

- **서버 재배포:** 바로 가능, 배포 후 알려 주기로 함. 지금 규칙 기준 실기 확인은 그 직후 가능(override와 무관).
- **Realtime:** `devices`는 publication에 있고 UPDATE는 행 전체가 오므로 `lcd_*` 7개 컬럼이 모두 `payload.new`에 온다(RLS 본인 기기). 별도 설정 없음.
- **사진 실패 시 `lcd_image_key`:** 지적이 맞음. `dl_connect`/`dl_read`/`http_NNN`/`sha_mismatch`/`flash_write`면 기기엔 사진이 없는데 서버 key는 옛값이 남는다. 서버가 이 result를 받으면 key를 NULL로 비우도록 고친다(서버만, 이번 주). `busy`/`no_token`/`bad_request`는 지우기 전에 거절된 것이라 옛 사진·key 그대로가 맞고, `no_ack`(기기가 못 받음)도 옛 사진 유지. 기기가 사진 유무를 직접 보고하는 건 위 telemetry `lcd` 블록에 같이 넣는다.
- **사진 받는 중 다른 LCD 명령:** `lcd_image`가 또 오면 `busy`. `lcd_saver`/`lcd_power`/`lcd_quiet`는 다운로드가 별도 태스크라 바로 적용되고, 사진은 완료 후 다음 사이클부터 보인다. 앱에서 막아도 무해. 실기에서 같이 확인.
- **구 펌웨어 vs LCD 없는 빌드:** `capabilities`로 구분.
  - `hub == true` → 허브. `lcd == false`면 LCD 없음. 허브는 개발 중단이라 숨김 권장
  - `hub` 없음 && `lcd_saver != true` → nano 구 펌웨어(capabilities null 포함) → "기기 업데이트 후 쓸 수 있어요"
  - `lcd_saver == true` → 지원
- **시험 기기:** `terra-d9feaaa2`는 베타 테스트용이라 바로 쓰기 어렵다. 별도 보드를 쓸지 포함해 추후 정해서 알려 주기로 함.
