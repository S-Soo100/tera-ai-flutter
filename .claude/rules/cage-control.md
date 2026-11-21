---
paths:
  - "lib/features/home/**"
  - "lib/features/my_cage/presentation/supabase_module_providers.dart"
  - "lib/features/my_cage/domain/device_command.dart"
  - "lib/features/my_cage/domain/telemetry_reading.dart"
  - "lib/shared/domain/actuator_marker.dart"
  - "lib/shared/domain/control_log.dart"
  - "lib/shared/domain/fan_actuator.dart"
  - "lib/core/config/feature_flags.dart"
---
# 사육장 제어 규칙

경위·수치·날짜: `docs/contracts/cage-control.md`. 절대 상태 명령, `cage_control_actions.dart` 경유, 히터 켜기 진입점 금지, 명령 매핑 두 곳은 CLAUDE.md에 있다.

## 제어 시트와 진입
- 제어 시트(`DeviceControlSheet`)에서 시작·정지는 전원 스위치가 한다. **꺼져 있을 때** 칩·슬라이더는 선택만 한다. 켜져 있을 때 다른 칩을 고르거나 슬라이더에서 손을 떼면 그 값으로 명령을 보낸다.
- 꺼진 환기팬은 시간 선택 → 시작으로 실행한다. 선택·취소만으로 명령을 보내지 않는다.
- 켜진 팬에서 이미 고른 칩을 다시 누르면 보내지 않는다. 실패하면 칩을 원복한다.
- 히터 타일은 켜짐·안전잠금일 때만 보인다(끄기·잠금 해제 진입점).
- 냉각팬: `FeatureFlags.coolFanEnabled`가 false면 이미 켜진 팬 끄기만 허용한다. fan2 미보고 보드는 타일·예약 목록에서 막는다.

## 확인 대기 (`control_pending.dart`)
- 명령은 `sendCageCommand(…, device:, expectOn:)`로 보낸다. 켜진 채 시간·밝기만 바꾸는 명령은 `expectOn: null`(ACK로 확인).
- 대기 중에는 스위치·타일을 목표 상태 + shimmer로 그리고 **그 사육장의 제어 전체를 잠근다**(사용자 결정). 다른 제어 대기 중인 타일은 흐리게.
- 거절(`busy`/`error`)·미전달(`no_ack`/`expired`/`lost`)은 즉시 안내하고 원위치한다. ACK는 됐는데 상태 보고만 늦으면 조용히 해제한다.
- 8초 무ACK는 "실행되지 않았다"가 아니라 "응답이 늦어요"(`ControlOutcome.unconfirmed`)다.
- 시트·홈 제어 안내에 **스낵바를 쓰지 않는다.** 제어 시트가 루트 모달이라 스낵바는 시트 뒤에 그려진다. `ControlFeedback`을 쓴다(분무 '실행 취소' 포함).
- 연결 판정 `moduleLinkProvider`는 그 기기의 실시간 `is_online`(`deviceLinkStatusProvider`)을 본다. 목록 첫 기기·앱 시작 스냅샷으로 판정하지 않는다. `ModuleLink`가 unknown이면 "확인 중"으로 그리고 제어는 계속 막는다.

## 분무
- `mist` + `payload.duration_ms`만 보낸다. **OFF는 보내지 않는다**(펌웨어가 스스로 끈다). 앱에서 지연 OFF로 펄스를 흉내 내지 않는다.
- 흐름은 시간 칩 → "1회 분사 시작" → 2초 실행 취소 창 → 분사. 선택지는 3/5/9초(기본 3초, 기기별 기억 `MistChoiceStore`).
- 즉시 분무는 명령 한 번(`kMistServerSupportsLong=true`). 3초 이어 보내기 경로(`sendMistWith`·`mistRunProvider`)는 되돌림용으로 남겨 둔다.
- 예약은 3·5초만. 9초 예약은 서버 `e2eba29` 운영 배포 확인 뒤 `kMistSchedulesSupportLong`을 켠다(그 전엔 400).
- 잠금은 분사 시간 + 3초(`MistLock.lockFor`). 8초 무응답이면 두 번 분사되지 않게 30초(`MistLock.unconfirmedHold`).
- 과거 `relay_toggle` 이력은 분무로 해석한다. 제어 기록은 이어진 분무를 한 줄로 합친다(`kMistChainGap`, `source='timer'` 이음 행은 더하지 않음).
- `capabilities.mist_max_ms`는 앱이 읽지 않는다.

## LED
- 밝기 슬라이더는 `Device.ledDimmable`이 true인 보드만. 펌웨어가 capabilities를 보고하지 않아 전 기기가 `relay`로 백필돼 있다. 앱은 분기만 갖고 기다린다.
- LED 실상태는 `telemetry.led`/`led_brightness`만 본다. 구 펌웨어(`unavailable`)는 "모름"으로 그리고 켜기/끄기 버튼을 둘 다 내놓는다. 로컬 추측 금지.

## 팬 타이머
- `fan_on` + `payload.duration_ms`(최대 2h). 자동 OFF는 펌웨어, 취소는 `fan_off`. 히터 타이머는 미지원.
- 진행 표시는 타일 부제 카운트다운이다. 홈 상단 타이머 칩(구 `RunningTimerChip`, 2026-11-21 코드 삭제)을 되살리지 않는다.
- 남은 시간은 서버 상태가 아니라 `commands` 이력의 `issued_at + duration_ms`로 계산한다(`RunningTimer.fanTimerFrom`).
- 미ACK(`pending`/`sent`) 명령은 발행 15초(`kCommandAckGrace`)까지만 인정한다. `sent`는 publish 성공일 뿐이고 단절 중 명령은 영영 전달되지 않는다.
- 최신 유효 팬 명령이 `source='auto'`(서버 자동 환기)면 타이머가 아니다.

## 예약
- 쓰기는 REST만(`schedule_repository.dart`). 직결 INSERT는 RLS를 통과하지만 `next_run_at`이 없어 영영 안 돈다. `next_run_at`은 UTC라 `.toLocal()` 한 번만.
- 예약 액션은 절대 명령만 고를 수 있다. `*_toggle` 예약과 off+guard는 서버 400. 가드는 on쪽에만 건다.
- 구간 예약은 같은 `pair_id`로 on/off 2건(`addSpan`). 토글·수정도 두 행을 함께 바꾼다(`setPairEnabled`/`updateSpanTiming`). off가 실패하면 on을 원래 값으로 되돌린다. 삭제 뒤엔 목록을 다시 조회한다.
- 반쪽 켜짐(on만 enabled)은 **켜짐+경고**로 그린다. OFF로 숨기면 안 꺼지는 히터를 감춘다.
- 예약 목록 줄마다 마지막 실행 결과를 보인다(`scheduleLastRunsProvider`).

## 화면
- 못 하는 이유를 화면에서 밝힌다(정지형 가드·히터 타이머 각주, `DeviceOfflineNotice`). 회색 버튼만 두지 않는다.
- `lcd_bitmap`/`lcd_clear`는 차트 마커·제어 기록에서 의도적으로 제외한다(액추에이터 동작이 아님).
