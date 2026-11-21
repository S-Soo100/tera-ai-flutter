---
paths:
  - "lib/features/home/**/env_*"
  - "lib/features/home/**/temp_*"
  - "lib/features/home/presentation/widgets/live_stat_overlay.dart"
  - "lib/shared/domain/env_*.dart"
  - "lib/shared/domain/num_format.dart"
  - "lib/shared/widgets/env_*.dart"
  - "lib/features/my_cage/presentation/supabase_module_providers.dart"
  - "lib/features/my_cage/presentation/device_settings_providers.dart"
  - "lib/features/my_cage/presentation/env_settings_screen.dart"
  - "lib/features/my_cage/data/supabase_module_control_repository.dart"
  - "lib/features/my_cage/data/device_settings_repository.dart"
  - "lib/features/my_cage/data/temp_offset_repository.dart"
  - "lib/features/my_cage/domain/species_comfort.dart"
  - "lib/features/my_cage/domain/telemetry_bucket.dart"
  - "lib/features/my_cage/presentation/widgets/telemetry_history_chart.dart"
  - "lib/features/my_cage/presentation/widgets/setpoint_setting_tile.dart"
  - "lib/features/my_cage/presentation/widgets/device_setting_sheet.dart"
  - "lib/features/my_cage/presentation/widgets/module_status_card.dart"
  - "lib/core/config/feature_flags.dart"
---
# 온습도 규칙

경위·수치·날짜: `docs/contracts/env-telemetry.md`.

## 현재 값 표시
- 홈 카드·라이브 오버레이·온습도 상세의 오늘 값은 `envLiveViewProvider`만 쓴다.
- 값은 정상 행(`a_ok` + 값>0)에서만 덮어쓰고 **절대 지우지 않는다.** 경과가 음수면 0으로 본다(폰 시계가 서버보다 늦을 수 있다).
- 신선도는 3단계: 15초 안 그대로 / 넘으면 흐리게 + "N초 전 값" / 서버 `is_online=false`면 "오프라인 · HH:MM 기준".
- 센서 오류 표시는 연속 10번(약 30초)부터. 첫 값은 `latestGoodTelemetry`.
- `telemetryStaleProvider`(60초)는 제어 허용 판정·연결 끊김 배너 전용이다. 표시에 쓰지 않는다.
- 과거 평균은 지표별 valid count로 계산한다. 서버 count 미지원은 `--`. 마지막 값·단순 평균으로 대체하지 않는다.
- 공용 `EnvChart`·`EnvSummaryBar`는 provider를 읽지 않고 값만 받는다(순환 참조 방지).

## 온도 보정
- 앱은 **사용자 보정값만** 주고받는다(보내기 `user_offset_c`, 읽기 `devices.temp_offset_user_c`). 공장 기준은 서버·펌웨어 몫이다.
- 앱에서 기기별 공장 기준을 가정하지 않는다(0.184.2 "허브 = 0" 오판). 콘솔 `set_temp_offset`은 절대값이다.
- 옛 계약 경로(`fromDevice`·`toDeviceValue`·`factoryDeviceValue`)는 `FeatureFlags.tempOffsetUserContract`를 되돌릴 때를 위해 남겨 둔다.

## 추이·목표값
- `telemetry_30m`의 0값은 센서 오프라인 센티넬이다. 로드할 때 `v>0` 필터.
- 안심존은 종 care_info에서 도출한다(`SpeciesComfort`). 임의 수치를 넣지 않는다.
- 목표 온습도는 REST `device_settings`. 미설정은 404가 아니라 전부 null인 200이다. **앱이 임의 기본값을 채우지 않는다.** 검증 범위는 서버와 같게(−20~60℃ / 0~100%).
- 카드의 목표 줄은 로딩·에러면 비우고, 서버가 null을 줬을 때만 "미설정"으로 그린다.
- 편집 대상은 "보고 있는 기기"다: 환경설정은 홈 세트의 기기(타일에 기기명 표시), 사육장 카드는 그 카드의 기기(`showSetpointSheet`).
- 환경설정의 "현재 세트 기기" 설정 타일은 `DeviceSettingTile`/`DeviceSettingSheet`/`submitAndClose`를 경유한다(새 기기 설정을 추가할 때 타일·시트를 복붙하지 않는다). 숫자 표기·파싱은 `shared/domain/num_format.dart`.
