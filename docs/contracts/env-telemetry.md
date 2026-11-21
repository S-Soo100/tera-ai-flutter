# 온습도 표시·보정·추이·목표값 계약

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

## 오늘·과거 온습도 값 (2026-09-14)

오늘 온습도는 유효한 실시간, 과거는 지표별 valid count를 사용한 평균. 서버 count 미지원은 `--`, 마지막 값/단순 평균 대체 금지.

## 현재 온습도 표시 규칙 (2026-09-28)

**현재 온습도 표시 규칙**(2026-09-28, 0.142.1, 백엔드 `docs/references/2026-09-28-telemetry-display.md` §3 — 웹 콘솔과 같은 규칙): 홈 카드·라이브 오버레이·온습도 상세 오늘 값은 `envLiveViewProvider`(`home/presentation/env_live_providers.dart`, 도메인 `env_realtime_values.dart`)만 쓴다. **값은 정상 행(`a_ok` + 값>0)에서만 덮어쓰고 절대 지우지 않는다** — 전엔 행마다 판정해 센서 단발 실패·12초 무소식·**폰 시계가 서버보다 늦어 경과가 음수**인 샘플마다 `--`가 됐다(데이터는 3~4초마다 빠짐없이 왔다). 신선도는 3단계(15초 안 그대로 / 넘으면 흐리게+"N초 전 값" / 서버 `is_online=false`면 "오프라인 · HH:MM 기준"), 경과가 음수면 0. 센서 오류는 연속 10번(약 30초)부터만(사용자 결정 — 단발 배지는 깜빡임). 첫 값은 `latestGoodTelemetry`(`a_ok=true`). `telemetryStaleProvider`(**60초** `moduleLinkGrace`, 2026-11-08 — 12초일 땐 분무 등 펌웨어 ~25초 침묵마다 "기기 연결이 끊겼어요"가 깜빡였다)는 **제어 허용 판정·연결 끊김 배너 전용**으로 남았다 — 표시에 다시 쓰지 말 것. REST 무소식 점검 주기(`telemetryStaleThreshold` 12초)와는 별개다.

## 온도 보정 (2026-11-19)

**온도 보정**(2026-11-19, 0.185.1): 새 계약(`FeatureFlags.tempOffsetUserContract=true`) — 앱은 **사용자 보정값만** 주고받는다(보내기 `user_offset_c`, 읽기 `devices.temp_offset_user_c`). 공장 기본(보드별 `temp_offset_base_c`, 미보고면 서버 env −1.5)은 서버가 더하고 뺀다(terra-server `backend/temp_offset.py`, `docs/APP_TEMP_OFFSET_2026-11-10.md`). **앱에서 기기별 공장 기준을 가정하지 말 것** — 0.184.2에서 "허브 = 0"으로 가정했다가 오판(허브 펌웨어 기본도 −1.5)이라 되돌렸다. 허브 공장 보정은 **지금은 0, 추후 바뀔 수 있음**(2026-11-19 서버 결정 — 허브 세 대 서버 base 0.0 입력, 허브 펌웨어 기본은 다음 릴리스에서 −1.5→0). 바뀌어도 펌웨어 기본·서버 base만 맞추면 앱은 바꿀 것이 없다. 옛 계약 경로(`fromDevice`·`toDeviceValue`·`factoryDeviceValue`)는 스위치를 false로 되돌릴 때를 위해 남겨 두었다. 콘솔의 `set_temp_offset`은 **절대값**이라 `offset_c: 0`은 사용자 +1.5다(2026-11-18 승수홈 +1.5의 원인).

## 온습도 추이 차트 (2026-07-07)

온습도 추이 차트(2026-07-07, v0.12.0+22): `telemetry_history_chart.dart`(chart_sparkline) — 지표별 카드 + 매끈한 스파크라인 + **초록 안심존 밴드** + 최고/최저 마커, 기간 24h/7d/30d. 안심존=종 care_info 자동도출(`SpeciesComfort`; device_settings는 전 디바이스 비어있어 미사용, **임의 수치 금지**). **`telemetry_30m` 0값=센서 오프라인 센티넬 → 로드 시 `v>0` 필터 필수.** 상세: 메모리 `project_telemetry_chart`·`project_telemetry_zero_sentinel`.

## 목표 온습도(setpoint) (2026-08-18)

**목표 온습도(setpoint)는 REST `device_settings`**(2026-08-18) — `my_cage/data/device_settings_repository.dart` + `presentation/device_settings_providers.dart`. 미설정 기기는 404가 아니라 전부 null인 200이고 화면은 "목표 미설정"으로 그린다(**앱이 임의 기본값을 채우지 않는다**). 편집은 환경설정(`/env-settings`) `SetpointSettingTile`(홈 세트의 기기 — title에 기기명 표시, 2026-09-08 사육장 연동에서 이동) **또는 사육장 탭 카드의 목표 줄 탭**(`showSetpointSheet`, 그 카드의 기기) — 두 화면의 기기 축이 달라 어느 쪽에서 고치든 "보고 있는 기기"가 대상이 되게 했다. 서버와 같은 범위 검증(−20~60℃/0~100%). 카드는 로딩·에러면 목표 줄을 비우고 서버가 null일 때만 "미설정". **환경설정의 "현재 세트 기기" 타일은 `DeviceSettingTile`/`DeviceSettingSheet`/`submitAndClose`(`my_cage/presentation/widgets/device_setting_sheet.dart`)를 경유한다**(LCD·setpoint 공용 — 새 기기 설정을 추가하면 이걸 쓰고 타일/시트를 복붙하지 말 것). 숫자 표기·JSON double 파싱은 `shared/domain/num_format.dart`(`formatCompact`·`parseDouble`) — 흩어진 `_fmt`/`_parseDouble` 복제는 2026-08-18에 여기로 통합했다. 정지형 가드(히터 목표온도 정지)가 생기면 이 값이 기준이다.

## 정정 (2026-11-21)

- "온습도 추이 차트" 문단의 `telemetry_history_chart.dart`와 "목표 온습도" 문단의 "사육장 탭 카드의 목표 줄 탭(`showSetpointSheet`)"은 구 사육장 화면과 함께 0.186.4에서 지웠다. 추이는 `/env-detail`(`EnvDayChart`·`WeekRangeChart`)이 맡는다. `telemetry_30m` 0값 센티넬과 "임의 수치 금지"는 그대로 유효하다. `SpeciesComfort`는 provider에서 계속 쓰이고, 판정 함수 `classifyComfort`는 호출하는 곳이 없어졌다.
