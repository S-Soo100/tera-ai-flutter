# 네트워크 관리 흐름 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 승인 뒤 `executing-plans`로 task 단위 구현(Implementer 분리는 CAOF v1.3 Critical 기준, 모델 상속). Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: 📝 **r3 — 2026-11-19 Figma 기준 전면 개정, 사용자 승인 대기.** r2(2026-11-16, "네트워크 변경"·종류별 1대·기기 상세 줄 제거)는 git 이력에 있다. 바뀐 이유: Figma가 그 뒤 고쳐졌다(메모리 `project_network_change_plan_figma_drift`) — 이름 "네트워크 관리", 같은 종류 여러 대 선택, 목록 오른쪽 Wi-Fi 이름·dBm, 기기 상세 "연결된 네트워크" 진입 유지, 끝 화면 "네트워크 연결 완료", 진입 1이 막대 → 신호 약함 모달 [변경].

**Goal:** 홈 헤더 메뉴 4번째 "네트워크 관리"로 들어가 근처의 이 계정 기기를 여러 대 골라 등록을 유지한 채 Wi-Fi만 한꺼번에 바꾸고, 신호 약함 모달 [변경]·기기 상세 "연결된 네트워크"·라이브 오프라인 [네트워크 변경]도 이 흐름으로 보낸다.

**Architecture:** 기존 기기 추가 흐름(`DeviceAddFlowController`/`DeviceAddFlowScreen`)에 **네트워크 관리 모드**를 더한다 — Figma 메모 "여기부터 기기추가 플로우랑 동일, 텍스트랑 리스트 변경됨"(1913:7804)대로 네트워크 선택·비밀번호·연결 단계는 그대로 쓴다. 여러 대 선택을 위해 먼저 선택·결과 맵의 키를 종류(`PairTargetKind`)에서 BLE 주소(`physicalId`)로 바꾼다(동작 불변 리팩터, 기기 추가는 계속 종류별 1대). 스캔된 BLE 기기를 이 계정 기기 행에 이 폰의 기억·`hw_id`로 맞춰 알아본 것만 보이고, 고른 기기에는 `SSID/PASS/CONNECT`만 보내 그 행 `last_seen_at`으로 판정한다(새 등록 없음). 마지막에 옛 단일 대상 모드(`WifiChangeTarget`, `/devices/wifi`)를 지운다.

**Tech Stack:** Flutter, Riverpod(StateNotifier), GoRouter, flutter_blue_plus(기존 `DeviceAddBleAdapter`), Supabase 직결 SELECT, easy_localization.

**Spec:** Figma `네트워크 신호 약함` 섹션 `1877:14741`(talk-to-figma 채널 `axgnvoxa`, 2026-11-19 조회) + 아래 사용자 결정(2026-11-19). 관련: `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`(맨 위 11-19 상자), `docs/ble-provisioning-protocol.md`, `docs/handoffs/2026-11-19-wifi-ssid-report-request.md`.

### Figma 노드 → 결정

| Figma | 결정 |
|---|---|
| 진입 1 `2020:11196` 모달 [변경] → `1913:6462` | 신호 약함 모달 [변경] → 네트워크 관리, 그 카메라 미리 체크 |
| 진입 2 `1913:7111` 헤더 메뉴 "네트워크 관리" → `1913:6462` | 메뉴 4번째 "네트워크 관리", 아무것도 체크 안 됨 |
| 진입 3 `1913:7413`/`1913:7510` 기기 상세 "연결된 네트워크 ·  iptime… >" / "추가하기 >" → `1913:6462` | 기기 상세 줄 이름을 "연결된 네트워크"로, 누르면 네트워크 관리 + 그 기기 미리 체크 |
| `1913:6462`(검색 중)·`1913:6570`(선택) | 상단 "네트워크 관리", 본문 제목 "네트워크에 연결할 기기 선택", 부제 2줄, 줄 = 이름·`hw_id` / Wi-Fi 이름·dBm·신호 그림 또는 "네트워크 연결 없음" / 체크. 같은 종류 여러 대 체크 |
| `1913:6573` "기기 2개 네트워크 연결"(체크 3개 그림) | 문구는 "기기 {}개 네트워크 연결", 숫자는 실제 체크 수(그림의 2는 시안 오기로 본다) |
| `1913:6618`~`6772` | 기기 추가의 네트워크 선택·비밀번호 화면 그대로, 상단만 "네트워크 관리" |
| `1913:7778` | 끝 화면: check_circle 64 + "네트워크 연결 완료" 600/18 + [확인] |
| 옛 막대 스낵바 `asis`(2020:11224) | 진입점 아님 — 이미 모달로 교체됨(0.185.0) |

### 사용자 결정 (2026-11-19)

1. **Wi-Fi 이름:** 아는 것만 보인다(서버 `wifi_ssid` → 이 폰의 기억 순). 모르면 dBm만. 서버·펌웨어 보고는 이관훈님께 요청(`docs/handoffs/2026-11-19-wifi-ssid-report-request.md`).
2. **여러 대:** Figma대로 같은 종류도 여러 대. 카메라부터 한 대씩 차례로.
3. **결과:** 전부 붙으면 Figma 완료 화면, 하나라도 안 붙거나 확인 못 하면 기기별 결과 목록 + [다시 찾기](Figma 밖, 기존 결과 틀).
4. **카메라 3분 광고 안내:** 넣지 않는다(Figma 문구만).

## 가정

- 확인:
  - 기기 추가: `DeviceAddState.selected: Map<PairTargetKind, DeviceAddCandidate>`, `results: Map<PairTargetKind, DeviceAddResult>`(`domain/device_add_flow.dart:191-261`) — 키를 바꾸는 범위는 lib 약 75곳·test 약 90곳(대부분 `results[c.kind]` 꼴).
  - Wi-Fi만 바꾸기 `_updateWifi`(`wifiOnly: true`)·서버 판정 `_watchReconnect`·`trusted` 규칙이 있다(`device_add_flow_controller.dart:638-767`). 연결 순서 카메라 먼저(`:431-440`).
  - 서버: `devices`·`cameras`에 `wifi_ssid` 없음(2026-11-19 조회). 신호 세기 `devices.sys_state.rssi`, `cameras.clip_stats.sys.rssi`(`SysHealth.fromDeviceRow/fromCameraRow`, `kWeakRssi = -75`). 앱은 이미 `row['wifi_ssid']`를 읽는 자리가 있다(`redesign_group_repository.dart:107`).
  - 기기 상세 "기기 정보" 값 = `hw_id`(`device_detail_screen.dart:182`) — Figma 줄 둘째 줄 `viva-iot-1234`와 같은 값.
  - 기기 상세 Wi-Fi 줄(`Key('device_wifi_change')`, `:288-327`)은 이미 아이콘·이름·값·화살표 구조 — 라벨·값·이동만 바꾸면 Figma와 같다.
  - 카메라는 켜진 뒤 3분만 BLE 광고(`docs/ble-provisioning-protocol.md:16`).
  - 중첩 scope provider는 `dependencies` 누락 시 릴리스에서 root 기본값을 읽는다(2026-09-22 사고).
- 미확인 (→ Task 8 실기기, 사용자만 가능):
  - 켜진 지 오래된 사육장이 BLE 광고를 계속하는지.
  - 사육장이 `SSID/PASS/CONNECT`만으로 같은 `device_id`로 붙는지(`kWifiChangeDeviceEnabled`).
  - `bleMatchesHardware`(차이 0·2)가 실제로 맞는지, iOS 사육장 광고 이름 끝 `_XXXX` 여부.

## 선택지와 추천

| 결정 | 선택지 | 추천 |
|---|---|---|
| 구현 방식 | A. 기존 흐름에 모드 추가 / B. 새 컨트롤러·화면 | **A** — Figma가 "기기추가 플로우랑 동일"이라 명시. 네트워크·비밀번호·판정이 이미 검증됨. B는 화면 비공개 메서드(`_networks`·`_credentials`) 추출이 커진다 |
| 여러 대 선택 | 선택·결과 맵 키를 `physicalId`로(전 모드) / 네트워크 모드 전용 맵 추가 | **키 변경** — 맵 두 벌이면 화면·연결 코드가 모드마다 갈린다. 리팩터는 단독 task·단독 커밋으로 되돌리기 쉽게 |
| 목록에 보일 기기 | 알아본 것만 / 전부 | **알아본 것만** — 모르는 기기는 판정할 행이 없다 |
| 알아보기 근거 | 이 폰의 기억 우선, 없으면 `hw_id`. 한 BLE↔여러 행, 한 행↔여러 BLE면 숨김 | 오인 방지가 빈 줄보다 중요 |
| 판정 신뢰 | 기억으로 알아봤거나 원래 오프라인 → "연결됐어요" / `hw_id`로만 알아본 온라인 기기 → 기존 "연결돼 있어요(확인 못 함)" | 옛 Wi-Fi 하트비트를 성공으로 단정하지 않는다 |
| 목록 순서 | 미리 체크된 기기 → 연결 없음 → 신호 약한 순 → 이름 | 바꿔야 할 기기가 위에(부제 "dBm이 낮은 기기는 네트워크 변경을 권장") |
| 기기 상세 값(이름 모름) | 온라인·이름 모름 → `--`(지금과 같음) / 오프라인 → "추가하기"(Figma 1913:7510) | Figma "네트워크 연결 없을 때 = 추가하기" |
| [새 기기로 등록] | 네트워크 관리 모드에선 숨김 + 컨트롤러 거부 | 이 흐름은 등록하지 않는다 |

## 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 켜져 있는 카메라(3분 지남) | 목록에 없음 | 사용자 결정 4: 안내 없음. [다시 스캔] |
| 근처에 이 계정 기기 없음 | 빈 목록 | 기존 빈 상태 문구 + [다시 스캔] |
| `hw_id` 매칭이 틀림 / iOS 끝자리 없음 | 못 알아봄 | 이 폰의 기억으로는 계속 알아본다. Task 8 결과가 나쁘면 범위 재논의 |
| 한 행에 맞는 BLE가 둘 | 둘 다 숨김 | 엉뚱한 기기에 Wi-Fi를 보내지 않는다 |
| 검색 뒤 연결 전 행이 해제·대체됨 | 보내기 직전 재확인 실패 | 그 기기 결과 "이 계정 기기가 아니에요"(`device_wifi_target_gone`), 다음 기기는 계속 |
| 여러 대 중 한 대 BLE 실패 | 그 기기만 실패, 다음 기기 진행 | 결과 목록(결정 3) |
| 사육장이 같은 행에 안 붙음 | 90초 뒤 "신호가 오지 않아요" | Task 8에서 확인되면 `kWifiChangeDeviceEnabled=false` → 사육장 목록 제외 |
| 기기 목록 조회 실패 | 아무것도 못 알아봄 | `ownedLoadFailed` 안내 + [다시 스캔] 재조회 |
| 늦게 끝난 매칭(네트워크 단계 뒤) | — | 미리 체크는 `step == scan`일 때만, 한 번만 |
| 체크한 여러 기기 중 첫 기기의 Wi-Fi 목록만 받음 | 다른 기기 근처 Wi-Fi가 다를 수 있음 | 기존과 같다(첫 기기로 검색). [직접 입력] 있음 |

## 유저 체험 시뮬레이션

1. 홈 라이브에 신호 약함 창이 뜬다 → [변경]. 상단 "네트워크 관리", 본문 "네트워크에 연결할 기기 선택" 옆 검색 중 표시, 부제 두 줄, 아래 [다시 스캔](검색 중 회색).
2. 몇 초 뒤 "카메라 4" 줄이 나타나며 이미 체크돼 있다. 줄 왼쪽은 카메라 아이콘·"카메라 4"·그 아래 회색 `p4cam-…`(기기 정보 값). 오른쪽은 이 폰이 기억하는 Wi-Fi 이름이 있으면 굵게, 그 아래 "-78 dBm"과 막대 1칸 그림. 이름을 모르면 dBm 줄만. 오프라인 사육장 줄은 오른쪽에 "네트워크 연결 없음".
3. 사육장 두 대도 체크하면 버튼이 "기기 3개 네트워크 연결"로 바뀐다 → 네트워크 선택(상단 "네트워크 관리") → 비밀번호 → [WiFi 연결].
4. 카메라부터 한 대씩 새 Wi-Fi를 받는다. 셋 다 서버 신호가 오면 화면 가운데 체크 원·"네트워크 연결 완료", 아래 [확인] → 들어온 화면으로 돌아간다. 이름·그룹·예약·기록은 그대로다.
5. 한 대라도 안 붙으면 기기별 결과 줄("연결됐어요"/"신호가 오지 않아요"/"연결돼 있어요(확인 못 함)")과 [다시 찾기]. 새 기기로 등록하는 버튼은 없다.
6. 헤더 메뉴 맨 아래 "네트워크 관리" → 아무것도 체크되지 않은 같은 화면. 기기 상세 "연결된 네트워크 · iptime… >"(오프라인이면 "추가하기 >") → 그 기기가 체크된 같은 화면. 라이브 오프라인 [네트워크 변경] → 그 카메라가 체크된 같은 화면.

## 근본 원인·전후 동작

- 전: Wi-Fi 변경은 기기 상세 [Wi-Fi 바꾸기]·라이브 오프라인·신호 약함 모달에서 기기 한 대씩, 같은 종류 BLE 목록에서 대상을 짐작해 고르고(못 알아보면 확인 창), 결과는 한 대. 헤더 메뉴에 진입점 없음.
- 후: 네 진입점 모두 네트워크 관리 화면. 알아본 이 계정 기기만 이름·`hw_id`·Wi-Fi 이름/dBm과 함께 보이고 여러 대를 함께 바꾼다. 결과는 전부 성공이면 완료 화면, 아니면 기기별. `/devices/wifi` 없음.

## 검증 방법

1. 매 task: `flutter analyze` 오류·경고 0, 해당 테스트 통과. 마지막에 전체 `flutter test`.
2. 시뮬레이터(iPhone 13 mini): 메뉴 4항목·모달 [변경]·기기 상세 줄·라이브 오프라인 진입·목록·완료 화면·결과 목록을 커밋하지 않는 디버그 주입으로 캡처 → `docs/design-audits/2026-11-19-network-manage/RESULTS.md`에 Figma 수치 대조(3배 PNG, 앱 1125 폭 맞춤).
3. **실기기(사용자만):** Task 8 항목. 판정은 `[device-add] network-match` 로그, 운영 DB 같은 `id`의 `last_seen_at` 갱신, 기기 관리에 행이 늘지 않는지.

## 사용자가 정할 것

1. **실기기 확인 시점** — 추천: 구현 뒤(Task 8), 스토어 배포 전 필수. 사육장이 같은 행에 안 붙으면 `kWifiChangeDeviceEnabled=false`로 사육장만 뺀다(기존 결정).
2. 그 외 없음 — 2026-11-19 결정 1~4로 정했다.

## Global Constraints

- 문구(Figma 그대로): 상단 제목·메뉴 "네트워크 관리", 본문 제목 "네트워크에 연결할 기기 선택", 부제 "사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요\ndBm이 낮은 기기는 네트워크 변경을 권장합니다", CTA "기기 {}개 네트워크 연결", 연결 없음 "네트워크 연결 없음", dBm "{} dBm", 완료 "네트워크 연결 완료" + "확인", 기기 상세 "연결된 네트워크"·"추가하기". 라이브 오프라인 버튼 "네트워크 변경"(Figma 1525:10689, 그대로).
- Figma 수치(1913:6570): 제목 600/18/줄 21.48/자간 −0.36 #3C3C3C(x24,y122) · 부제 500/14/줄 20/자간 −0.28 #626262(제목 아래 8) · 목록 369 폭 r12, 줄 64·면 #F4F4F4·선 #E3E3E3(목록 위 16) · 아이콘 원 36 #3C3C3C(그림 20, x16) · 왼쪽 글 x+12: 이름 600/16/줄 19.09/자간 −0.32 #3C3C3C, 둘째 줄 `hw_id` 500/14/줄 16.71/자간 −0.28 #949090(사이 4) · 오른쪽 오른쪽 정렬: Wi-Fi 이름 600/16/줄 19.09 #1E1E1E(한 줄 말줄임), dBm 500/14/줄 16.71 #949090 + 신호 그림 16 #B4AEAE(≥−60 alt, ≥−75 alt_2_bar, 그 외 alt_1_bar) · 연결 없음 600/14/줄 16.71 #949090 · 체크 24(오른쪽 16, 글과 사이 12) · CTA 369×56 r12 600/18/줄 28 #FAFAFA.
- Figma 수치(1913:7778): check_circle 64(가운데, y321.5) · 그 아래 24에 "네트워크 연결 완료" 600/18/줄 21.48 #3C3C3C 가운데 · CTA [확인] 하단 고정(기존 결과 CTA 위치).
- 글자 크기는 Figma 그대로(`AppTextScaler`). 하드코딩 문자열·색 금지. `CircularProgressIndicator` 금지.
- 네트워크 관리 모드는 **절대 등록(JWT·NAME·UNPAIR)하지 않는다** — `wifiOnly: true`만.
- 버전: 첫 `lib` 커밋(Task 1)에서 main 다음 minor(현재 main 0.185.1+540 → **0.186.0**), 이후 `lib` 커밋은 build만 +1. CHANGELOG 0.186.0은 유저에게 보이는 변화가 생기는 Task 6에서 만들고 Task 7에 덧붙인다. 병합 직전 main보다 한 칸 위로 재조정.
- 작업 공간: `tools/worktree.sh new feat/network-manage`.
- 건드리지 않는 것: 기기 **추가** 동작(종류별 1대·등록·자동 그룹·"새 기기로 등록"), `DeviceAddBleAdapter`, `KnownDeviceStore` 저장 형식, `DeviceWifiNameStore` 저장 형식, 초점 안내 막대, 신호 약함 모달의 표시 규칙, 서버·DB.

## Review Focus

1. **키 변경 회귀** — 기기 추가에서 같은 종류 둘째 기기를 누르면 첫째가 풀리고 둘째가 체크(종류별 1대 유지) → Task 1 `기기 추가는 같은 종류를 바꿔 고른다`.
2. **한 행 ↔ 여러 BLE** → Task 2 `한 행에 맞는 BLE가 둘이면 둘 다 null`.
3. **스캔이 행 로드보다 먼저** → Task 4 `행 로드 뒤 이미 잡힌 후보를 다시 맞춘다`.
4. **[새 기기로 등록] 누수** → Task 4 `네트워크 관리 모드의 registerAsNew는 아무것도 안 한다` + Task 5 버튼 없음.
5. **릴리스 provider 기본값** → Task 6 통합 테스트(`/devices/network`로 열면 네트워크 관리 모드, `dependencies` 누락 시 실패).

---

### Task 1: 리팩터 — 선택·결과 맵 키를 BLE 주소로 (동작 불변, + 0.186.0)

**Files:**
- Modify: `lib/features/my_cage/domain/device_add_flow.dart`, `lib/features/my_cage/presentation/device_add_flow_controller.dart`, `lib/features/my_cage/presentation/device_add_flow_screen.dart`, `pubspec.yaml`
- Test: `test/features/my_cage/device_add_flow_test.dart`, `test/features/my_cage/device_add_flow_screen_test.dart`(기계적 갱신)

**Context:**
- Depends on: 없음
- Produces:
  - `DeviceAddState.selected: Map<String, DeviceAddCandidate>`(키 `physicalId`), `DeviceAddState.results: Map<String, DeviceAddResult>`(키 `candidate.physicalId`).
  - `DeviceAddState.selectedOf(PairTargetKind kind) → DeviceAddCandidate?`, `resultOf(PairTargetKind kind) → DeviceAddResult?`(기기 추가 화면·자동 그룹용 — 그 종류 첫 값).
  - `registerAsNew(String physicalId)`(인자 변경).
- Must know:
  - 기기 추가 `select`: 같은 종류의 다른 후보가 골라져 있으면 빼고 넣는다(종류별 1대 유지). 같은 후보면 해제.
  - 자동 그룹(`DeviceAddAutoGroup(account, Map<PairTargetKind,String>)`)은 결과에서 종류별로 만들어 넘긴다 — 시그니처 그대로.
  - `_replacing`은 종류 키 그대로 둬도 된다(기기 추가 전용).
  - 동작 변경 없음 — 기존 테스트는 키 표현만 바꾸고 기대값은 그대로.
- Acceptance: `flutter test test/features/my_cage/` 통과, `flutter analyze` 0.

- [ ] **Step 1:** 테스트에 `기기 추가는 같은 종류를 바꿔 고른다`(카메라 A 선택 → 카메라 B 선택 → `selected.keys == {B.physicalId}`) 추가, 기존 테스트 키 표현 갱신 → 실행해 컴파일 실패 확인
- [ ] **Step 2:** 키 변경 구현 + `pubspec.yaml` 0.186.0+(main 다음 build)
- [ ] **Step 3:** `flutter test test/features/my_cage/` 통과, analyze 0
- [ ] **Step 4:** 단독 커밋 `refactor(device-add): 선택·결과를 BLE 주소로 구분 (0.186.0+N)`

---

### Task 2: 도메인 — 이 계정 기기 알아보기·표시 값

**Files:**
- Create: `lib/features/my_cage/domain/network_manage.dart`
- Test: `test/features/my_cage/network_manage_test.dart`

**Context:**
- Depends on: 없음
- Consumes: `DeviceAddCandidate`, `bleMatchesHardware`(`domain/device_add_flow.dart`), `PairTargetKind`, `kWeakRssi`(`domain/sys_health.dart`)
- Produces:
  - `class OwnedNetworkDevice { final PairTargetKind kind; final String id; final String name; final String? hardwareId; final bool? isOnline; final DateTime? lastSeen; final int? wifiRssi; final String? wifiSsid; }` (const, named)
  - `enum NetworkMatchVia { memory, hardware }`, `typedef NetworkMatch = ({OwnedNetworkDevice device, NetworkMatchVia via});`
  - `Map<String, NetworkMatch> matchOwnedDevices(List<DeviceAddCandidate> candidates, List<OwnedNetworkDevice> rows, Map<String, String> remembered)` — 키 `physicalId`, `remembered`는 `physicalId → 행 id`.
  - `bool networkOffline(OwnedNetworkDevice d)` = `isOnline == false`.
  - `String networkSignalIcon(int rssi)` — `≥ -60` `redesign_v2/signal_cellular_alt`, `≥ -75` `…_alt_2_bar`, 그 외 `…_alt_1_bar`(기기 추가 `device_add_flow_screen.dart:646-649`과 같은 경계 — 그 자리도 이 함수를 쓰게 바꾼다).
  - `int compareNetworkRows(NetworkMatch a, NetworkMatch b, Set<String> preferredIds)` — 미리 체크(행 id ∈ preferred) → 오프라인 → rssi 낮은 순(null은 뒤) → 이름.
- Must know: `matchOwnedDevices`는 같은 `kind`끼리만. ① `remembered[physicalId]`가 그 종류 행 id면 memory ② 아니면 `bleMatchesHardware` 참인 행이 정확히 하나면 hardware ③ 같은 행에 후보가 둘 이상이면 모두 뺀다(memory 후보가 정확히 하나면 그것만 남김).
- Acceptance: `flutter test test/features/my_cage/network_manage_test.dart` 통과.

- [ ] **Step 1: 실패하는 테스트**

```dart
// 기억이 hw보다 우선
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [camRow('c1', hw: 'AABBCCDDEE10'), camRow('c2')], {'AA:BB:CC:DD:EE:12': 'c2'})['AA:BB:CC:DD:EE:12']!.device.id, 'c2');
// Android 차이 0·2만
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [camRow('c1', hw: 'AABBCCDDEE10')], {})['AA:BB:CC:DD:EE:12']!.via, NetworkMatchVia.hardware);
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:13')], [camRow('c1', hw: 'AABBCCDDEE10')], {}), isEmpty);
// 한 BLE ↔ 두 행 → 없음 / 한 행 ↔ 두 BLE → 둘 다 없음
expect(matchOwnedDevices([camNamed('FB2_P4_CAM_EE12')], [camRow('c1', hw: '00111111EE10'), camRow('c2', hw: '00222222EE12')], {}), isEmpty);
expect(matchOwnedDevices([camNamed('FB2_P4_CAM_EE12'), camNamed('FB2_P4_CAM_EE10')], [camRow('c1', hw: '00111111EE10')], {}), isEmpty);
// 다른 종류 행은 보지 않는다
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [devRow('d1', hw: 'AABBCCDDEE10')], {}), isEmpty);
// 신호 그림 경계
expect(networkSignalIcon(-60), 'redesign_v2/signal_cellular_alt');
expect(networkSignalIcon(-75), 'redesign_v2/signal_cellular_alt_2_bar');
expect(networkSignalIcon(-76), 'redesign_v2/signal_cellular_alt_1_bar');
// 순서: 미리 체크 → 오프라인 → 약한 순 → 이름
expect(sorted([good('a', -50), weak('b', -80), offline('c'), pref('d', -40)]).map((m) => m.device.id), ['d', 'c', 'b', 'a']);
```

- [ ] **Step 2:** 실행 → 컴파일 실패 확인
- [ ] **Step 3:** 구현, `device_add_flow_screen.dart`의 신호 그림 분기를 `networkSignalIcon`으로
- [ ] **Step 4:** 통과, analyze 0
- [ ] **Step 5:** 커밋 `feat(network): 이 계정 기기 알아보기·표시 규칙 도메인`

---

### Task 3: 데이터 — 이 계정 기기 목록

**Files:**
- Modify: `lib/features/my_cage/data/device_add_registration_repository.dart`
- Test: `test/features/my_cage/device_add_registration_repository_test.dart`(없으면 Create — MockClient 패턴 `test/features/notification/notification_repository_test.dart`)

**Context:**
- Depends on: Task 2
- Produces: `Future<List<OwnedNetworkDevice>> networkDevices(String account)`
- Must know:
  - `devices`·`cameras` 각각 `.select()`(전체 열 — `wifi_ssid`가 생기면 앱 수정 없이 읽게; 없는 열을 이름으로 고르면 PostgREST 400), `.eq('owner_id', account)`. `unlinked_at`·`superseded_at`이 있는 행은 앱에서 거른다(`owned()`와 같은 규칙 — `superseded_at`은 cameras에만 있으니 서버 필터로 걸지 않는다).
  - rssi는 `SysHealth.fromDeviceRow`/`fromCameraRow`의 `rssi`. `wifiSsid`는 `row['wifi_ssid']`가 비지 않은 문자열일 때만.
  - 요청 전후 `_guard(account)`(같은 파일 패턴). `camerasProvider`에 넣지 않는다(CLAUDE.md — `clip_stats`는 heartbeat마다 바뀜). 화면 열 때·[다시 스캔] 때만 읽는다.
- Acceptance: MockClient 테스트가 `owner_id=eq.a` 요청, 해제·대체 행 제외, rssi 정수·누락 null, `wifi_ssid` 있음/없음, `is_online` 파싱을 확인하고 통과.

- [ ] Step 1 실패 테스트 → Step 2 실패 확인 → Step 3 구현 → Step 4 통과 → Step 5 커밋 `feat(network): 네트워크 관리용 이 계정 기기 목록 조회`

---

### Task 4: 컨트롤러 — 네트워크 관리 모드 (옛 단일 대상 모드는 그대로)

**Files:**
- Modify: `lib/features/my_cage/domain/device_add_flow.dart`(`NetworkManageRequest`, `DeviceAddState` 필드, `DeviceProvisionFailure.notOwned`)
- Modify: `lib/features/my_cage/presentation/device_add_flow_controller.dart`, `lib/features/my_cage/presentation/device_add_flow_route.dart`
- Test: `test/features/my_cage/device_add_flow_test.dart`(새 group `네트워크 관리 모드`)

**Context:**
- Depends on: Task 1, 2, 3
- Produces:
  - `class NetworkManageRequest { const NetworkManageRequest({this.preferredIds = const {}}); final Set<String> preferredIds; }` — 행 id(`devices.id`/`cameras.id`).
  - `final deviceAddNetworkManageProvider = Provider<NetworkManageRequest?>((ref) => null, dependencies: const []);` — **`deviceAddFlowProvider`의 `dependencies`에 추가 필수**, `DeviceAddFlowRoute`가 override.
  - 컨트롤러 named 인자: `NetworkManageRequest? networkManage`, `Future<List<OwnedNetworkDevice>> Function()? networkDevices`, `String? Function(DeviceAddCandidate)? rememberedId`(로컬 `KnownDeviceStore.load`). `target`과 `networkManage`는 동시에 주지 않는다(assert).
  - `DeviceAddState` 추가: `Map<String, NetworkMatch> owned`(physicalId → 매칭), `bool ownedLoadFailed`, `bool get networkManage`.
  - `bool get allConnected` — 네트워크 관리 결과가 하나 이상이고 모두 `reconnect == online && !unverified`(또는 서버 확인 불가 시 `wifiConnected`).
- Must know (이 모드에서만, 다른 모드 동작 불변):
  - 원본 스캔 목록 `_raw`. **스캔 갱신·행 로드 완료 때마다** `matchOwnedDevices(_raw, rows, {for c in _raw: c.physicalId: rememberedId(c)})`로 다시 맞춘다. `candidates` = 매칭된 것 중 `supportsWifiChange(kind)`인 것.
  - `scan()`이 매번 `networkDevices()`를 다시 읽는다. 실패 → `ownedLoadFailed: true`, 성공 → false.
  - `select`: 같은 종류 제한 없음(여러 대). 매칭 없는 후보는 무시.
  - 미리 체크: `step == scan`이고 아직 하지 않았으면, `preferredIds`에 든 행에 매칭된 후보를 모두 고른다. 한 번 고른 뒤엔 다시 하지 않는다(유저가 풀면 그대로).
  - 연결: 고른 기기 전부, 카메라 먼저(같은 종류는 고른 순서). 보내기 직전 `owned(kind, id)` 재확인 — null이면 그 기기 결과 `failed` + `failure: notOwned`, **다음 기기 계속**.
  - `_existingId(c)` = `state.owned[c.physicalId]?.device.id`.
  - `trusted` = `via == memory || !wasOnline`.
  - `registerAsNew`·`groupConfirmed`·자동 그룹·새 이름: 이 모드에선 부르지 않는다/즉시 return.
  - `continueAdding`([다시 찾기]): 결과가 실패·미확인인 기기의 행 id를 다시 미리 체크하고 scan으로.
  - 로그: `debugPrint('[device-add] network-match name=… kind=… row=…${tail} via=memory|hardware|none')`.
  - 비동기 뒤 `_active` 확인 후에만 `state=`.
- Acceptance: `flutter test test/features/my_cage/device_add_flow_test.dart` 통과(기존 + 새 group).

- [ ] **Step 1: 실패하는 테스트** (새 group `네트워크 관리 모드`)
  - `알아본 이 계정 기기만 보인다` — 후보 3(hw 일치 사육장, 불일치 사육장, 기억 일치 카메라) → candidates 2, owned via 확인.
  - `같은 종류 여러 대를 고른다` — 사육장 2대 select → `selected.length == 2`.
  - `행 로드 뒤 이미 잡힌 후보를 다시 맞춘다` — 스캔 먼저, `networkDevices` Completer 나중.
  - `미리 체크는 scan 단계에서 한 번만` — 자동 선택 뒤 해제 → 다음 스캔에도 비어 있음 / `loadNetworks()` 뒤 늦은 매칭은 고르지 않음.
  - `Wi-Fi만 보낸다, 카메라 먼저` — gateway 호출 순서 카메라→사육장→사육장, 모두 `wifiOnly: true`·`jwt: ''`, `outcome == wifiUpdated`, `registeredId == 행 id`.
  - `보내기 직전 행이 사라지면 그 기기만 실패하고 다음 기기는 보낸다` — `failure == notOwned`, 다음 기기 gateway 호출 1.
  - `hardware로만 알아본 온라인 기기는 unverified` / `memory면 online`.
  - `allConnected` — 둘 다 online → true, 하나 missing → false.
  - `registerAsNew는 아무것도 안 한다`, `자동 그룹을 부르지 않는다`.
  - `목록 조회 실패는 유지 플래그, 다시 스캔하면 재조회`.
  - `[다시 찾기]는 실패 기기만 다시 체크`.
  - `dispose 뒤 응답 무시`.
- [ ] Step 2 실패 확인 → Step 3 구현 → Step 4 `flutter test test/features/my_cage/` 통과 → Step 5 커밋 `feat(network): 기기 추가 흐름에 네트워크 관리 모드(여러 대)`

---

### Task 5: 화면 — 목록·완료·기기별 결과

**Files:**
- Modify: `lib/features/my_cage/presentation/device_add_flow_screen.dart`, `device_add_flow_route.dart`(`networkManage` 인자), `assets/l10n/ko.json`
- Test: `test/features/my_cage/device_add_flow_screen_test.dart`, `test/design/text_scale_overflow_test.dart`

**Context:**
- Depends on: Task 4
- Produces: `DeviceAddFlowRoute({…, NetworkManageRequest? networkManage})`, `DeviceAddFlowScreen({…, NetworkManageRequest? networkManage})`(`wifiTarget`은 Task 7까지 남김). Key: 줄 `network_manage_row_<physicalId>`, Wi-Fi 이름 `network_manage_ssid_<physicalId>`, dBm `network_manage_dbm_<physicalId>`, 완료 `network_manage_done`, 결과 줄 `network_manage_result_<physicalId>`.
- Must know:
  - ko.json: `network_manage_title` "네트워크 관리", `network_manage_select_title` "네트워크에 연결할 기기 선택", `network_manage_select_subtitle` "사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요\ndBm이 낮은 기기는 네트워크 변경을 권장합니다", `network_manage_selected` "기기 {}개 네트워크 연결", `network_manage_dbm` "{} dBm", `network_manage_no_connection` "네트워크 연결 없음", `network_manage_done` "네트워크 연결 완료", `network_manage_load_failed` "기기 정보를 불러오지 못했어요. 다시 스캔해 주세요"(Figma 밖), `network_manage_not_owned`(= `device_wifi_target_gone` 재사용 가능하면 새 키 없이).
  - 상단 제목: 이 모드의 모든 단계 "네트워크 관리".
  - 목록 줄(Global Constraints 수치): 왼쪽 아이콘 + `Column(이름, hw_id ?? 줄 없음)`. 오른쪽: 오프라인이면 "네트워크 연결 없음" 한 줄. 아니면 `wifiSsid ?? 기억한 이름(deviceWifiNameProvider)`가 있으면 이름 줄, `wifiRssi`가 있으면 dBm 줄 + `networkSignalIcon`. 둘 다 없으면 오른쪽 비움. 순서 `compareNetworkRows`.
  - `ownedLoadFailed`면 빈 상태보다 먼저 안내.
  - CTA: 미선택 [다시 스캔], 선택 "기기 N개 네트워크 연결". `device_add_selection_hint`는 이 모드에서 숨김.
  - 결과: `state.allConnected`면 완료 화면(1913:7778 수치) + [확인](pop, 기존 `common_confirm`). 아니면 기기별 결과 목록 — 줄마다 이름 + 기존 `_wifiUpdated` 문구, notOwned는 `device_wifi_target_gone`, **[새 기기로 등록] 없음**, [다시 찾기](`device_wifi_retry`) + 닫기.
- Acceptance:
  - `네트워크 관리 목록: Figma 수치` — 카메라(online, −78, ssid 'iptime') → 이름 600/16 #3C3C3C, hw 500/14 #949090, ssid 600/16 #1E1E1E, "-78 dBm" 500/14 #949090 + alt_1_bar, 본문 제목 600/18, 상단 "네트워크 관리".
  - `이름 모르면 dBm만`, `오프라인은 네트워크 연결 없음 한 줄`, `rssi·이름 둘 다 없으면 오른쪽 비움`.
  - `CTA는 실제 체크 수` — 3대 → "기기 3개 네트워크 연결".
  - `모두 붙으면 완료 화면` — check_circle 64·"네트워크 연결 완료"·[확인] 누르면 pop.
  - `하나라도 안 붙으면 기기별 결과` — 두 줄, `새 기기로 등록` findsNothing, [다시 찾기] 있음.
  - `기기 추가 모드는 그대로` — 기존 테스트 통과.
  - text_scale 1.0/1.3/2.0에 목록·완료·결과 추가, 통과.
- [ ] Step 1 실패 테스트 → Step 2 확인 → Step 3 구현 → Step 4 통과 → Step 5 커밋 `feat(network): 네트워크 관리 목록·완료·결과 화면(Figma 1913:6570·7778)`

---

### Task 6: 진입점 4곳 + 라우트

**Files:**
- Modify: `lib/core/router/app_router.dart`(`/devices/network` 추가, `/devices/wifi`는 아직 둔다), `lib/shared/widgets/redesign_tab_header.dart`, `lib/features/my_cage/presentation/widgets/weak_signal_notice_prompt.dart`, `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart`, `lib/features/my_cage/presentation/device_detail_screen.dart`, `assets/l10n/ko.json`, `CHANGELOG.md`, `pubspec.yaml`(build +1)
- Test: `test/features/my_cage/weak_signal_notice_prompt_test.dart`, `test/features/my_cage/webrtc_live_view_test.dart`, `test/features/my_cage/device_management_screen_test.dart`, `test/features/home/home_header_bar_test.dart`, `test/features/my_cage/crecam_home_test.dart`, 새 `test/features/my_cage/network_manage_route_test.dart`

**Context:**
- Depends on: Task 5
- Produces: `GoRoute(path: '/devices/network', builder: (_, s) => DeviceAddFlowRoute(networkManage: NetworkManageRequest(preferredIds: {if (s.extra case final String id) id})))`
- Must know:
  - 메뉴: 4번째 `('/devices/network', 'network_manage_title')`(세 탭 공용 헤더). 구분선 조건 `i == 2` → `i < items.length - 1`.
  - 신호 약함 모달 [변경]: `context.push('/devices/network', extra: cameraId)`(`WifiChangeTarget` 대신). `cameraName` 인자는 쓰지 않게 되면 지운다.
  - 라이브 오프라인 [네트워크 변경](Key `webrtc_live_wifi_change` 유지) → `/devices/network` + extra 카메라 id.
  - 기기 상세 줄(Key `device_wifi_change` 유지): 라벨 `network_manage_connected`("연결된 네트워크"), 값 = 서버 `wifi_ssid` → 기억한 이름 → 오프라인(`is_online == false`)이면 `network_manage_add`("추가하기") → 그 외 `--`. 누르면 `/devices/network` + extra 행 id. 삭제 확인 문구 `management_delete_confirm_wifi`를 "[네트워크 관리]"로(`device_detail_screen.dart:360-363`, 테스트 `device_management_screen_test.dart`).
  - CHANGELOG 0.186.0: 추가(네트워크 관리·여러 대·완료 화면, 메뉴), 변경(신호 약함 [변경]·기기 상세 줄·라이브 오프라인 이동).
- Acceptance:
  - 모달: [변경] → `/devices/network`, extra 카메라 id.
  - 메뉴(두 파일): 4항목 `기기 추가/기기 관리/개체 추가 · 관리/네트워크 관리`, 마지막만 구분선 없음, 누르면 `/devices/network`(extra 없음).
  - 기기 상세: 라벨 "연결된 네트워크", 오프라인 행 값 "추가하기", 누르면 `/devices/network` + 그 행 id.
  - 라이브 오프라인: [네트워크 변경] → `/devices/network` + 카메라 id.
  - 통합: 실제 `app_router`로 `/devices/network` → 상단 "네트워크 관리"·본문 "네트워크에 연결할 기기 선택" — provider `dependencies` 누락 시 실패해야 한다.
- [ ] Step 1 실패 테스트 → Step 2 확인 → Step 3 구현 → Step 4 `flutter test test/features/` 통과·analyze 0 → Step 5 커밋 `feat(network): 메뉴·신호 약함·기기 상세·라이브에서 네트워크 관리로 (0.186.0+N)`

---

### Task 7: 옛 단일 대상 모드 삭제 (단독 커밋)

**Files:**
- Modify: `lib/core/router/app_router.dart`(`/devices/wifi` 삭제), `device_add_flow.dart`(`WifiChangeTarget` 삭제), `device_add_flow_controller.dart`(`_target`·`_loadTarget`·`_match`·`matched`·`targetGone`·`deviceAddWifiTargetProvider`), `device_add_flow_route.dart`, `device_add_flow_screen.dart`(`wifiTarget` 분기·`device_wifi_confirm_other` 창), `assets/l10n/ko.json`(`grep`으로 미사용 확인한 `device_wifi_*`만), 관련 테스트, `CHANGELOG.md`·`pubspec.yaml`(build +1)
- Test: 기존 테스트에서 `WifiChangeTarget` 참조 정리

**Context:**
- Depends on: Task 6
- Must know: 결과 문구 키(`device_wifi_target_gone`·`device_wifi_target_missing`·`device_wifi_retry`·`device_wifi_unverified*`)는 Task 5가 쓰면 남긴다(grep). CHANGELOG 0.186.0에 "제거: 기기별 Wi-Fi 바꾸기 화면(네트워크 관리로 통합)".
- Acceptance: `grep -rn "devices/wifi\|WifiChangeTarget\|deviceAddWifiTargetProvider" lib test` 없음, 전체 `flutter test` 통과, analyze 0.
- [ ] Step 1 삭제·테스트 정리 → Step 2 통과 → Step 3 커밋 `refactor(network): 기기별 Wi-Fi 바꾸기(단일 대상 모드) 삭제`

---

### Task 8: 화면 검수·문서·실기기

**Files:**
- Create: `docs/design-audits/2026-11-19-network-manage/RESULTS.md` + `captures/`
- Modify: `CLAUDE.md`(Wi-Fi 바꾸기·라이브 오프라인 단락), `docs/ble-provisioning-protocol.md`(Wi-Fi 바꾸기 줄), `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`([변경] 목적지 확정), 메모리 `project_network_change_plan_figma_drift`(해소)

**Context:**
- Depends on: Task 7
- Must know: 시뮬레이터엔 BLE가 없다 — 목록·완료·결과는 커밋하지 않는 디버그 주입으로 캡처하고 되돌린다(2026-11-19 모달 검수 방식). 비교는 Figma 3배 PNG ↔ 앱 1125 폭.
- Acceptance: RESULTS.md에 메뉴·목록 줄·CTA·완료 화면·기기 상세 줄 Figma 대조표, 차이는 보고 후 확정.
- [ ] Step 1: 캡처·대조 → RESULTS.md, 문서 → 커밋 `docs(network): 네트워크 관리 화면 검수·문서`
- [ ] Step 2: main 병합(`tools/worktree.sh finish`)
- [ ] Step 3 (**사용자, 스토어 배포 전 필수**): 실기기에서 ① 켜진 지 10분 넘은 사육장이 목록에 나오는가 ② 카메라는 전원 재연결 뒤 나오는가 ③ `[device-add] network-match` 로그가 맞는 기기에 붙는가(Android·iOS) ④ 사육장·카메라 Wi-Fi 바꾼 뒤 운영 DB 같은 `id`의 `last_seen_at`이 갱신되고 새 행이 안 생기는가 ⑤ 두 대 이상 한 번에 바꾸기. 나쁘면 `kWifiChangeDeviceEnabled=false` 또는 범위 재논의.
