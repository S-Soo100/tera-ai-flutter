# 자동 환기·자동 분무 — 앱 구현 계획

> **구현 방식 (CAOF):** Critical 트랙(4개 이상 파일, 서버 계약 의존). 사용자 승인 뒤 task 단위로 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **서버 §7 회신 (2026-11-05 저녁, 요청서 §8):** D1 해소(서버가 Figma대로 습도 1시간 연속, 분무 뒤 보호 삭제) · Q4 → 합치기 창 8분(0.174.2) · Q5 확인 · D2는 앱이 예약 목록으로 판정해야 함(서버 `schedule_hold`는 토글 꺼진 기기 미계산) — 후속 · Q3 테스트 기기 UUID 전달 대기.
>
> **진행 (2026-11-05):** Task 2·1·3·4 완료 → main 병합(0.171.3~0.174.0+479, 토글 숨김). 남은 것: 사용자 `/code-review`, 서버 §7 질문 회신(요청서 §7), Task 5.
>
> **r2 (2026-11-05):** 교차 검수(Codex + Claude) 반영. 검수 결과 `docs/superpowers/plans/2026-11-05-auto-env-app-review-final.md`.

**Goal:** 환기팬·분무 제어 시트에 기기별 "자동 환기"·"자동 분무" 토글을 붙인다. 서버가 낸 자동 명령은 제어 기록에 "자동"으로 구분해 보여 준다. 자동으로 켜진 팬을 사용자 타이머로 잘못 세는 문제도 막는다.

**Architecture:** 판정과 실행은 전부 서버가 한다(브리지가 3초 텔레메트리마다 판정). 앱이 하는 일은 셋이다.
1. 토글을 `GET/PATCH /devices/{id}/settings`로 읽고 쓴다.
2. `devices.auto_env_state.vent.active`를 기존 `deviceLinkStatusProvider` 경로로 읽기만 한다.
3. `commands.source='auto'`와 `reason`을 해석한다. 제어 기록 조회는 컬럼을 고르지 않는 `select()`로 바꾼다. 그러면 `reason` 컬럼이 생기기 전후 어느 서버에서도 깨지지 않는다.

토글 노출만 `kAutoEnvReleased` 하나로 막는다. 서버가 "전체 켬"을 알리기 전까지는 토글이 꺼진 채 main에 합쳐진다.

**Tech Stack:** Flutter, Riverpod, terra REST(`TerraRestClient`), Supabase Realtime(`devices`), easy_localization

**Spec:**
- 서버 계약: `/Users/baek/terra-server-wt-auto-env/docs/APP_AUTO_ENV_2026-11-05.md`. 착수 전에 맨 위 "배포 상태"를 다시 볼 것.
- 앱 요청서: `docs/handoffs/2026-11-05-auto-vent-mist-request.md`
- Figma: `1635:6166` 안의 자동 환기·분무 시트
  - `1635:6168` 환기
  - `1657:5326` 환기·예약 중
  - ~~`1657:5353` 분무~~ → **`1783:12062` 분무**(2026-11-06 개정 — 칩이 Figma에 들어오고 자동 분무는 CTA 아래, 1657:5353은 삭제됨)
  - ~~`1657:5361` 분무·예약 중~~ → **`1783:12087` 분무·예약 중**(2026-11-06)
  - 메모 `1657:5409`

## 사전 조건

| # | 내용 | 상태 |
|---|---|---|
| P1 | **Figma 습도 조건이 서버와 다르다.** 2026-11-05 오후에 메모 `1657:5409`와 환기 시트 설명이 "습도 {Max}% 초과 **1시간 이상 유지**(습도 주의 이벤트와 같은 조건)"로 바뀌었다. 서버 계약 §1(확정)은 "습도 > MAX **3분 연속**" + 분무 뒤 60분 보호다. 설명 문구는 실제 동작과 같아야 한다 | **사용자 결정 D1**. 출시(Task 5)만 막는다 |
| P2 | 서버 DB 마이그레이션(설정 API `auto_*_enabled`, `commands.reason`, `devices.auto_env_state`) | 미적용(2026-11-05). Task 1~4는 가짜 데이터 테스트로 먼저 진행할 수 있다 |
| P3 | 서버 "전체 켬" 통보 | Task 5만 기다린다 |

## 사용자가 정할 것

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| D1 | 습도 자동 환기 조건 | (a) 서버에 Figma대로 "1시간 이상 연속 초과"로 바꿔 달라고 요청 (b) 디자이너에게 서버 확정 규칙에 맞춘 문구를 요청 — 예: "습도 {}% 또는 온도 {}℃를 넘는 상태가 3분 이어지면 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다" | **(a)를 먼저 묻고, 서버가 섀도 모드 일정 때문에 어렵다고 하면 (b)** — 디자이너는 습도 주의 알림과 같은 조건이라고 명시했다. 다만 계약 §1은 "확정"이고 섀도 일정과 묶여 있어, 회신이 늦으면 Task 5가 막힌다. 앱에서 바뀌는 건 문구 키(`auto_vent_desc`) 하나라 어느 쪽이든 늦게 정해도 된다 |
| D2 | 예약 실행 중 화면(`1657:5326`) | (a) Figma대로 안내 + 잠금 (b) 이번엔 안 그림, 토글은 늘 활성(서버가 알아서 쉼) | **(b)** — 서버 `schedule_hold`는 "자동이 쉬는 중"이라는 뜻일 뿐 수동 명령을 막지 않는다. 자동이 꺼진 기기에서도 계산되는지(Q2)도 모른다. 자동이 켜진 채 예약 구간에 들어가면 사용자가 자동을 끌 수조차 없게 되는 문제도 있다. Q2 회신 뒤 별도로 정한다 |
| D3 | 분무 시트에서 자동 토글 위치 | 앱 분무 시트에는 Figma에 없는 분사 시간 칩(3/5/9초)이 있다. (a) 탭 바로 아래(Figma 자리) → 칩 → [1회 분사 시작] (b) 칩 → 자동 토글 → CTA | ~~(a)~~ → **2026-11-06 Figma `1783:12062`로 대체:** 칩 → [1회 분사 시작] → 24 → 1px 선 → 20 → 자동 분무(환기 시트와 같은 틀). 0.174.9+488 반영 |
| D4 | 제어 기록에서 매시간 다시 켜는 자동 환기 | 원인이 남아 있으면 서버는 1시간 타이머가 끝날 때마다 `fan_on`을 다시 보낸다(하루 최대 12줄) | **한 줄로 합친다.** 직전 자동 `fan_on`의 `issued_at + duration_ms + 10분` 안에 온 자동 `fan_on`은 이어진 것으로 본다. 단 그 사이에 같은 팬의 다른 명령(자동이 아닌 on/off/toggle, 자동 off)이 있으면 끊는다. 10분은 서버의 "꺼진 팬 재명령 최소 5분 간격"을 덮는 여유다(Q4로 상한 확인) |
| D5 | 자동이 켠 팬일 때 시트의 작동 시간 칩 | 지금 규칙(켜짐 + 사용자 타이머 없음 = "계속" 선택)대로면 자동 환기 중에 "계속"이 선택돼 보인다. 실제로는 원인이 풀리면 꺼진다. (a) 그대로 (b) `auto_env_state.vent.active`면 아무 칩도 선택하지 않음 | **(b)** — 사용자가 고르지 않은 선택을 보여 주지 않는다. Figma에 별도 표시는 없어 칩 선택만 비운다 |

## 서버에 물을 것 (Task 5 전까지 회신 필요, 구현은 막지 않음)

- Q1: D1 결정 내용. (a)라면 분무 뒤 60분 보호를 남길지도 함께 묻는다.
- Q2: `auto_env_state.vent.schedule_hold`가 자동이 꺼진 기기에서도 계산되는가. D2 후속에 필요하다.
- Q3: 앱 실기 확인용으로 앱 계정 기기 1대를 테스트 허용 목록에 넣을 수 있는가.
- Q4: 원인이 계속될 때 자동 재켜짐이 1시간 타이머가 끝난 뒤 최대 몇 분 안에 나가는가. D4의 10분 창이 맞는지 확인하려는 것이다.
- Q5: 자동 분무 명령의 모양이 `action='mist'` + `payload.duration_ms=3000`인가. 제어 기록의 "3초" 표시 근거다.

## 가정

| # | 가정 | 상태 |
|---|---|---|
| A1 | `listDevices`·`fetchLinkStatus`는 `devices`를 `select()`(전체 컬럼)로 읽는다. 그래서 `auto_env_state`가 저절로 실려 온다 | **확인** (`supabase_module_control_repository.dart:59-75`) |
| A2 | 제어 기록은 `acked`+`ok`만 그린다. 서버가 `expired`/`superseded`로 바꾼 자동 명령은 이미 숨겨진다 | **확인** (`control_log.dart:136`) |
| A3 | 팬 타이머 칩과 앱 열 때 알림 재동기화가 같은 판정(`RunningTimer.fanTimerFrom`)과 같은 쿼리 모양을 쓴다 | **확인** (`running_timer_chip.dart:46-56`, `fan_timer_notification_resync.dart:33-46`) |
| A4 | `commands.source`는 이미 있다. `reason`은 마이그레이션 전엔 없다. 그래서 제어 기록 조회를 `select()`로 바꾸고 `reason`은 키가 있을 때만 읽는다 | **확인**(source) — 미확인 부분을 설계로 우회 |
| A5 | 온습도 상세의 차트 마커는 `EnvDayChart.log`, 즉 제어 기록(`ControlLogEntry`) 그대로다. D4 합치기는 마커도 같이 줄인다(의도) | **확인** (`env_detail_screen.dart:253-255`) |
| A6 | 홈 제어 타일은 기기가 오프라인이면 시트를 열지 않는다. 그래서 오프라인 기기의 토글 저장 경로는 없다 | **확인** (`cage_control_grid.dart:71,138,163`) |

## 유저 체험 시뮬레이션

1. **환기 시트 열기:** 홈에서 환기팬 타일을 누르면 시트가 열린다. 전원·작동 시간 칩 아래에 가는 구분선이 있고, 그 아래 "자동 환기" 스위치(꺼짐)가 있다. 회색 설명에는 내 사육장 값이 들어간다. D1-a 기준 예: "습도 80% 초과 1시간 이상 또는 온도 27℃ 초과 시 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다".
2. **스위치 켜기:** 스위치 위로 shimmer가 흐르고, 서버 저장이 끝나면 켜진 색으로 멈춘다. 실패하거나, 서버가 응답은 했지만 값이 바뀌지 않았으면 꺼짐으로 돌아오고 시트 위에 "자동 설정을 저장하지 못했어요…" 안내가 뜬다.
3. **서버가 팬을 켤 때:** 몇 시간 뒤 습도가 높아 서버가 팬을 켠다. 홈 타일은 "켜짐"이 된다. 카운트다운("59m 뒤 꺼짐")은 **뜨지 않고**, 1시간 뒤 "팬 타이머가 끝났어요" 알림도 **오지 않는다**. 시트를 열면 작동 시간 칩이 아무것도 선택되지 않은 상태다(D5-b).
4. **제어 기록:** 온습도 상세의 사육장 제어 기록에 "자동 환기 켜짐 / 오후 1:30 · 습도 높음"이 한 줄 보인다. 2시간 동안 계속 돌았어도 줄과 차트 마커는 하나다. 꺼질 때는 "자동 환기 꺼짐 / 오후 3:31 · 적정 범위 도달"과 온습도 변화(델타)가 보인다. 자정 전에 시작한 자동 환기는 그날 첫 줄의 시작을 모를 수 있다(기존 한계와 같다).
5. **예약과 겹칠 때:** 구간 예약이 팬을 돌리는 중이어도 자동 환기 스위치는 그대로 조작할 수 있다. 서버는 그 구간 동안 자동을 쉰다(D2-b).
6. **분무 시트:** 탭 아래에 분무 시간 칩과 [1회 분사 시작]이 있고, 그 아래 구분선 다음에 "자동 분무" 스위치와 "습도가 40% 미만으로 내려가면 자동으로 1회 분무"가 있다(Figma `1783:12062`, 2026-11-06 — 구 D3-a 대체). 자동 분무는 "자동 분무 3초 작동 / 오전 9:12 · 습도 낮음"으로 남는다. 바로 이어 손으로 분무해도 그 줄에 합쳐지지 않는다.
7. **지원하지 않는 기기:** 텔레메트리를 받기 전이거나, 텔레메트리에 `fan`이 오지 않는 기기에서는 자동 환기 줄이 없다. 분무도 `relay` 기준으로 같다.

## Global Constraints

- **문자열·색:** 하드코딩 문자열 금지 — `assets/l10n/ko.json` 키 + `.tr()`. 하드코딩 색 금지 — `context.glass` 역할색.
- **로딩:** CircularProgressIndicator 금지. 로딩은 shimmer(`ControlLoadingOverlay`·스켈레톤).
- **시트 안 안내:** 스낵바가 아니라 `ControlFeedback.of(context).show(text)`(CLAUDE.md — 시트가 루트 모달이라 스낵바가 시트 뒤에 그려진다).
- **글자 크기:** Figma 그대로. 스위치 줄 18/600, 설명 14/500 lh16.8 ls −0.28 `textTertiary`(#949090).
- **상태 관리:** Riverpod만. 시트의 기존 지역 `setState` 패턴은 유지하고, 새 전역 상태를 setState로 만들지 않는다.
- **토글 저장:** 낙관적 반영을 하지 않는다(`DeviceSettingsNotifier` 규칙). 서버 응답 값을 그린다.
- **출시 스위치:** `kAutoEnvReleased = false`인 동안 바뀌는 건 토글이 안 보인다는 것뿐이다. 다음은 스위치와 무관하게 늘 동작한다(서버 배포 전엔 자동 행이 없어 화면 변화도 없다).
  - 타이머 수정(Task 2)
  - 제어 기록의 `source='auto'`·`reason` 해석(Task 3)
- **커밋:** 커밋마다 `flutter analyze` 0 + 관련 테스트 통과. `lib/` 변경 커밋은 `pubspec.yaml` 버전 올림(fix→patch, feat→minor) + `CHANGELOG.md` 한글 항목.
- **작업 공간:** `tools/worktree.sh new feat/auto-env`(최신 main 기준), 끝나면 `finish`. Task 2는 따로 먼저 병합해도 된다.
- **건드리지 않는 것:**
  - 서버 판정을 앱에서 다시 계산하지 않는다(문구에 쓰는 MIN/MAX만 읽음).
  - 냉각팬 시트(서버가 자동으로 켜지 않음), 예약 편집기·목록, 제어 확인 대기(`control_pending.dart`).
  - 홈 `actuatorMarkersProvider`(현재 실화면 소비처 없음).
  - v4 온습도 알림.
  - 홈 타일의 오프라인 잠금.
  - 온습도 상세 제어 기록의 실시간 갱신 — 지금도 화면을 다시 열어야 반영된다. 자동 명령만의 문제가 아니라 범위 밖이다.
  - `auto_env_state`의 `schedule_hold`·`paused_until`·`runtime_today_sec`·`mist.*`(D2 후속, Figma에 없음).

## Review Focus

1. **서버가 모르는 필드를 무시** — 마이그레이션 전 서버가 `auto_*_enabled`를 무시하고 200을 주면, 스위치가 아무 안내 없이 꺼짐으로 돌아간다. → Task 1: 응답 값이 보낸 값과 다르면 실패로 throw. Task 4: 안내가 뜨는지 테스트.
2. **사용자 타이머와 자동이 섞임** — 사용자 30분 타이머 뒤에 자동 `fan_on`이 오면 칩이 사라져야 한다. 반대 순서면 칩이 떠야 한다. → Task 2 테스트 2개.
3. **합친 자동 환기의 지속 시간·델타** — 1시간이 넘는 자동 환기도 꺼짐 줄에 전체 지속 시간과 델타가 나와야 한다(기존 `expired` 판정과 충돌). → Task 3 테스트(운영과 같은 행 모양: 1시간 + 수 초 뒤 재켜짐, 마지막 auto off).
4. **글자 확대** — 설명 두 줄이 1.3배·상한에서 넘치지 않는다. → Task 4에서 `text_scale_overflow_test.dart`에 두 시트 추가.
5. **연타·저장 중 닫기** — 저장 왕복 중 재탭은 무시한다. 저장 중 시트를 닫아도 예외가 없다. → Task 1(keepAlive)·Task 4 테스트.

---

### Task 1: 자동 설정·상태 도메인과 저장

**Files:**
- Create: `lib/features/home/domain/auto_env.dart`
- Create: `lib/features/home/presentation/auto_env_providers.dart`
- Modify: `lib/features/my_cage/domain/device_settings.dart`, `lib/features/my_cage/data/device_settings_repository.dart`, `lib/features/my_cage/presentation/device_settings_providers.dart`
- Modify: `lib/features/my_cage/domain/device.dart` (`Device`·`DeviceLinkStatus`에 `autoEnv`)
- Modify: `assets/l10n/ko.json` (이 기능의 문구 키 전부 — Task 3·4가 쓴다)
- Test: `test/features/home/auto_env_test.dart`, `test/features/my_cage/device_settings_range_test.dart`(추가)

**Context:**
- Depends on: 없음
- Produces:
  - `const bool kAutoEnvReleased = false;` (`auto_env.dart`)
  - `class AutoEnvState { final bool ventActive; static const none = AutoEnvState(ventActive: false); static AutoEnvState fromJson(Object? raw); ==/hashCode }`
  - `enum AutoEnvReason { ventHumidHigh, ventTempHigh, ventBoth, ventEnd, ventCold, ventCap, ventDisabled, mist; static AutoEnvReason? fromWire(Object? s); String get labelKey; }`
    - wire 값(계약 C2): `auto_vent:humid_high`, `auto_vent:temp_high`, `auto_vent:humid_high+temp_high`, `auto_vent_end`, `auto_vent_cold`, `auto_vent_cap`, `auto_vent_disabled`, `auto_mist`. 모르는 값·null은 null.
    - `labelKey` = `auto_reason_` + 이름을 snake_case로(`ventHumidHigh` → `auto_reason_vent_humid_high`).
  - `DeviceSettings.autoVentEnabled`, `autoMistEnabled`(bool, 기본 false). `patchBody(..., bool? autoVentEnabled, bool? autoMistEnabled)` → `auto_vent_enabled`/`auto_mist_enabled`.
  - `DeviceSettingsRepository.patch(..., bool? autoVentEnabled, bool? autoMistEnabled)`
  - `class AutoEnvSaveMismatch implements Exception {}` + `DeviceSettingsNotifier.saveAuto({bool? vent, bool? mist}) → Future<void>`
  - `Device.autoEnv`, `DeviceLinkStatus.autoEnv`(`AutoEnvState`, `==`/`hashCode`에 포함, `of`/`fromJson` 둘 다 채움)
  - `autoEnvReleasedProvider = Provider<bool>((_) => kAutoEnvReleased)` — 테스트에서 override
  - `autoEnvStateProvider = Provider.autoDispose.family<AutoEnvState, String>` — `deviceLinkStatusProvider(id)`를 `select`해 `autoEnv`만 본다(값이 없으면 `none`).
- Must know:
  - **`auto_env_state` 파싱:** jsonb다. `vent.active == true`일 때만 true. 그 밖(키 없음·다른 타입)은 false. 파싱은 throw하지 않는다.
  - **설정 bool 파싱:** `== true`만 true(서버가 `"true"` 문자열을 보내도 false).
  - **`saveAuto` 실패 처리:** 응답의 해당 값이 보낸 값과 다르면 `AutoEnvSaveMismatch`를 throw하고 state를 바꾸지 않는다(Review Focus 1).
  - **`saveAuto` 수명:** 저장하는 동안 `ref.keepAlive()`로 provider를 붙잡고 끝나면 닫는다(autoDispose — 시트를 닫아도 예외 없음, Review Focus 5).
  - **비교는 값으로:** `DeviceLinkStatus`는 3초마다 오는 생존 신호 행에도 다시 만들어진다. `AutoEnvState.==`가 값 비교여야 하위가 다시 그려지지 않는다(`device.dart:99-109`).
  - **문구(ko.json):**
    - Task 3: `env_detail_auto_vent_on` "자동 환기 켜짐", `env_detail_auto_vent_off` "자동 환기 꺼짐", `env_detail_auto_mist_for` "자동 분무 {}초 작동", `env_detail_time_reason` "{} · {}"
    - 원인: `auto_reason_vent_humid_high` "습도 높음", `auto_reason_vent_temp_high` "온도 높음", `auto_reason_vent_both` "온도·습도 높음", `auto_reason_vent_end` "적정 범위 도달", `auto_reason_vent_cold` "온도 낮음", `auto_reason_vent_cap` "하루 최대 시간", `auto_reason_vent_disabled` "자동 환기 끔", `auto_reason_mist` "습도 낮음"
    - Task 4: `auto_vent_label` "자동 환기", `auto_mist_label` "자동 분무", `auto_mist_desc` "습도가 {}% 미만으로 내려가면 자동으로 1회 분무", `auto_env_save_failed` "자동 설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요", `auto_env_load_failed` "자동 설정을 불러오지 못했어요"
    - `auto_vent_desc`: D1-a면 "습도 {}% 초과 1시간 이상 또는 온도 {}℃ 초과 시 자동 환기를 시작하고, 적정 범위에 도달하면 종료합니다". D1-b면 디자이너 확정 문구(인자 순서 습도 MAX, 온도 MAX 유지).
- Acceptance: 아래 테스트 통과, `flutter analyze` 0.

- [ ] **Step 1: 실패하는 테스트**

```dart
test('설정 파싱 — 자동 토글', () {
  expect(DeviceSettings.fromJson({'device_id': 'd', 'auto_vent_enabled': true}).autoVentEnabled, isTrue);
  expect(DeviceSettings.fromJson({'device_id': 'd'}).autoMistEnabled, isFalse);
  expect(DeviceSettings.fromJson({'device_id': 'd', 'auto_mist_enabled': 'true'}).autoMistEnabled, isFalse);
});
test('패치 본문 — 자동 토글만', () => expect(
    DeviceSettings.patchBody(autoVentEnabled: false), {'auto_vent_enabled': false}));
test('auto_env_state 파싱', () {
  expect(AutoEnvState.fromJson({'vent': {'active': true}}).ventActive, isTrue);
  expect(AutoEnvState.fromJson(null), AutoEnvState.none);
  expect(AutoEnvState.fromJson({'vent': 'x'}), AutoEnvState.none);
});
test('reason wire', () {
  expect(AutoEnvReason.fromWire('auto_vent:humid_high+temp_high'), AutoEnvReason.ventBoth);
  expect(AutoEnvReason.fromWire('auto_mist'), AutoEnvReason.mist);
  expect(AutoEnvReason.fromWire('nope'), isNull);
  expect(AutoEnvReason.ventHumidHigh.labelKey, 'auto_reason_vent_humid_high');
});
test('DeviceLinkStatus는 auto_env_state를 싣고 값으로 비교한다', () {
  final a = DeviceLinkStatus.fromJson({...linkBase, 'auto_env_state': {'vent': {'active': true}}});
  final b = DeviceLinkStatus.fromJson({...linkBase, 'auto_env_state': {'vent': {'active': true}}});
  expect(a.autoEnv.ventActive, isTrue);
  expect(a, b);
});
test('서버가 값을 무시하면 저장 실패', () async {
  final c = containerWith(fakeSettingsRepo(patchResponse: {'device_id': 'd'})); // 필드 없는 200
  await c.read(deviceSettingsProvider('d').future);
  await expectLater(c.read(deviceSettingsProvider('d').notifier).saveAuto(vent: true),
      throwsA(isA<AutoEnvSaveMismatch>()));
  expect(c.read(deviceSettingsProvider('d')).value!.autoVentEnabled, isFalse);
});
```

(`linkBase`는 테스트 안 최소 기기 행 `{'is_online': true, 'last_seen_at': null}`이다. `containerWith`·`fakeSettingsRepo`는 테스트 파일 안 헬퍼로, `deviceSettingsRepositoryProvider`를 override한다.)

- [ ] **Step 2: 실패 확인** — `flutter test test/features/home/auto_env_test.dart test/features/my_cage/device_settings_range_test.dart` → FAIL(심볼 없음)
- [ ] **Step 3: 구현** — Produces·Must know 그대로
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS, `flutter analyze` 0
- [ ] **Step 5: 커밋** `feat(auto-env): 자동 환기·분무 설정·상태 도메인(출시 스위치 꺼짐)` — 버전 minor + CHANGELOG "변경(내부)"

### Task 2: 자동으로 켜진 팬을 사용자 타이머로 세지 않기

**Files:**
- Modify: `lib/features/home/domain/running_timer.dart` (`fanTimerFrom` + 공용 컬럼 상수)
- Modify: `lib/features/home/presentation/widgets/running_timer_chip.dart:50`, `lib/features/home/data/fan_timer_notification_resync.dart:35-36`
- Test: `test/features/home/running_timer_test.dart`

**Context:**
- Depends on: 없음(Task 1과 독립이라 먼저 병합·배포해도 된다)
- Produces: `const kFanTimerColumns = 'id, device_id, action, status, result, payload, issued_at, source';` (`running_timer.dart`). 칩 provider와 재동기화가 둘 다 이 상수로 select한다.
- Must know:
  - **규칙:** 기존 유효성 검사(`acked`+`ok`, 미ACK 유예)를 통과한 **최신 행**이 `source == 'auto'`이면 `null`(사용자 타이머 아님)을 돌려준다. 자동 `fan_off`는 원래도 onAction이 아니라 null이다.
  - **출시 스위치와 무관:** `source`는 이미 있는 컬럼이다. 다른 폰(신 앱)에서 자동을 켜면 이 폰도 영향을 받는다.
  - **한 곳만 고치면 된다:** 홈 타일 부제, 시트 칩 선택(`_seedFanChoice`), 로컬 "타이머 끝" 알림이 모두 이 판정을 쓴다.
  - **받아들인 한계:** 사용자 타이머 직후 미ACK 유예(15초) 안의 자동 명령이 오면, 칩이 최대 15초 사라졌다 돌아올 수 있다(계약 §4 "명령 겹침"과 같은 범주).
- Acceptance: 아래 테스트 PASS. 기존 `running_timer_test.dart` 전부 PASS.

- [ ] **Step 1: 실패하는 테스트**

```dart
test('자동 fan_on은 타이머가 아니다', () {
  final rows = [fanOn(issuedAt: now.subtract(const Duration(minutes: 5)), ms: 3600000, source: 'auto')];
  expect(RunningTimer.fanTimerFrom(rows, now), isNull);
});
test('사용자 타이머 뒤 자동 fan_on이 오면 칩이 사라진다', () {
  final rows = [
    fanOn(issuedAt: now.subtract(const Duration(minutes: 1)), ms: 3600000, source: 'auto'),
    fanOn(issuedAt: now.subtract(const Duration(minutes: 10)), ms: 1800000, source: 'app'),
  ];
  expect(RunningTimer.fanTimerFrom(rows, now), isNull);
});
test('자동 fan_on 뒤 사용자 타이머는 칩이 뜬다', () {
  final rows = [
    fanOn(issuedAt: now.subtract(const Duration(minutes: 1)), ms: 1800000, source: 'app'),
    fanOn(issuedAt: now.subtract(const Duration(minutes: 20)), ms: 3600000, source: 'auto'),
  ];
  expect(RunningTimer.fanTimerFrom(rows, now)?.durationMinutes, 30);
});
```

(`fanOn`은 테스트 파일 안 헬퍼다. 기존 행 모양에 `'source'` 키를 더한다.)

- [ ] **Step 2: 실패 확인** — `flutter test test/features/home/running_timer_test.dart` → 첫째·둘째 FAIL
- [ ] **Step 3: 구현** — Must know의 규칙 + 두 쿼리를 `kFanTimerColumns`로 교체
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS, `flutter analyze` 0
- [ ] **Step 5: 커밋** `fix(fan-timer): 서버 자동 환기 명령을 사용자 타이머로 세지 않음` — 버전 patch + CHANGELOG "수정"

### Task 3: 제어 기록에 자동 명령 표시

**Files:**
- Modify: `lib/shared/domain/control_log.dart` (`ControlLogEntry.auto`·`reason`, 자동 재켜짐 합치기, 분무 묶기 분리)
- Modify: `lib/features/home/data/command_history_repository.dart` (`readPeriod`·`readPreceding`의 `_columns` → `select()`)
- Modify: `lib/features/home/presentation/widgets/control_log_list.dart` (제목·시각 줄)
- Test: `test/features/shared/control_log_test.dart`, `test/features/home/command_history_repository_test.dart`, `test/features/home/control_log_list_test.dart`

**Context:**
- Depends on: Task 1 (`AutoEnvReason`, 문구 키)
- Consumes: `AutoEnvReason.fromWire`, `.labelKey`
- Produces: `ControlLogEntry`에 `final bool auto;`(기본 false), `final AutoEnvReason? reason;`
- Must know:
  - **조회:** `readPeriod`·`readPreceding`은 컬럼 목록 대신 `select()`(전체 컬럼)를 쓴다. `reason`이 없는 서버에서도 400이 나지 않는다(`fetchLinkStatus`와 같은 이유, `supabase_module_control_repository.dart:73-74`). `recentScheduleRuns`의 자체 컬럼 목록은 그대로 둔다. 기존 테스트가 컬럼 문자열을 단언하면 맞게 고친다.
  - **해석:** `auto = r['source'] == 'auto'`. `reason`은 행에 키가 있을 때만 `fromWire`로 읽는다.
  - **D4 합치기**(파싱·정렬 뒤, 델타 짝짓기 전):
    - 자동 `fan_on`이 직전 자동 `fan_on`(묶음의 마지막 회차)의 `at + timerMs + 10분` 안이면 합친다.
    - 사이에 같은 kind(fan)의 다른 명령이 없어야 한다. 비자동 on/off/toggle이나 자동 off가 끼면 끊는다.
    - 합칠 때 묶음 첫 줄의 `timerMs`를 `(마지막 회차 at + 그 timerMs) − 첫 줄 at`으로 늘린다. 그래야 기존 `expired` 판정(`control_log.dart:212-225`)이 꺼짐 줄의 `startedAt`·델타를 지우지 않는다.
  - **분무 묶기 분리:** 기존 8초 분무 묶기는 `auto`가 같은 행끼리만 묶는다(자동 3초 직후의 손 분무가 합쳐지지 않게).
  - **받아들인 한계:** 자정 전부터 이어진 자동 환기는 `readPreceding`이 직전 1건만 읽어서 첫 시작을 모를 수 있다. 그날 꺼짐 줄의 지속 시간·델타가 빠질 수 있다(기존 수동 명령과 같은 한계).
  - **제목 규칙:**
    - `auto` + fan: on/off에 따라 `env_detail_auto_vent_on/off`
    - `auto` + mist: `sprayMs`가 있으면 `env_detail_auto_mist_for`, 없으면 초를 추측하지 않고 `env_detail_ran`에 `auto_mist_label`
    - 그 밖: 기존 규칙
  - **시각 줄:** `reason`이 있으면 `env_detail_time_reason`(시각 · 원인), 없으면 시각만.
  - **테스트 헬퍼:** 기존 `row(action, at)`(`control_log_test.dart:6`)에 이름 인자 `source`, `reason`, `ms`를 더한다.
- Acceptance: 아래 테스트 PASS. 기존 control_log·history·list 테스트 PASS.

- [ ] **Step 1: 실패하는 테스트**

```dart
// control_log_test.dart
test('자동 명령 표시 정보', () {
  final log = buildControlLog(commandRows: [
    row('fan_on', t0, source: 'auto', reason: 'auto_vent:humid_high', ms: 3600000),
  ], buckets: const []);
  expect(log.single.auto, isTrue);
  expect(log.single.reason, AutoEnvReason.ventHumidHigh);
});
test('매시간 다시 켠 자동 환기는 한 줄 + 전체 지속 시간', () {
  final log = buildControlLog(commandRows: [
    row('fan_on', t0, source: 'auto', ms: 3600000),
    row('fan_on', t0.add(const Duration(minutes: 60, seconds: 5)), source: 'auto', ms: 3600000),
    row('fan_off', t0.add(const Duration(minutes: 90)), source: 'auto', reason: 'auto_vent_end'),
  ], buckets: const []);
  expect(log.map((e) => e.state), [ControlLogState.on, ControlLogState.off]);
  expect(log.last.duration, const Duration(minutes: 90));
});
test('재명령이 5분 늦어도 합친다', () {
  final log = buildControlLog(commandRows: [
    row('fan_on', t0, source: 'auto', ms: 3600000),
    row('fan_on', t0.add(const Duration(minutes: 66)), source: 'auto', ms: 3600000),
  ], buckets: const []);
  expect(log.length, 1);
});
test('사이에 사용자 명령이 끼면 합치지 않는다', () {
  final log = buildControlLog(commandRows: [
    row('fan_on', t0, source: 'auto', ms: 3600000),
    row('fan_on', t0.add(const Duration(minutes: 10)), source: 'app', ms: 1800000),
    row('fan_on', t0.add(const Duration(minutes: 50)), source: 'auto', ms: 3600000),
  ], buckets: const []);
  expect(log.length, 3);
});
test('자동 분무 직후 손 분무는 따로', () {
  final log = buildControlLog(commandRows: [
    row('mist', t0, source: 'auto', ms: 3000),
    row('mist', t0.add(const Duration(seconds: 5)), source: 'app', ms: 3000),
  ], buckets: const []);
  expect(log.map((e) => e.auto), [true, false]);
});
// control_log_list_test.dart
testWidgets('자동 환기 줄', (t) async {
  await pumpLog(t, [entry(kind: MarkerKind.fan, state: ControlLogState.on, auto: true, reason: AutoEnvReason.ventHumidHigh)]);
  expect(find.text('자동 환기 켜짐'), findsOneWidget);
  expect(find.textContaining('· 습도 높음'), findsOneWidget);
});
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/shared/control_log_test.dart test/features/home/command_history_repository_test.dart test/features/home/control_log_list_test.dart` → FAIL
- [ ] **Step 3: 구현** — Produces·Must know 그대로
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS, `flutter analyze` 0
- [ ] **Step 5: 커밋** `feat(control-log): 서버 자동 환기·분무 명령을 "자동"으로 표시` — 버전 minor + CHANGELOG "추가"(서버 배포 뒤 보임)

### Task 4: 제어 시트 자동 토글

**Files:**
- Create: `lib/features/home/presentation/widgets/auto_env_toggle.dart` (`AutoEnvToggle`)
- Modify: `lib/features/home/presentation/widgets/device_control_sheet.dart` (환기는 `_immediate`의 `ScheduleDevice.fan` 분기 뒤, 분무는 `_mist` 맨 위, `_seedFanChoice`의 D5)
- Test: `test/features/home/auto_env_toggle_test.dart`, `test/features/home/device_control_sheet_test.dart`(추가), `test/design/text_scale_overflow_test.dart`(추가)

**Context:**
- Depends on: Task 1
- Consumes: `deviceSettingsProvider(deviceId)` + `.notifier.saveAuto`, `autoEnvStateProvider(deviceId)`, `autoEnvReleasedProvider`, `telemetryStreamProvider(deviceId)`
- Produces:
  - `AutoEnvToggle({required String label, required String description, required bool value, required bool enabled, required bool loading, required ValueChanged<bool> onChanged, Key? key})` — 표시 전용(상태 없음).
  - 키: `DeviceControlSheet.autoVentKey = Key('auto_vent_toggle')`, `autoMistKey = Key('auto_mist_toggle')`.
- Must know (Figma 수치는 `1635:6168`·`1657:5353` 실측 — 분무 배치는 2026-11-06 `1783:12062`로 바뀜, D3 참고):
  - **스위치 줄:** 345×48, r16, 바탕 `surfaceHeader`(#FFFFFF), 왼쪽 패딩 12, 라벨 18/600 ls −0.36 `textSecondary`(#3C3C3C). 스위치는 기존 `ScheduleSwitch`(80×32).
  - **설명:** 스위치 줄 아래 8, 좌우 12, 14/500 lh16.8 ls −0.28 `textTertiary`(#949090), 줄 수 제한 없음.
  - **비활성 모양:** 바탕 `outline`(#E3E3E3), 라벨 `textTertiary` — `1657:5326` 실측.
  - **배치:**
    - 환기 시트: 작동 시간 칩 아래 24 → 1px 선(`outline`, 전폭) → 20 → 자동 환기 블록.
    - 분무 시트(D3-a): 탭 아래 24 → 자동 분무 블록(선 없음) → 24 → 분사 시간 칩 → 24 → CTA.
  - **설명에 넣는 값:** 환기는 `settings.humidRange.max`, `settings.tempRange.max`. 분무는 `settings.humidRange.min`. 숫자는 `formatCompact`.
  - **보이는 조건:** `autoEnvReleasedProvider == true` **그리고** 텔레메트리를 받았고 해당 필드(`fan`/`relay`)가 `unavailable`이 아님. 텔레메트리가 없으면 보이지 않는다(지원을 모르는 기기에 설정하지 않는다). 냉각팬·LED 시트에는 없다.
  - **활성 조건:** 설정이 `AsyncData`이고 저장 중이 아님. `schedule_hold`는 보지 않는다(D2-b).
    - 설정 로딩 중: 블록 자리에 같은 높이의 shimmer 스켈레톤.
    - 설정 에러: 비활성 + 설명 대신 `auto_env_load_failed`.
  - **저장 흐름:**
    1. 탭하면 먼저 기존 `_targetStillValid()`로 기기 해제·세트 변경을 확인한다.
    2. 지역 상태 `_autoSaving = true`로 두고, 줄 위에 `ControlLoadingOverlay`를 그린다.
    3. `saveAuto(vent:/mist:)`를 호출한다.
    4. 실패(`AutoEnvSaveMismatch` 포함)면 `ControlFeedback.of(context).show('auto_env_save_failed'.tr())`.
    - 저장 중 재탭은 무시한다. `mounted`를 확인한 뒤 상태를 바꾼다.
    - 시트의 기존 `_busy`(명령 왕복)와 섞지 않는다. 자동 저장 중에도 수동 제어는 된다.
  - **D5:** `_seedFanChoice`에서 `autoEnv.ventActive && timer == null`이면 칩 선택을 비운다(`_fanChoice`를 "없음" 상태로 — 기존 null은 "계속"이라, "선택 없음"을 나타낼 별도 표시가 필요하다. 예: `bool _fanChoiceNone`).
- Acceptance: 아래 테스트 PASS. 기존 `device_control_sheet_test.dart` 전부 PASS(출시 스위치 기본값이 꺼짐이라 화면 변화 없음). `text_scale_overflow_test.dart` PASS.

- [ ] **Step 1: 실패하는 테스트**

```dart
testWidgets('스위치 꺼짐이면 자동 토글이 없다', (t) async {
  await pumpSheet(t, ScheduleDevice.fan, released: false);
  expect(find.byKey(DeviceControlSheet.autoVentKey), findsNothing);
});
testWidgets('환기 설명에 내 MAX 값', (t) async {
  await pumpSheet(t, ScheduleDevice.fan, released: true,
      settings: const DeviceSettings(deviceId: 'd', targetHumidMin: 40, targetHumidMax: 75, targetTempMin: 18, targetTempMax: 27));
  expect(find.textContaining('75%'), findsOneWidget);
  expect(find.textContaining('27℃'), findsOneWidget);
});
testWidgets('켜면 PATCH 한 번, 저장 중 재탭 무시', (t) async {
  final repo = await pumpSheet(t, ScheduleDevice.fan, released: true, patchDelay: const Duration(seconds: 1));
  await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
  await t.pump();
  await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
  await t.pump(const Duration(seconds: 2));
  expect(repo.patches, [{'auto_vent_enabled': true}]);
});
testWidgets('서버가 값을 무시하면 꺼짐 유지 + 안내', (t) async {
  await pumpSheet(t, ScheduleDevice.fan, released: true, patchIgnoresField: true);
  await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
  await t.pumpAndSettle();
  expect(find.text('자동 설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
  expect(switchValue(t, DeviceControlSheet.autoVentKey), isFalse);
});
testWidgets('저장 중 시트를 닫아도 예외 없음', (t) async {
  await pumpSheet(t, ScheduleDevice.fan, released: true, patchDelay: const Duration(seconds: 1));
  await t.tap(find.byKey(DeviceControlSheet.autoVentKey));
  await t.pump();
  await closeSheet(t);
  await t.pump(const Duration(seconds: 2));
  expect(t.takeException(), isNull);
});
testWidgets('설정 로드 실패 — 비활성 + 실패 문구', (t) async {
  await pumpSheet(t, ScheduleDevice.mist, released: true, settingsError: true);
  expect(find.text('자동 설정을 불러오지 못했어요'), findsOneWidget);
});
testWidgets('텔레메트리 없음 또는 relay 미보고 기기에는 자동 분무가 없다', (t) async {
  await pumpSheet(t, ScheduleDevice.mist, released: true, telemetry: null);
  expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
  await pumpSheet(t, ScheduleDevice.mist, released: true, telemetry: telemetry(relay: ActuatorState.unavailable));
  expect(find.byKey(DeviceControlSheet.autoMistKey), findsNothing);
});
testWidgets('분무 시트 순서 — 자동 분무가 칩보다 위', (t) async {
  await pumpSheet(t, ScheduleDevice.mist, released: true);
  final auto = t.getTopLeft(find.byKey(DeviceControlSheet.autoMistKey)).dy;
  final chip = t.getTopLeft(find.byKey(DeviceControlSheet.mistChipKey(MistDuration.values.first))).dy;
  expect(auto, lessThan(chip));
});
testWidgets('자동이 켠 팬은 작동 시간 칩이 선택되지 않는다(D5)', (t) async {
  await pumpSheet(t, ScheduleDevice.fan, released: true,
      telemetry: telemetry(fan: ActuatorState.on), autoEnv: const AutoEnvState(ventActive: true));
  expect(chipSelected(t, const Key('fan_steady_on')), isFalse);
});
```

(`pumpSheet`는 기존 `control_sheet_fixtures.dart`를 확장한다.
- override: `autoEnvReleasedProvider`, `deviceSettingsRepositoryProvider`(가짜 — 받은 PATCH 본문을 `patches`에 쌓고, 지연·에러·필드 무시를 흉내), `autoEnvStateProvider`, `telemetryStreamProvider`.
- 같은 파일의 헬퍼: `switchValue`·`chipSelected`·`closeSheet`.)

- [ ] **Step 2: 실패 확인** — `flutter test test/features/home/device_control_sheet_test.dart test/features/home/auto_env_toggle_test.dart` → FAIL
- [ ] **Step 3: 구현** — Produces·Must know 그대로. `text_scale_overflow_test.dart`에 환기·분무 시트를 released=true로 추가(1.0/1.3/상한).
- [ ] **Step 4: 통과 확인** — 같은 명령 + `flutter test test/design/text_scale_overflow_test.dart` PASS, `flutter analyze` 0
- [ ] **Step 5: 커밋** `feat(auto-env): 환기·분무 시트 자동 토글(출시 스위치 꺼짐)` — 버전 minor + CHANGELOG "변경(내부)"

### Task 5: 출시 (P1·P3 뒤)

**Files:**
- Modify: `lib/features/home/domain/auto_env.dart` (`kAutoEnvReleased = true`)
- Modify: `assets/l10n/ko.json` (`auto_vent_desc` — D1 확정 문구)
- Create: `docs/design-audits/2026-11-05-auto-env/RESULTS.md`
- Modify: `CHANGELOG.md`, `pubspec.yaml`, `CLAUDE.md`(사육장 제어 요약에 자동 환기·분무 한 문단 — 계약 위치, 타이머 판정 규칙, 기록 합치기, 출시 스위치 위치)

**Context:**
- Depends on: Task 1~4, P1(D1 반영 확인), P3(서버 "전체 켬"), Q4·Q5 회신
- Must know: 스토어 배포 전에 전체 기능 테스트를 마쳐야 한다(메모리 `feedback-release-all-tested`).
- Acceptance:
  - **Claude 확인:** 화면 수치 검수(Step 2) 기록에 차이 0, 또는 차이를 보고한 뒤 확정.
  - **사용자만 확인 가능**(실기기, 테스트 허용 기기):
    - 시트에서 자동 환기를 켜면 다시 열었을 때도 켜져 있다(서버 GET 값 true).
    - 자동 환기가 동작하면 홈 타일이 "켜짐"이 되고, 카운트다운과 "타이머 끝" 알림은 없다. 시트의 작동 시간 칩은 선택되지 않는다.
    - 온습도 상세 제어 기록이 정상으로 불러와지고, "자동 환기 켜짐 / 시각 · 원인"이 한 줄로 보인다. 꺼질 때 지속 시간·델타가 있다.
    - 자동 분무 1회가 "자동 분무 3초 작동 / 시각 · 습도 낮음"으로 남는다.

- [ ] **Step 1:** 서버 문서 "배포 상태"에서 전체 켬을 확인하고, D1 문구와 Q4·Q5 회신을 반영한다(D4 창 10분이 회신과 다르면 Task 3 상수를 고친다).
- [ ] **Step 2: 화면 수치 검수** — 스위치 true 빌드로 시뮬레이터에서 캡처한다. Figma `1635:6168`(환기)·`1783:12062`(분무, 2026-11-06 개정 — 구 `1657:5353`은 삭제됨)과 간격·글자·색·버튼 위치를 대조해 `RESULTS.md`에 원본·앱 측정값과 차이를 기록한다(CLAUDE.md 페이지별 수치 검수).
- [ ] **Step 3:** `flutter analyze` 0, `flutter test` 전체 PASS
- [ ] **Step 4:** 실기기 Acceptance(사용자)
- [ ] **Step 5: 커밋** `feat(auto-env): 자동 환기·자동 분무 출시` — 버전 minor + CHANGELOG "추가" + CLAUDE.md

## 검증 방법

- **명령:** `flutter analyze`(에러 0), 아래 테스트, 마지막에 `flutter test` 전체.

  ```bash
  flutter test test/features/home/auto_env_test.dart test/features/my_cage/device_settings_range_test.dart test/features/home/running_timer_test.dart test/features/shared/control_log_test.dart test/features/home/command_history_repository_test.dart test/features/home/control_log_list_test.dart test/features/home/device_control_sheet_test.dart test/features/home/auto_env_toggle_test.dart test/design/text_scale_overflow_test.dart
  ```

- **화면:** Task 5 Step 2 시뮬레이터 캡처 대조(Claude가 직접).
- **실동작:** Task 5 Acceptance — **사용자만 확인 가능**(서버 스위치·테스트 기기 필요).
- **코드 리뷰:** Task 4 뒤 사용자가 `/code-review`를 실행한다.

## 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 스위치를 켠 빌드가 마이그레이션 전 서버에 붙음 | 제어 기록은 `select()`라 정상. 설정 PATCH는 서버가 필드를 무시하면 200이나 값 없음 → 저장 실패 안내 | Task 1 `AutoEnvSaveMismatch`. 출시 스위치는 P3 뒤에만 켠다 |
| D1 미반영 상태로 출시 | 설명은 "1시간 이상"인데 서버는 3분 뒤 켠다 → 사용자 혼란 | Task 5 Step 1에서 확인. 안 맞으면 출시 보류 |
| 서버 재켜짐이 10분 창보다 늦음 | 자동 환기가 여러 줄로 쪼개짐(기능은 정상) | Q4 회신으로 창 조정 |
| 서버 설정 캐시 60초 | 끈 직후 자동 명령이 하나 더 나감 | 서버 계약상 정상. 앱은 안내하지 않는다(Figma에 없음) |
| 자동 환기 중 사용자가 타이머 칩 → 기기 `busy` | 기존 거절 안내(`module_command_busy`)로 원위치 | 변경 없음(서버 한계 §4, 펌웨어 확인 중) |
| 구 앱(0.171.x)과 신 앱을 같이 쓰는 사용자 | 구 앱은 자동 팬에 카운트다운·"타이머 끝" 알림 | Task 2를 먼저 배포해 범위를 줄인다. 구 앱 자체는 못 고친다 |
