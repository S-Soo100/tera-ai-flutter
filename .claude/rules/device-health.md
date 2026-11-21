---
paths:
  - "lib/features/my_cage/**/sys_health*.dart"
  - "lib/features/my_cage/data/camera_repository.dart"
  - "lib/features/my_cage/data/device_health_repository.dart"
  - "lib/features/my_cage/presentation/my_cage_providers.dart"
  - "lib/features/my_cage/presentation/supabase_module_providers.dart"
  - "lib/features/my_cage/presentation/device_detail_screen.dart"
  - "lib/features/my_cage/presentation/widgets/camera_rotate_tile.dart"
  - "lib/features/my_cage/presentation/widgets/webrtc_live_view.dart"
  - "lib/features/profile/presentation/device_reboot_screen.dart"
---
# 재시작·Wi-Fi 약함·카메라 회전 규칙

경위·수치·날짜: `docs/contracts/device-health.md`, `docs/contracts/camera-rotate.md`.

## heartbeat
- heartbeat 값(`clip_stats`·`sys_state`)을 목록 provider(`camerasProvider`·`deviceListProvider`)에 넣지 않는다(홈이 깜빡인다). 상세를 보는 동안만 `sysHealthProvider`.
- 재시작 완료를 기다리는 heartbeat 구독은 **누른 뒤에만** 연다. `rebootProvider`는 진행 중 `keepAlive`, 끝나면 놓는다.
- REST `GET /cameras`에는 `clip_stats`·`rotate_180`·`capabilities`가 빠져 있다. 읽기는 직결.
- 진단 필드(`last_err`·`up_fail` 등)는 앱에 표시하지 않는다.

## 재시작
- 흐름은 `rebootProvider`·`confirmAndRequestReboot`·`listenRebootOutcome`을 공용으로 쓴다. 발행 뒤 60초는 다시 누르지 못하게 하고, 2분 무소식이면 전원 재연결을 안내한다.
- 카메라: REST `POST /cameras/{id}/reboot`. `published == true`만 성공(`kCameraRebootPublishedReliable`). 노출 조건은 `is_online && isRebootCapableFirmware(firmware_ver)`.
- 카메라 완료 판정: 리셋 사유가 mqtt 재부팅 **이고**, `uptime_s`가 누르기 직전보다 줄었거나 `누른 뒤 폰 경과 시간 + 2초` 이하일 때. **폰 stopwatch 기준**이고 서버 시각과 비교하지 않는다.
- 리셋 사유는 `resetReasonBase`/`isMqttRebootReason`으로 비교한다(펌웨어가 `(WDT)` 같은 사유를 덧붙인다). 정확 일치 비교 금지.
- 사육장: `POST /devices/{uuid}/reboot` → 그 `commands` 행을 구독한다. **`status`만 보지 않는다**(거부도 `acked`, 성공은 `result == ok`뿐이고 ok는 재부팅 직전). `no_ack`/`expired`/`lost`는 응답 없음, `unknown_action`은 펌웨어 업데이트 안내. 신 펌웨어 판별은 `sys_state != null`.
- 기기 상세 `RebootRow`는 조건이 안 맞으면 숨긴다(단 재시작 중 오프라인이 돼도 결과까지는 남긴다). 마이페이지 `DeviceRebootScreen`과 세로 확대 화면은 비활성 + 이유를 보인다. 마이페이지 재시작에 카메라는 넣지 않는다.

## Wi-Fi 약함
- `rssi ≤ −75`가 서로 다른 heartbeat에서 연속될 때만 띄운다(카메라 4번, 사육장 20번). 사육장에서 rssi 없는 보고는 연속 횟수를 0으로 되돌린다. 배너는 사용자가 닫을 때까지 유지한다.

## 카메라 회전
- REST `PATCH /cameras/{id}` `{rotate_180}`만. Supabase 직결 UPDATE 금지(서버가 MQTT `set_rotation`을 발행).
- 토글은 항상 노출한다(세트에 카메라가 없으면 비활성 + 이유). 적용은 재부팅 후 약 20초라 성공 안내(`camera_rotate_applying`)로 예고한다.
