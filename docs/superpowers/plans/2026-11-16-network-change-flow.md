# 네트워크 변경 흐름 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙 — Implementer 에이전트(`flutter-dev`) 분리(GATE 4), task 단위로 구현한다. 실행은 `executing-plans` 스킬. Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: 📝 **r2 — `/검수` 반영, 사용자 결정·승인 대기** (2026-11-16). 검수 결과 `docs/design-audits/2026-11-16-network-change/plan-review-final.md`.

**Goal:** 근처 기기를 검색해 이 계정의 사육장·카메라를 골라 Wi-Fi만 바꾸는 "네트워크 변경" 흐름을 만들고, 신호 약함 막대·헤더 관리 메뉴·라이브 오프라인 안내에서 들어오게 하며, 기기 상세의 기기별 [Wi-Fi 바꾸기]를 없앤다.

**Architecture:** 기존 기기 추가 흐름(`DeviceAddFlowController`/`DeviceAddFlowScreen`)에 **네트워크 변경 모드**를 추가한다. 스캔된 BLE 기기마다 이 계정 기기 행을 이 폰의 기억·`hw_id`로 알아보고(`matchOwnedDevices`), 알아본 기기만 등록 이름·연결 상태와 함께 보인다. 고른 기기에는 지금 Wi-Fi 바꾸기와 같은 `SSID/PASS/CONNECT`만 보내고 그 행 `last_seen_at`으로 판정한다(새 등록 없음 → 같은 행 유지). 새 모드가 완성된 뒤 마지막 task에서 옛 단일 대상 모드(`WifiChangeTarget`, `/devices/wifi`)를 지운다.

**Tech Stack:** Flutter, Riverpod(StateNotifier), GoRouter, flutter_blue_plus(기존 `DeviceAddBleAdapter`), Supabase 직결 SELECT, easy_localization.

**Spec:** Figma `네트워크 신호 약함` 섹션 `1877:14741`(talk-to-figma로 2026-11-16 조회) + 아래 "기획 해석"(대화 합의 2026-11-16). 관련: `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`, `docs/ble-provisioning-protocol.md`, 기기 추가 Figma 971:1837/990:11220.

### 기획 해석 (Figma 노드 → 결정)

| Figma | 결정 |
|---|---|
| `1913:7121` "진입 1 - 스낵바 터치" + 화살표(막대 `1913:7028` → `1913:6462`) | 신호 약함 막대 전체를 누르면 네트워크 변경 흐름 |
| `1913:7125` "진입 2 - 설정>네트워크 변경" + 화살표(`1913:7111` → `1913:6462`) | 헤더 관리 메뉴 4번째 "네트워크 변경" |
| `1912:5676` "이쪽 플로우는 지울까?" + `1913:7116` 메모("자동 검색 → 신호 세기 리스트 → 교체할 기기 선택 → 와이파이 선택… 이 방법이 나을 것 같아요") | 기기 상세 [Wi-Fi 바꾸기] 줄·기기별 흐름 제거 |
| `1913:7129` "연결된 와이파이 이름을 보여줘야하는데.." + 목록 안 `1913:7130`(이름 아래 "네트워크 연결 양호") | 목록 줄 왼쪽 이름 아래 연결 상태 한 줄 |
| `1913:6462`/`6570`/`6618`/`6683`/`6743`/`6772` | 상단 제목 "네트워크 변경", 나머지는 기기 추가 화면 틀 |

## 가정

- 확인:
  - 기기 추가 흐름: 종류별 1대 선택(`DeviceAddState.selected: Map<PairTargetKind, …>`) → Wi-Fi 하나로 차례 연결(카메라 먼저, `device_add_flow_controller.dart:430-440`).
  - Wi-Fi만 바꾸기(`_updateWifi`, `wifiOnly: true`) + 서버 판정(`_watchReconnect`, 5초·90초) + 온라인 대상 경계(`wasOnline`, `trusted`, `DeviceAddResult.unverified`)가 있다(`:638-770`).
  - **카메라는 켜진 뒤 3분만 BLE 광고한다**(`docs/ble-provisioning-protocol.md:16`, 관훈님 회신). 켜져 있는 카메라는 전원을 다시 넣어야 목록에 나온다.
  - 운영 DB(2026-11-16): 해제 안 된 `devices` 38행 모두 `hw_id`(12자), 37행 `sys_state.rssi`. `cameras`(해제·대체 안 된) 25행 중 23행 `hw_id`·`clip_stats.sys.rssi`. `devices`·`cameras`에 SSID 컬럼 없음.
  - 결과 화면 `_wifiUpdated()`는 `state.results.values.first` 한 대만 그린다(`device_add_flow_screen.dart:1052`), [새 기기로 등록]은 `missing`이면 조건 없이 뜬다(`:1143`).
  - 헤더 관리 메뉴(`redesign_tab_header.dart:174-178`)는 홈·카메라·마이크레 탭 공용, 테스트는 `test/features/home/home_header_bar_test.dart:132-135`·`test/features/my_cage/crecam_home_test.dart:335`.
  - 기기 삭제 확인 문구 `management_delete_confirm_wifi`(`ko.json:300`)가 [Wi-Fi 바꾸기]를 가리킨다(`device_detail_screen.dart:360-363`).
  - 중첩 scope provider는 `dependencies`에 없으면 릴리스에서 root 기본값을 읽는다(2026-09-22 사고).
- 미확인 (→ Task 0 실기기, 사용자만 가능):
  - 켜진 지 오래된 **사육장**이 BLE 광고를 계속하는지.
  - 사육장이 `SSID/PASS/CONNECT`만으로 **같은 `device_id`**로 다시 붙는지(`kWifiChangeDeviceEnabled`).
  - `bleMatchesHardware`(차이 0·2)가 실제로 맞는지, iOS에서 사육장 광고 이름에 `_XXXX` 끝자리가 붙는지(없으면 iOS는 이 폰의 기억 없이는 사육장을 못 알아본다).

## 선택지와 추천

| 결정 | 선택지 | 추천 |
|---|---|---|
| 구현 방식 | A. 기존 흐름에 모드 추가 후 옛 모드 삭제 / B. 새 화면·컨트롤러 | **A** — BLE·네트워크·비밀번호·Wi-Fi만 바꾸기 판정이 이미 검증돼 있다 |
| 커밋 순서 | A. 새 모드 추가 → 진입점 전환 → 옛 모드 삭제(단독 커밋) / B. 한 번에 교체 | **A** — 매 커밋이 컴파일·테스트 통과, 삭제만 되돌리기 쉽다 |
| 목록에 보일 기기 | A. 알아본 것만 / B. 전부, 모르는 건 비활성 | **A** — 모르는 기기는 판정할 행이 없다. B는 Figma에 없는 문구가 필요 |
| 알아보기 근거 | 이 폰의 기억(로컬) 우선, 없으면 `hw_id`. 한 BLE ↔ 여러 행, 한 행 ↔ 여러 BLE면 모두 숨김 | 오인 방지가 빈 줄보다 중요 |
| 판정 신뢰 | 기억으로 알아봤거나 원래 오프라인 → "연결됐어요" / `hw_id`로만 알아본 온라인 기기 → 기존 "연결돼 있어요(확인 못 함)" | 옛 Wi-Fi 하트비트를 성공으로 단정하지 않는다 |
| 결과 화면 | 네트워크 변경은 기기별 결과 목록(한 대여도) | 두 대 결과를 다 보인다. 줄 문구는 기존 `_wifiUpdated` 문구 재사용 |
| [새 기기로 등록] | 네트워크 변경 모드에선 숨김 + 컨트롤러 거부 | 이 흐름은 등록하지 않는다 — 안 붙으면 [다시 찾기] |

## 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 켜져 있는 카메라(3분 지남) | 목록에 없음 | 안내 문구(사용자 결정 1) + [다시 스캔]. Task 0에서 사육장 광고도 확인 |
| 근처에 이 계정 기기 없음 | 빈 목록 | 기존 빈 상태 문구 + [다시 스캔] |
| `hw_id` 매칭이 실제로 틀림 / iOS 사육장 끝자리 없음 | 못 알아봄 → 빈 목록 | 이 폰의 기억으로는 계속 알아본다. Task 0 결과가 나쁘면 범위 재논의(사용자) |
| 한 행에 맞는 BLE 후보가 둘(근처 다른 계정 기기) | 둘 다 숨김 | 엉뚱한 기기에 Wi-Fi를 보내거나 짝을 잘못 기억하지 않는다 |
| 검색 뒤 연결 전 행이 해제·대체됨 | 보내기 직전 재확인에서 실패 | 결과 "이 계정 기기가 아니에요"(기존 `device_wifi_target_gone`), 등록으로 넘어가지 않음 |
| 사육장이 같은 행에 안 붙음 | 90초 뒤 "신호가 오지 않아요" | Task 0에서 확인되면 `kWifiChangeDeviceEnabled=false` → 사육장 목록 제외 |
| 옛 Wi-Fi로 온라인인 채 진행 | 옛 하트비트가 새 접속처럼 보일 수 있음 | 판정 신뢰 규칙(위) |
| 비밀번호 틀림 / 블루투스 꺼짐 | 즉시 실패 / 검색 실패 | 기존 동작 |
| 기기 목록 조회 실패 | 아무것도 못 알아봄 | 유지 플래그 `ownedLoadFailed` → 안내 + [다시 스캔] 재조회 |
| 늦게 끝난 매칭(네트워크 단계로 넘어간 뒤) | — | 자동 선택은 `step == scan`일 때만 |

## 유저 체험 시뮬레이션

1. 홈 라이브 위 "네트워크 신호가 약하니 점검해 주세요" 막대(어디든)를 누른다 → "네트워크 변경" 화면이 열리고 근처 기기 검색이 시작된다. 제목 "네트워크 변경할 기기 선택" 옆에 검색 중 표시, 아래 [다시 스캔]은 회색.
2. 카메라는 켜진 지 3분이 지나 목록에 없다. 부제·빈 상태 안내(사용자 결정 1)를 보고 카메라 전원을 뺐다 꽂으면 몇 초 뒤 "카메라 4" 줄이 나타나며 이미 체크돼 있다(막대로 들어온 그 카메라). 줄 왼쪽은 아이콘·"카메라 4"·그 아래 회색 연결 상태, 오른쪽은 광고 이름과 블루투스 세기(-68 dBm), 체크박스.
3. 사육장도 체크하면 버튼이 "기기 2개 네트워크 변경"(사용자 결정 2)으로 바뀐다 → 네트워크 선택(상단 "네트워크 변경") → 비밀번호.
4. 연결을 누르면 카메라부터 차례로 새 Wi-Fi를 받는다. 결과 화면에 기기마다 "연결됐어요"/"신호가 오지 않아요"/"연결돼 있어요(확인 못 함)"가 한 줄씩 나온다. 이름·그룹·예약·기록은 그대로다. 안 붙은 기기는 [다시 찾기]로 다시 검색한다(새 기기로 등록하지 않는다).
5. 헤더 관리 버튼 메뉴 맨 아래 "네트워크 변경"을 누르면 아무것도 체크되지 않은 같은 화면이 열린다.
6. 기기 상세에는 [Wi-Fi 바꾸기] 줄이 없다. 기기를 지울 때 확인 문구는 "Wi-Fi를 바꾸려면 [네트워크 변경]을 쓰세요" 쪽으로 바뀐다. 라이브 오프라인 안내의 [네트워크 변경]은 그 카메라가 미리 체크된 같은 화면으로 간다.

## 근본 원인·전후 동작

- 전: 막대 → 그 카메라 기기 상세. Wi-Fi 변경은 기기 상세·라이브 오프라인에서 기기 한 대씩, 같은 종류 BLE 목록에서 대상을 짐작해 고르고(못 알아보면 확인 모달), 결과는 한 대.
- 후: 막대·관리 메뉴·라이브 오프라인 → 네트워크 변경 화면. 알아본 이 계정 기기만 이름·연결 상태와 함께 뜨고 종류별 1대씩 함께 바꾸며 결과는 기기별. 기기 상세 [Wi-Fi 바꾸기]·`/devices/wifi` 없음.

## 검증 방법

1. 매 task: `flutter analyze` 오류·경고 0, 해당 테스트 통과. 마지막에 전체 `flutter test`.
2. 시뮬레이터(iPhone 13 mini): 메뉴 4항목·막대 진입·라이브 오프라인 진입·기기 상세 줄 제거·목록(디버그 주입)·결과 화면 캡처 → `docs/design-audits/2026-11-16-network-change/RESULTS.md` Figma 수치 대조.
3. **실기기(사용자만):** Task 0(구현 전)·Task 6(구현 후) 항목. 판정은 `[device-add] wifi-target`/`network-match` 로그와 운영 DB 같은 `id`의 `last_seen_at` 갱신, 기기 관리에 행이 늘지 않는지.

## 사용자가 정할 것

1. **켜져 있는 카메라 안내** — 카메라는 켜진 뒤 3분만 검색된다. Figma 부제는 "사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요"뿐. 추천: 기획자에게 부제·빈 상태 문구를 받는다(예: "카메라는 전원을 다시 연결한 뒤 3분 동안만 찾을 수 있어요"). 안내를 넣지 않으면 막대 진입이 사실상 빈 목록이 된다.
2. **기기 선택 버튼 문구** — Figma 1913:6573 "기기 2개 추가". 추천 "기기 {}개 네트워크 변경".
3. **연결 상태 문구** — Figma엔 "네트워크 연결 양호"뿐. 추천: 양호 "네트워크 연결 양호" / 약함(현재 rssi ≤ −75) "네트워크 신호 약함" / 오프라인 "오프라인" / 값 없음 → 줄 숨김. 주의: 막대는 −75 이하가 10분 이어질 때 뜨고 이 줄은 현재 값이라, 막대를 보고 들어와도 "양호"로 보일 수 있다.
4. **결과 화면** — Figma에 없다. 추천: 기기 추가 결과 목록 틀(기기별 한 줄)에 상단 제목 "네트워크 변경".
5. **같은 종류 여러 대** — 추천: 이번엔 종류별 1대(사육장 1·카메라 1). 더 필요하면 흐름을 다시 돈다.
6. **메뉴 노출 탭** — 헤더가 홈·카메라·마이크레 공용이라 세 탭 모두에 "네트워크 변경"이 생긴다. 추천: 세 탭 모두(Figma 진입 2는 홈 그림뿐).
7. **Wi-Fi 이름** — 서버에 없다. 추천: 이번엔 표시하지 않는다.
8. **Task 0 결과가 나쁠 때** — 사육장이 같은 행에 안 붙으면 사육장 제외, 매칭이 안 맞으면 범위 재논의. 추천: Task 0 결과를 보고 구현 착수 여부를 정한다.

## Global Constraints

- 문구(Figma 그대로): 상단 제목·메뉴 "네트워크 변경"(기존 키 `device_wifi_title` 재사용), 본문 제목 "네트워크 변경할 기기 선택", 상태 "네트워크 연결 양호". 그 외 새 문구는 사용자 결정 1~4 확정값.
- Figma 수치(1913:6462): 목록 줄 369×64·면 #F4F4F4·줄 사이 선 #E3E3E3·묶음 r12 / 아이콘 원 36 #3C3C3C(그림 20) / 왼쪽 이름 600·16·줄 19.09·자간 −0.32 #3C3C3C / 오른쪽 광고 이름 600·16 #1E1E1E / dBm 500·14·줄 16.71·자간 −0.28 #949090 + 신호 그림 16 #B4AEAE / 체크 24 / 본문 제목 600·18·줄 21.48·자간 −0.36 #3C3C3C / 부제 500·14 #626262 / CTA 369×56 r12(비활성 #E3E3E3, 글자 600·18·줄 28 #FAFAFA). 상태 줄(1913:7141) 500·14·줄 16.71·자간 −0.28 #949090, 이름 바로 아래.
- 글자 크기는 Figma 그대로(`AppTextScaler`). 하드코딩 문자열·색 금지. `CircularProgressIndicator` 금지.
- 네트워크 변경 모드는 **절대 등록(JWT·NAME·UNPAIR)하지 않는다** — `wifiOnly: true`만.
- 버전: 첫 `lib` 커밋(Task 1)에서 **0.179.0** minor bump, 이후 `lib` 커밋은 build 번호만 +1. CHANGELOG 0.179.0 항목은 유저에게 보이는 변화가 생기는 Task 5 커밋에서 만들고 Task 6에서 덧붙인다. 병합 직전 main보다 한 칸 위로 재조정(CLAUDE.md 병렬 세션 규칙).
- 작업 공간: `tools/worktree.sh new feat/network-change`.
- 건드리지 않는 것: 기기 **추가** 흐름 동작(등록·자동 그룹·"새 기기로 등록"), `DeviceAddBleAdapter`, `KnownDeviceStore` 저장 형식, `DeviceWifiNameStore`(저장 유지·표시 안 함), 초점 안내 막대 이동, 서버·DB.

## Review Focus

1. **한 행 ↔ 여러 BLE**(근처 다른 계정 기기) → Task 1 `한 행에 맞는 BLE가 둘이면 둘 다 null`.
2. **스캔이 행 로드보다 먼저 옴** → Task 3 `행 로드 뒤 이미 잡힌 후보를 다시 맞춘다`.
3. **네트워크 단계에서 늦은 자동 선택** → Task 3 `scan 단계가 아니면 preferred로 고르지 않는다`.
4. **[새 기기로 등록] 누수** → Task 3 `네트워크 변경 모드의 registerAsNew는 아무것도 안 한다` + Task 4 버튼 없음.
5. **릴리스 provider 기본값** → Task 5 라우트를 통과하는 통합 테스트(`/devices/network`로 열면 네트워크 변경 모드).

---

### Task 0: 실기기 사전 확인 (사용자 — 구현 전)

**Files:** 기록만 — `docs/design-audits/2026-11-16-network-change/RESULTS.md` §0

**Context:**
- Depends on: 없음. 지금 main(0.178.0+515)의 기존 `/devices/wifi` 흐름(기기 상세 [Wi-Fi 바꾸기])과 `[device-add] wifi-target` 로그를 쓴다.
- Must know: 시뮬레이터엔 BLE가 없다. 사용자 폰 + 디버그 빌드(`flutter run`, 로그 수집) 필요.
- Acceptance(각 항목 예/아니오 기록):
  1. 켜진 지 10분 넘은 **사육장**이 기기 상세 [Wi-Fi 바꾸기] 목록에 나오는가.
  2. 켜진 지 10분 넘은 **카메라**는 안 나오고, 전원 재연결 후엔 나오는가.
  3. 로그 `match=true`가 그 기기에 붙는가(Android·iOS 각각). iOS 사육장 광고 이름 끝에 `_XXXX`가 있는가.
  4. 사육장 Wi-Fi 바꾸기 뒤 운영 DB에서 **같은 `devices.id`**의 `last_seen_at`이 갱신되고 새 행이 생기지 않는가.
- 결과가 나쁘면 사용자 결정 8에 따라 범위를 다시 정한 뒤 Task 1로.

---

### Task 1: 도메인 — 등록 기기 알아보기·연결 상태 (+ 버전 0.179.0)

**Files:**
- Create: `lib/features/my_cage/domain/network_change.dart`
- Modify: `pubspec.yaml`(0.179.0). CHANGELOG는 이 커밋에 쓰지 않는다 — Task 1~4는 유저가 볼 변화가 없고(진입점이 Task 5에 생긴다), 0.179.0 항목은 유저에게 보이는 변화가 생기는 Task 5 커밋에 쓴다.
- Test: `test/features/my_cage/network_change_test.dart`

**Context:**
- Depends on: Task 0(진행 결정)
- Consumes: `DeviceAddCandidate`, `bleMatchesHardware`(`domain/device_add_flow.dart`), `PairTargetKind`, `kWeakRssi`(`domain/sys_health.dart`)
- Produces:
  - `class OwnedNetworkDevice { final PairTargetKind kind; final String id; final String name; final String? hardwareId; final bool? isOnline; final DateTime? lastSeen; final int? wifiRssi; }` (const, named)
  - `enum NetworkHealth { good, weak, offline, unknown }`, `NetworkHealth networkHealthOf(OwnedNetworkDevice d)`
  - `enum NetworkMatchVia { memory, hardware }`
  - `typedef NetworkMatch = ({OwnedNetworkDevice device, NetworkMatchVia via});`
  - `Map<String, NetworkMatch> matchOwnedDevices(List<DeviceAddCandidate> candidates, List<OwnedNetworkDevice> rows, Map<String, String> remembered)` — 반환 키는 `physicalId`, `remembered`는 `physicalId → 행 id`(이 폰의 기억).
- Must know:
  - `networkHealthOf`: `isOnline == false` → offline / `wifiRssi == null` → unknown / `wifiRssi <= kWeakRssi` → weak / 그 외 good.
  - `matchOwnedDevices`: 같은 `kind`끼리만. ① `remembered[physicalId]`가 그 종류 행 id면 memory. ② 아니면 `bleMatchesHardware`가 참인 행이 정확히 하나면 hardware. ③ 그 뒤 **같은 행에 둘 이상의 후보가 붙으면 그 후보들을 모두 뺀다**(memory로 붙은 후보가 정확히 하나면 그것만 남긴다).
- Acceptance: `flutter test test/features/my_cage/network_change_test.dart` 통과.

- [ ] **Step 1: 실패하는 테스트** (헬퍼 `cam`/`camNamed`/`camRow`/`devRow`/`dev`는 파일 안)

```dart
expect(networkHealthOf(dev(isOnline: false, rssi: -40)), NetworkHealth.offline);
expect(networkHealthOf(dev(isOnline: true, rssi: null)), NetworkHealth.unknown);
expect(networkHealthOf(dev(isOnline: true, rssi: -75)), NetworkHealth.weak);
expect(networkHealthOf(dev(isOnline: true, rssi: -74)), NetworkHealth.good);

// 기억이 hw보다 우선
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [camRow('c1', hw: 'AABBCCDDEE10'), camRow('c2')], {'AA:BB:CC:DD:EE:12': 'c2'})['AA:BB:CC:DD:EE:12']!.device.id, 'c2');
// Android 차이 0·2만
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [camRow('c1', hw: 'AABBCCDDEE10')], {})['AA:BB:CC:DD:EE:12']!.via, NetworkMatchVia.hardware);
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:13')], [camRow('c1', hw: 'AABBCCDDEE10')], {}), isEmpty);
// 한 BLE ↔ 두 행(iOS 끝자리) → 없음
expect(matchOwnedDevices([camNamed('FB2_P4_CAM_EE12')], [camRow('c1', hw: '00111111EE10'), camRow('c2', hw: '00222222EE12')], {}), isEmpty);
// 한 행 ↔ 두 BLE → 둘 다 없음
expect(matchOwnedDevices([camNamed('FB2_P4_CAM_EE12'), camNamed('FB2_P4_CAM_EE10')], [camRow('c1', hw: '00111111EE10')], {}), isEmpty);
// 다른 종류 행은 보지 않는다
expect(matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')], [devRow('d1', hw: 'AABBCCDDEE10')], {}), isEmpty);
```

- [ ] **Step 2:** 실행 → 컴파일 실패 확인
- [ ] **Step 3:** 구현 + `pubspec.yaml` 0.179.0+(main 다음 build)
- [ ] **Step 4:** 통과, `flutter analyze` 0
- [ ] **Step 5:** 커밋 `feat(network): 등록 기기 알아보기·연결 상태 도메인 (0.179.0+N)`

---

### Task 2: 데이터 — 이 계정 기기 목록

**Files:**
- Modify: `lib/features/my_cage/data/device_add_registration_repository.dart`
- Test: `test/features/my_cage/device_add_registration_repository_test.dart`(없으면 Create — MockClient 패턴 `test/features/notification/notification_repository_test.dart:103`)

**Context:**
- Depends on: Task 1
- Produces: `Future<List<OwnedNetworkDevice>> networkDevices(String account)`
- Must know:
  - `devices`: `select('id,name,hw_id,is_online,last_seen_at,sys_state')`, `.eq('owner_id', account)`, `.isFilter('unlinked_at', null)`. `cameras`: `select('id,name,hw_id,is_online,last_seen_at,clip_stats')`, 같은 필터 + `.isFilter('superseded_at', null)`. 요청 전후 `_guard(account)`(같은 파일 `names()` 패턴).
  - rssi는 직접 파싱하지 않고 `SysHealth.fromDeviceRow`/`SysHealth.fromCameraRow`(`domain/sys_health.dart:125-146`)의 rssi를 쓴다.
  - 결과를 `camerasProvider`에 넣지 않는다(CLAUDE.md — `clip_stats`는 heartbeat마다 바뀜). 화면 열 때·[다시 스캔] 때만 읽는다.
- Acceptance: MockClient 테스트가 쿼리 파라미터(`owner_id=eq.a`, `unlinked_at=is.null`, 카메라 `superseded_at=is.null`)와 파싱(rssi 정수·누락 null, `is_online`)을 확인하고 통과.

- [ ] Step 1 실패 테스트 → Step 2 실패 확인 → Step 3 구현 → Step 4 통과 → Step 5 커밋 `feat(network): 네트워크 변경용 기기 목록 조회`

---

### Task 3: 컨트롤러 — 네트워크 변경 모드 추가 (옛 모드는 그대로 둔다)

**Files:**
- Modify: `lib/features/my_cage/domain/device_add_flow.dart` (`NetworkChangeRequest`, `DeviceAddState` 필드 추가)
- Modify: `lib/features/my_cage/presentation/device_add_flow_controller.dart`
- Modify: `lib/features/my_cage/presentation/device_add_flow_route.dart` (`deviceAddFlowProvider` 배선)
- Test: `test/features/my_cage/device_add_flow_test.dart` (새 group 추가, 기존 테스트 유지)

**Context:**
- Depends on: Task 1, 2
- Produces:
  - `class NetworkChangeRequest { const NetworkChangeRequest({this.preferredId}); final String? preferredId; }`
  - `final deviceAddNetworkChangeProvider = Provider<NetworkChangeRequest?>((ref) => null, dependencies: const []);` — **`deviceAddFlowProvider`의 `dependencies` 목록에 추가 필수**.
  - 컨트롤러 생성자 named 인자 추가: `NetworkChangeRequest? networkChange`, `Future<List<OwnedNetworkDevice>> Function()? networkDevices`, `Map<String, String> Function(List<DeviceAddCandidate>)? rememberedIds`(로컬 `KnownDeviceStore.load`만 — Supabase 호출 없음). `target`과 `networkChange`는 동시에 주지 않는다(assert).
  - `DeviceAddState` 추가 필드: `Map<String, NetworkMatch> owned`(physicalId → 매칭), `bool ownedLoadFailed`(copyWith로 유지되는 플래그).
- Must know (네트워크 변경 모드일 때만; 다른 모드 동작 불변):
  - 원본 스캔 목록을 `_raw`에 따로 두고, **스캔 갱신 때와 행 로드 완료 때마다** `matchOwnedDevices(_raw, rows, rememberedIds(_raw))`로 전체를 다시 맞춘다. `candidates` = 매칭된 것 중 `supportsWifiChange(kind)`인 것.
  - `scan()`이 매번 `networkDevices()`를 다시 읽는다. 실패 → `ownedLoadFailed: true`, 성공 → false.
  - preferred: `step == DeviceAddStep.scan`이고 그 종류에 고른 게 없고 아직 한 번도 자동 선택하지 않았으면, `preferredId` 행에 매칭된 후보를 한 번 고른다.
  - `_existingId(c)` = `state.owned[c.physicalId]?.device.id`. 매칭 없는 후보는 `select`가 무시한다.
  - 보내기 직전 `_owned(kind, id)`로 재확인 — null이면 그 기기 결과 `DeviceAddOutcome.failed` + 새 `failure: DeviceProvisionFailure.notOwned`(enum 값 추가), 등록으로 넘어가지 않는다.
  - `trusted` = `via == memory || !wasOnline`(hardware로만 알아본 온라인 기기는 기존 `unverified`).
  - `registerAsNew`: 이 모드에선 즉시 return. `groupConfirmed`·자동 그룹·새 이름은 부르지 않는다.
  - `continueAdding`([다시 찾기]): 실패·미확인 기기만 다시 고를 수 있게 scan 단계로, preferred 자동 선택은 다시 하지 않는다.
  - 로그: 매칭 때 `debugPrint('[device-add] network-match name=… kind=… row=… via=memory|hardware|none')`.
  - 비동기 뒤 `_active` 확인 후에만 `state=`.
- Acceptance: `flutter test test/features/my_cage/device_add_flow_test.dart` 통과(기존 + 새 group).

- [ ] **Step 1: 실패하는 테스트** (새 group `네트워크 변경 모드`)
  - `알아본 이 계정 기기만 보인다` — 후보 3(hw 일치 사육장, 불일치 사육장, 기억 일치 카메라) → candidates 2개, owned via 확인.
  - `행 로드 뒤 이미 잡힌 후보를 다시 맞춘다` — 스캔 먼저 방출, `networkDevices` Completer 나중 완료 → candidates 채워짐.
  - `scan 단계가 아니면 preferred로 고르지 않는다` — `loadNetworks()` 뒤 늦게 매칭 → selected 변화 없음.
  - `preferred는 한 번만` — 자동 선택 후 `select`로 해제 → 다음 스캔 갱신에도 비어 있음.
  - `Wi-Fi만 보낸다` — gateway 호출 모두 `wifiOnly: true`·`jwt: ''`, `outcome == wifiUpdated`, `registeredId == 행 id`.
  - `보내기 직전 행이 사라지면 실패, 등록 안 함` — `owned` 재확인 null → `failure == notOwned`, gateway `provision` 호출 0.
  - `hardware로만 알아본 온라인 기기는 unverified` / `memory면 online` — `_watchReconnect` 결과.
  - `registerAsNew는 아무것도 안 한다` — 호출 뒤 state 동일, `_replacing` 효과 없음(다음 connect도 wifiOnly).
  - `목록 조회 실패는 유지 플래그, 다시 스캔하면 재조회` — 스캔 결과가 와도 `ownedLoadFailed == true` 유지, 두 번째 `scan()` 성공 시 false.
  - `dispose 뒤 응답 무시`.
- [ ] Step 2 실패 확인 → Step 3 구현 → Step 4 `flutter test test/features/my_cage/` 통과 → Step 5 커밋 `feat(network): 기기 추가 흐름에 네트워크 변경 모드 추가`

---

### Task 4: 화면 — 목록·버튼·기기별 결과

**Files:**
- Modify: `lib/features/my_cage/presentation/device_add_flow_screen.dart`, `device_add_flow_route.dart`(`networkChange` 인자 전달), `assets/l10n/ko.json`
- Test: `test/features/my_cage/device_add_flow_screen_test.dart`, `test/design/text_scale_overflow_test.dart`

**Context:**
- Depends on: Task 3
- Produces: `DeviceAddFlowRoute({…, NetworkChangeRequest? networkChange})`, `DeviceAddFlowScreen({…, NetworkChangeRequest? networkChange})` — `wifiTarget`은 아직 남긴다(Task 6에서 삭제). 상태 줄 Key `network_change_health_<physicalId>`, 결과 줄 Key `network_change_result_<kind.name>`.
- Must know:
  - ko.json 추가(사용자 결정 1~4 확정값): `network_change_select_title` "네트워크 변경할 기기 선택", `network_change_selected` "기기 {}개 네트워크 변경"(결정 2), `network_health_good` "네트워크 연결 양호", `network_health_weak`/`network_health_offline`(결정 3), `network_change_load_failed`, `network_change_power_hint`(결정 1 — 부제 또는 빈 상태), `network_change_not_owned`(notOwned 결과 문구). 상단 제목은 `device_wifi_title`.
  - 목록 줄: 왼쪽 아이콘 + `Column(owned.device.name, 상태 줄)` — `unknown`이면 상태 줄 없음. 오른쪽(광고 이름·dBm·신호 그림)·체크박스는 기기 추가와 같다. 최소 높이 64.
  - `ownedLoadFailed`면 빈 상태보다 먼저 `network_change_load_failed`를 그린다.
  - CTA: 선택 시 `network_change_selected`, `device_add_selection_hint`는 이 모드에서 숨김.
  - 결과: 이 모드는 결과 수와 무관하게 **기기별 목록**(결정 4). 줄마다 이름(`state.owned.values.firstWhereOrNull((m) => m.device.id == result.registeredId)?.device.name ?? candidate.name`), 상태 문구는 기존 `_wifiUpdated` 문구(연결됐어요/확인 중/신호 안 옴/unverified)를 기기 이름으로 채워 재사용, notOwned는 `network_change_not_owned`. **[새 기기로 등록] 버튼 없음**, [다시 찾기]는 실패·미확인 기기가 있을 때. 닫기는 pop.
- Acceptance:
  - `네트워크 변경 목록: 이름·상태·Figma 수치` — `카메라 4`(online, −80) → 이름 600/16 #3C3C3C, `네트워크 신호 약함` w500/14/height 16.70703125÷14 #949090, 본문 제목 600/18, 상단 `네트워크 변경`.
  - `rssi 없으면 상태 줄 없음`, `목록 조회 실패 안내가 빈 상태보다 먼저`.
  - `두 대 결과가 모두 보인다` — 사육장 online + 카메라 missing → 두 결과 줄, `새 기기로 등록` 텍스트 findsNothing.
  - `기기 추가 모드는 그대로` — 기존 테스트 통과.
  - text_scale 1.0/1.3/2.0에 네트워크 변경 목록·결과 추가, 통과.
- [ ] Step 1 실패 테스트 → Step 2 확인 → Step 3 구현 → Step 4 통과 → Step 5 커밋 `feat(network): 네트워크 변경 목록·기기별 결과 화면(Figma 1913:6462·6570)`

---

### Task 5: 진입점 전환 + 라우트

**Files:**
- Modify: `lib/core/router/app_router.dart`(`/devices/network` 추가 — `/devices/wifi`는 아직 둔다), `lib/shared/widgets/redesign_tab_header.dart`, `lib/features/my_cage/presentation/widgets/live_notice_bar.dart`, `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart`, `lib/features/my_cage/presentation/device_detail_screen.dart`, `assets/l10n/ko.json`, `CHANGELOG.md`, `pubspec.yaml`(build +1)
- Test: `test/features/my_cage/live_notice_bar_test.dart`, `test/features/my_cage/webrtc_live_view_test.dart`, `test/features/my_cage/device_management_screen_test.dart`, `test/features/home/home_header_bar_test.dart`, `test/features/my_cage/crecam_home_test.dart`, 새 통합 테스트 `test/features/my_cage/network_change_route_test.dart`

**Context:**
- Depends on: Task 4
- Produces:
  - `GoRoute(path: '/devices/network', builder: (_, s) => DeviceAddFlowRoute(networkChange: NetworkChangeRequest(preferredId: s.extra is String ? s.extra as String : null)))`
  - `live_notice_bar.dart`: `liveNoticeTapPath` → `void openLiveNotice(BuildContext context, String kind, String cameraId)` — 신호 약함 `context.push('/devices/network', extra: cameraId)`, 초점 기존 경로.
- Must know:
  - 메뉴: 4번째 `('/devices/network', 'device_wifi_title')`(결정 6 — 세 탭 공용 헤더). 구분선 조건 `i == 2` → 마지막 인덱스 계산.
  - 기기 상세: `device_wifi_change` 줄과 `deviceWifiNameProvider` 사용 제거. `management_delete_confirm_wifi` 문구를 "[네트워크 변경]"으로 고친다(`device_detail_screen.dart:360-363` 분기·테스트 `device_management_screen_test.dart:428` 갱신).
  - 라이브 오프라인 [네트워크 변경](Key `webrtc_live_wifi_change` 유지) → `/devices/network` + extra 카메라 id.
  - CHANGELOG 0.179.0 항목을 여기서 채운다: 추가(네트워크 변경 흐름·메뉴), 변경(막대·라이브 오프라인 이동, 삭제 확인 문구), 제거(기기 상세 [Wi-Fi 바꾸기]).
- Acceptance:
  - 막대: 신호 약함 막대 어디를 눌러도 `/devices/network`, extra = 카메라 id. 초점 막대는 기존.
  - 메뉴(두 테스트 파일): 4항목 순서 `기기 추가/기기 관리/개체 추가 · 관리/네트워크 변경`, 마지막만 구분선 없음, 누르면 `/devices/network`.
  - 기기 상세: `Key('device_wifi_change')` findsNothing, 삭제 확인 문구 갱신.
  - 라이브 오프라인: [네트워크 변경] → `/devices/network`, extra 카메라 id.
  - 통합: 실제 `app_router`로 `/devices/network`를 열면 `deviceAddFlowProvider`가 네트워크 변경 모드(상단 "네트워크 변경", 본문 "네트워크 변경할 기기 선택")로 뜬다 — provider `dependencies` 누락 시 실패해야 한다.
- [ ] Step 1 실패 테스트 → Step 2 확인 → Step 3 구현 → Step 4 `flutter test test/features/` 통과·analyze 0 → Step 5 커밋 `feat(network): 막대·관리 메뉴·라이브에서 네트워크 변경으로, 기기 상세 Wi-Fi 바꾸기 제거`

---

### Task 6: 옛 단일 대상 모드 삭제 (단독 커밋) + 검수·문서

**Files:**
- Modify: `lib/core/router/app_router.dart`(`/devices/wifi` 삭제), `device_add_flow.dart`(`WifiChangeTarget` 삭제), `device_add_flow_controller.dart`(`_target`·`_loadTarget`·`_match`·`matched`·`targetGone` 삭제), `device_add_flow_route.dart`(`deviceAddWifiTargetProvider`·`wifiTarget` 삭제), `device_add_flow_screen.dart`(`wifiTarget` 분기·`device_wifi_confirm_other` 모달 삭제), `assets/l10n/ko.json`(더는 안 쓰는 `device_wifi_confirm_other`, `device_wifi_confirm_other_ok`, `device_wifi_next`, `device_wifi_action` — `grep`으로 미사용 확인한 것만), 관련 테스트(`device_add_flow_test.dart`, `device_add_flow_screen_test.dart`, `webrtc_live_view_test.dart`, `device_management_screen_test.dart`의 `WifiChangeTarget` 참조)
- Modify(문서): `CLAUDE.md`(Wi-Fi 바꾸기·라이브 오프라인 단락), `docs/ble-provisioning-protocol.md:19`, `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`(D2 확정), `CHANGELOG.md`·`pubspec.yaml`(build +1)
- Create: `docs/design-audits/2026-11-16-network-change/RESULTS.md` + `captures/`

**Context:**
- Depends on: Task 5
- Must know:
  - `device_wifi_target_gone`·`device_wifi_target_missing`·`device_wifi_retry`·`device_wifi_unverified*`는 Task 4 결과 화면이 쓰면 남긴다(grep).
  - 시뮬레이터엔 BLE가 없다 — 목록·결과는 커밋하지 않는 디버그 주입으로 캡처하고 되돌린다(2026-11-16 막대 검수와 같은 방식).
- Acceptance: `grep -rn "devices/wifi\|WifiChangeTarget\|deviceAddWifiTargetProvider" lib test` 없음, 전체 `flutter test` 통과, analyze 0, RESULTS.md에 Figma 대조표(메뉴·목록 줄·상태 줄·CTA·결과).
- [ ] Step 1: 삭제 + 테스트 정리 → `flutter test` 통과 → 커밋 `refactor(network): 기기별 Wi-Fi 바꾸기(단일 대상 모드) 삭제`
- [ ] Step 2: 시뮬레이터 캡처·대조 → RESULTS.md, 문서·CHANGELOG → 커밋 `docs(network): 네트워크 변경 화면 검수·문서`
- [ ] Step 3: 사용자 실기기 확인(Task 0 항목 2·4를 새 흐름으로 다시) → 결과 기록 → 병합 여부는 사용자 결정
