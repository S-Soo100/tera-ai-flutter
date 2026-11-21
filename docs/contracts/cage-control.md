# 사육장 제어 계약 (명령·확인 대기·분무·LED·팬 타이머·예약)

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

## 삭제된 핸드오프·회신 문서 안내 (2026-09-07)

**전달용 핸드오프/회신 문서는 레포에서 삭제됨(2026-09-07 정리)** — 반영 완료 문서(08-14 계약 요약, 08-18 webrtc·계약, 08-29 커뮤니티, camera-detail-ux, timer-mist 결정 로그, 09-07 mist 블랙아웃 요청/펌웨어 회신/앱 답신)는 **git 이력에서 조회**(`git log --diff-filter=D -- docs/`). 핵심 계약은 아래 요약과 코드 주석이 SOT

## mist 블랙아웃·명령 유실 회신 (2026-09-07)

**백엔드 핸드오프 2026-09-07 (mist 블랙아웃·명령 유실) → 회신 받음**: 분무 시 ~25초 침묵의 원인은 펌프 블로킹이 **아니라**(mist는 이미 비블로킹) 브라운아웃/전원 노이즈/재연결 비용 의심(P0 실측 예정). 유실 메커니즘 확정: MQTT clean session + retain=false로 단절 중 명령은 영영 미전달, `sent`=publish 성공일 뿐. 서버 P1=sent 30초 만료+절대명령 제한 재전송 수용. 앱은 ACK 15초 유예(`kCommandAckGrace`)+미전달(`pending/sent/expired/lost`) 스낵바 — 서버 P1 배포 후 서버 상태 기반으로 교체

## 제어 시트·로그인·마이페이지 구현 (2026-09-16)

**2026-09-16 저녁: 로그인·기기 제어 시트·마이페이지 구현(0.109.0~0.111.0).** 결과·결정표 [`docs/design-audits/2026-09-16-sheets-login-mypage/RESULTS.md`](../../docs/design-audits/2026-09-16-sheets-login-mypage/RESULTS.md). 홈 제어 타일 탭 = `DeviceControlSheet`(즉시/예약 segment, **전원 스위치가 명시적 시작/정지 — 칩·슬라이더는 선택만**, 분무는 "1회 분사 시작"+2초 실행 취소, 타이머는 타일 부제 카운트다운·상단 칩 폐지). 공용 입력은 `VivaTextField`/`VivaCheckRow`, 확인 모달은 `showVivaModal`. 마이페이지 목록 행 `MyPageRow`는 **선 없는 흰 면 r12**(2026-10-04 사용자 지적 — Figma에 테두리 없음, 테두리 되살리지 말 것). 마이페이지는 `/profile` + `community`·`blocked`·`notifications`·`account(/password,/withdraw)`. 서버 의존 3건은 [요청서](../../docs/handoffs/2026-09-16-mypage-server-requests.md). Figma 이미지는 talk-to-figma 소켓(3055)에 직접 붙는 스크립트로 파일 저장(MCP 결과는 화면 표시만) — `docs/design-audits/2026-09-16-sheets-login-mypage/RESULTS.md` §3.

## 꺼진 환기팬 실행 방식 (2026-09-14)

꺼진 환기팬은 시간 선택→시작으로 실행. 선택/취소만으로 명령을 보내지 않는다. 일정 & 타이머 문구는 ‘일정’. → **2026-09-19 사용자 결정으로 홈 진입 문구는 ‘기기 예약 설정’으로 통일**(Figma 1107:10445·예약 화면 제목과 일치, `redesign_home_schedule_settings`).

## 제어 명령 경유 원칙

**⚠️ 사육장 제어 명령은 반드시 `home/presentation/cage_control_actions.dart`를 경유한다.** 히터 2단 안전확인(과열=개체 폐사)이 거기 있다. 진입점은 홈 `CageControlGrid` **하나뿐**이다(구 서브탭 `QuickControlGrid`는 2026-09-04 정리로 삭제 — 라이브 아래 `LiveControlBar`도 버튼이 두 벌 쌓여 2026-08-09 제거, D4 철회). 제어 진입점을 다시 늘린다면 반드시 이 모듈을 경유할 것.

## 제어 확인 대기 (2026-09-22)

**제어 확인 대기**(2026-09-22, `home/presentation/control_pending.dart`): 명령은 `sendCageCommand(…, device:, expectOn:)`로 보내고, 기기 텔레메트리가 목표 상태를 보고하거나 `commands` 상태가 확정될 때까지(1초 조회×최대 8회) `controlPendingProvider(deviceId)`가 대기한다. 그동안 시트 스위치·홈 타일은 **목표 상태 + shimmer**(`ControlLoadingOverlay`)로 그리고 **그 사육장의 제어 전체를 잠근다**(사용자 결정 — 텔레메트리 반영 p50 1.7s·p90 3s라 스위치가 늦게 넘어가 연타 → 기기 `busy` 거절이 잦았다). 거절(`busy`/`error`)·미전달(`no_ack`/`expired`/`lost`)·8초 무ACK는 즉시 안내 후 원위치, ACK는 됐는데 보고만 늦으면 조용히 해제. 켜진 채 시간·밝기만 바꾸는 명령은 `expectOn: null`(ACK로 확인). 구 16초 `_watchCommandAck`는 이것으로 대체됐다. **2026-09-25:** 8초 무ACK는 "실행되지 않았다"가 아니라 "응답이 늦어요"(`ControlOutcome.unconfirmed` — 서버는 30초 뒤 no_ack 확정). **결과 안내는 `ControlFeedback`(루트 Navigator Overlay 맨 위, `widgets/control_feedback.dart`)** — 제어 시트가 루트 모달이라 ScaffoldMessenger 스낵바는 시트 뒤에 그려져 안 보였다(분무 '실행 취소' 포함). 시트·홈 제어 안내는 스낵바를 쓰지 말 것. 켜진 팬에서 이미 고른 칩 재탭은 보내지 않고, 실패하면 칩 원복. 다른 제어 대기 중인 타일은 흐리게(`dimmed`). 연결 판정 `moduleLinkProvider`는 **그 기기의 실시간 `is_online`**(`deviceLinkStatusProvider` — devices UPDATE 구독+재합류 재조회)을 본다(전엔 목록 첫 기기·앱 시작 스냅샷이라 켤 때 꺼져 있던 사육장이 재시작 전까지 잠겼다). 예약 목록 줄마다 마지막 실행 결과(`scheduleLastRunsProvider` — commands `source='schedule'`·`source_id`).

## 절대 상태 명령 (2026-08-12)

**⚠️ 제어는 toggle이 아니라 절대 상태 명령을 쓴다** (2026-08-12). `fan_on/off`·`heater_on/off`·`relay_on/off`가 펌웨어에 **처음부터 있었다** — `APP_INTEGRATION.md §3.2` 표에 toggle만 적혀 있어 없는 줄 알았을 뿐이다. 뒤집기는 기기의 현재 상태를 전제하는데 그 전제가 어긋나면 끄려던 조작이 켜고, 히터에서는 과열=폐사다. 홈 `CageControlGrid`·사육장 탭 `actuator_controls` 둘 다 절대 명령이다.

## 새 명령 추가 시 같이 고칠 매핑

**⚠️ 새 명령을 추가하면 `shared/domain/actuator_marker.dart`의 `_kindByAction`과 `shared/domain/control_log.dart`의 `_entryByAction`을 같이 고칠 것.** 안 하면 그 동작만 차트(마커)와 제어 기록에서 **조용히** 사라진다(에러 없음). `led_toggle` 누락으로 12건을 놓쳤고, `mist` 전환 때도 밟을 뻔했다.

## 분무

**분무**: `mist` + `payload.duration_ms`. 홈 타일 탭은 제어 시트를 열고 **분사 시간 칩(**3/5/9초**, 기본 3초 — 2026-09-29 사용자 결정(구 3/6/9초: 실기기에서 3초 이어 보내기가 3초만 뿌려짐), 기기별 기억 `MistChoiceStore`) → "1회 분사 시작" → 2초 실행 취소 창 → 선택한 시간만큼 분사**(Figma 분무 시트엔 시간 선택이 없어 환기팬 "작동 시간" 칩 문법을 재사용). **2026-09-28부터 긴 분무(당시 6·9초, 현재 9초)도 명령 한 번**(`kMistServerSupportsLong=true`) — terra-server `backend/mqtt/dispatcher.py` 2.5단계가 기기 상한(`capabilities.mist_max_ms`, 미보고 5000)을 넘으면 상한만큼 먼저 보내고 나머지를 1.5초 뒤 `source='timer'` 후속으로 보낸다(9/23 `19384a2`부터 운영, 즉시 분무 commands 직결엔 허용값 검사 없음). 구 펌웨어 9초 = 5+4(약 10.5초), 신 펌웨어는 한 번에. 앱 3초 이어 보내기(`sendMistWith` 회차·`mistRunProvider`)는 false로 되돌릴 때를 위해 남겨 둔다. **예약은 옛 허용값에 있는 3·5초만, 9초는 REST 검증을 1~20초 범위로 바꾼 `e2eba29`의 운영 배포가 확인된 뒤**(`kMistSchedulesSupportLong=false`, 배포 전 9초 예약은 400). 잠금은 분사 시간 + 3초(`MistLock.lockFor`: 3초 6초·5초 8초·9초 12초 — 백엔드 규칙), 8초 무응답이면 늦은 도착으로 두 번 분사되지 않게 30초 잠금(`MistLock.unconfirmedHold`). 제어 기록은 이어진 분무를 한 줄로 합친다(`kMistChainGap` 8초, 서버 `source='timer'` 이음 행은 더하지 않음). 운영 참고: 수동 분무는 commands 직결 INSERT라 REST 허용값(1/2/3초) 검사를 안 거치고, 서버는 펌웨어 5초 상한 때문에 긴 분무를 5초씩 이어 보낸다(10초=5+5, 2026-09-25 실측). **2026-09-28 백엔드 전달(`docs/references/2026-09-28-mist-max-30s.md`):** 신 펌웨어(nano `a09772f`/supermini `7ed013d`, `capabilities.mist_max_ms=30000`, 운영 4대 확인)는 분무 상한 30초 — 10초가 분할 없이 한 번에 나가고 `source='timer'` 후속 행이 없다(구 펌웨어는 계속 5+5). 제어 기록 묶기는 후속 행 유무와 무관하다. `mist_max_ms`는 앱이 읽지 않는다(백엔드 권고). (이 전달문을 받고 적었던 "허용값 밖 6·9초는 앱이 3초씩 이어 보낸다·6000·9000 직결 INSERT는 하지 않는다"는 같은 날 서버 분할을 확인한 0.142.0에서 폐기 — 현행은 위 `kMistServerSupportsLong=true`.) 앱은 지속시간만 보내고 **OFF는 보내지 않는다** — 펌웨어가 스스로 끈다. 과거 `relay_toggle` 144건도 계속 분무로 해석한다(`MistDuration`, `home_mist_*`).

## LED 밝기 (2026-08-18)

**LED 밝기는 보드 능력으로 분기한다**(2026-08-18): `devices.capabilities.led_dimmable`(`Device.ledDimmable`)이 true인 MOSFET 보드만 제어 시트(`DeviceControlSheet`, 진입 `openDeviceControlSheet`)에 슬라이더(`led_on`+`brightness`)가 뜬다. 릴레이 보드는 on/off만. **⚠️ 펌웨어가 아직 capabilities를 보고하지 않아 전 기기가 `relay`로 백필**돼 있다 — 실제 MOSFET이면 운영자가 DB를 고치거나 펌웨어 보고가 붙어야 슬라이더가 열린다. 앱은 분기만 갖고 기다린다. **LED 실상태는 `telemetry.led`/`led_brightness`**(`TelemetryReading.led`)만 본다 — 구 펌웨어(`unavailable`)는 "모름"으로 그리고 켜기/끄기 버튼을 둘 다 내놓는다(홈 캡슐·사육장 타일 동일 규칙, 로컬 추측 없음).

## 팬 타이머·자동 환기

**팬 타이머**(2026-08-14): `fan_on` + `payload.duration_ms`(최대 2h) → **펌웨어가 자동 OFF**, 취소는 `fan_off`. 진행 표시는 타일 부제 카운트다운("켜짐 · 30m 56s 뒤 꺼짐", 2026-09-16 — 상단 `RunningTimerChip`은 화면에서 뺌 — 클래스는 `running_timer_chip.dart`에 남아 있으나 그리는 곳이 없고, 같은 파일의 `runningTimersProvider`만 쓰인다)이며 서버 상태가 아니라 `commands` 이력에서 `issued_at+duration_ms`로 계산한다(`RunningTimer.fanTimerFrom`) — 단 **미ACK(`pending`/`sent`) 명령은 발행 15초(`kCommandAckGrace`)까지만 인정**(2026-09-07 mist 블랙아웃 유실 대응). 히터 타이머는 보드 미탑재로 미지원. **최신 유효 팬 명령이 `source='auto'`(서버 자동 환기)면 타이머가 아니다**(2026-11-05 — 자동은 1시간 `fan_on`을 반복해 카운트다운·"타이머 끝" 알림이 뜨던 문제). 자동 환기·분무 전체는 계획 `docs/superpowers/plans/2026-11-05-auto-env-app.md` — 토글은 2026-11-06 사용자 결정으로 `kAutoEnvReleased=true` 출시(0.175.0) — **서버는 아직 구현 착수·스위치 꺼짐이라 서버 전체 켬 전까지 토글이 동작하지 않을 수 있다**. 남은 Task 5(서버 전체 켬 뒤 실기 확인·수치 검수).

## 예약(일정)

**예약(일정)**: `home/data/schedule_repository.dart`(REST 전용) + `home/presentation/schedule_providers.dart` + `RoutineSettingsScreen`. **쓰기는 반드시 REST** — RLS가 있어 직결 INSERT도 통과하지만 서버가 `next_run_at`을 계산하므로 직접 넣으면 예약이 영영 안 돈다. `next_run_at`은 UTC로 오니 `.toLocal()` 한 번(문서 예제의 `+9h`는 이중 변환 버그). 예약 액션은 **절대 명령만 selectable**(toggle은 무인 실행에서 위험해 제외). **구간 예약**은 편집기 [구간]이 **같은 `pair_id`(앱 UUID)**로 on/off 2건을 만든다(`addSpan`, off 실패 시 on 롤백) — 서버가 짝을 묶어 **한 건 DELETE로 둘 다 삭제**되고, 목록은 `Schedule.group()`이 `SchedulePair` 한 줄로 그린다(토글·편집도 두 행 동시, `setPairEnabled`/`updateSpanTiming` — **off 실패 시 on을 원래 값으로 롤백**, 삭제 후엔 목록 재조회로 서버 캐스케이드를 확인). 반쪽 켜짐(on만 enabled)은 **켜짐+경고**로 그린다(OFF로 숨기면 안 꺼지는 히터를 감춘다). 2026-08-18 이전 낱개 구간은 짝 없이 그대로 보인다. **스마트 가드**는 스킵형 4종(`ScheduleGuard`), 가드는 on쪽에만 건다 — **off+guard는 서버가 400**, `*_toggle` 예약도 서버 400(앱은 이미 안 고름).

## 화면에서 이유를 밝힌다·LCD 문구

**화면에서 이유를 밝힌다**: 정지형 가드·히터 타이머는 펌웨어 후속이라 `RoutineSettingsScreen` 하단 각주로 밝힌다. 기기 오프라인도 `DeviceOfflineNotice`로 밝힌다 — 회색 버튼만 두면 고장으로 읽힌다. **LCD 문구**는 홈 '일정 설정' 하단 `HomeLcdRow`(2026-09-07 사육장 설정에서 이동, 시트=`showLcdSheet`, REST `/lcd`, 64자 상한) — `lcd_bitmap/lcd_clear`는 차트 마커에서 **의도적으로 제외**(액추에이터 동작이 아님).

## 백엔드 계약 결정 로그 이관 안내

백엔드 계약 결정 로그(timer-mist §10·08-14 계약 요약)는 **git 이력으로 이관**(2026-09-07 docs 정리). ⚠️ 팬타이머·LCD 실동작은 **펌웨어 플래시 선행**.
