# 네트워크 변경 흐름 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙 — Implementer 에이전트(`flutter-dev`) 분리(GATE 4), task 단위로 구현한다. 실행은 `executing-plans` 스킬. Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: 📝 계획 — `/검수`·사용자 승인 전 (2026-11-16).

**Goal:** 근처 기기를 검색해 등록된 사육장·카메라를 골라 Wi-Fi만 한꺼번에 바꾸는 "네트워크 변경" 흐름을 만들고, 신호 약함 막대·홈 설정 메뉴·라이브 오프라인 안내에서 들어오게 하며, 기기 상세의 기기별 [Wi-Fi 바꾸기]를 없앤다.

**Architecture:** 기존 기기 추가 흐름(`DeviceAddFlowController`/`DeviceAddFlowScreen`)의 "단일 대상 Wi-Fi 바꾸기" 모드(`WifiChangeTarget`)를 **대상 없는 네트워크 변경 모드**로 바꾼다. 검색된 BLE 기기마다 이 계정의 등록 기기 행을 `hw_id`·이 폰의 기억으로 알아보고(`matchOwnedDevice`), 알아본 기기만 목록에 등록 이름·연결 상태와 함께 보인다. 고른 기기에는 지금 Wi-Fi 바꾸기와 같은 `SSID/PASS/CONNECT`만 보내고 그 행 `last_seen_at`으로 판정한다(등록 없음 → 같은 행 유지).

**Tech Stack:** Flutter, Riverpod(StateNotifier), GoRouter, flutter_blue_plus(기존 `DeviceAddBleAdapter`), Supabase 직결 SELECT, easy_localization.

**Spec:** Figma `네트워크 신호 약함` 섹션 `1877:14741` (talk-to-figma로 2026-11-16 조회). 기획 해석은 대화 합의(2026-11-16)를 따른다 — 아래 "기획 해석" 표. 관련: `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`(막대), `docs/ble-provisioning-protocol.md`(BLE 명령), 기기 추가 흐름 Figma 971:1837/990:11220.

### 기획 해석 (Figma 노드 → 결정)

| Figma | 결정 |
|---|---|
| `1913:7121` "진입 1 - 스낵바 터치" + 화살표 `1913:7128`(막대 `1913:7028` → `1913:6462`) | 신호 약함 막대 전체를 누르면 네트워크 변경 흐름 |
| `1913:7125` "진입 2 - 설정>네트워크 변경" + 화살표 `1913:7127`(`1913:7111` → `1913:6462`) | 홈·카메라 탭 헤더 관리 메뉴 4번째 "네트워크 변경" |
| `1912:5676` "이쪽 플로우는 지울까?" + `1913:7116` 메모("자동 검색 → 신호 세기 리스트 → 교체할 기기 선택 → 와이파이 선택… 이 방법이 나을 것 같아요") | 기기 상세 [Wi-Fi 바꾸기] 줄과 기기별 흐름(`/devices/wifi`) 제거 |
| `1913:7129` "연결된 와이파이 이름을 보여줘야하는데.." + 목록 안 `1913:7130`(이름 아래 "네트워크 연결 양호") | 목록 줄 왼쪽 이름 아래에 연결 상태 한 줄 |
| `1913:6462` 기기 검색01 / `1913:6570` 기기 선택02 / `1913:6618·6683` 네트워크 설정 / `1913:6743·6772` 비밀번호 | 화면 구성 — 상단 제목 "네트워크 변경", 나머지는 기기 추가 화면과 같은 틀 |

## 가정

- 확인:
  - 기기 추가 흐름은 이미 "종류별 1대씩 고르기(`DeviceAddState.selected: Map<PairTargetKind, …>`) → Wi-Fi 하나로 차례로 연결(카메라 먼저)"을 한다(`device_add_flow_controller.dart:415-470`). Figma 기기 선택02도 사육장 1 + 카메라 1을 고른 그림이다.
  - Wi-Fi만 바꾸기 경로(`_updateWifi`, `wifiOnly: true`, NAME·JWT 생략)와 서버 `last_seen_at` 판정(`_watchReconnect`, 5초 주기·90초 한도)이 이미 있다(`:638-770`).
  - 운영 DB(2026-11-16): 해제 안 된 `devices` 38행 모두 `hw_id`(12자) 있음, 37행 `sys_state.rssi` 있음. `cameras`(해제·대체 안 된) 25행 중 23행 `hw_id`(12자)·`clip_stats.sys.rssi` 있음.
  - 서버에 Wi-Fi 이름(SSID) 컬럼은 없다(`devices`·`cameras` 컬럼 조회 결과 없음). 이 폰이 붙인 이름만 `DeviceWifiNameStore`에 있다.
  - 헤더 관리 메뉴는 `lib/shared/widgets/redesign_tab_header.dart:174-178` 3항목, 마지막 줄만 구분선 없음(`i == 2`).
  - 진입점: 기기 상세 `device_detail_screen.dart:291-313`(Key `device_wifi_change`), 라이브 오프라인 `webrtc_live_view.dart:459-468`(Key `webrtc_live_wifi_change`), 막대 `live_notice_bar.dart` `liveNoticeTapPath`.
- 미확인:
  - **사육장이 `SSID/PASS/CONNECT`만으로 같은 `device_id`로 다시 붙는지**(`kWifiChangeDeviceEnabled`, 2026-09-28부터 실기기 미확인). 안 되면 사육장은 이 흐름에서 빠진다(Task 3 규칙).
  - **BLE 주소 ↔ `hw_id` 짝 맞추기(차이 0·2)**가 실제로 맞는지(`bleMatchesHardware`, 추정). Android는 MAC 전체, iOS는 광고 이름 끝 4자리만 본다.
  - 위 둘은 Task 6 실기기 확인(사용자만 가능)에서 판정한다.

## 선택지와 추천

| 결정 | 선택지 | 추천 |
|---|---|---|
| 구현 방식 | A. 기존 흐름에 "네트워크 변경 모드"를 넣고 `WifiChangeTarget` 모드를 없앤다 / B. 새 화면·컨트롤러를 따로 만든다 | **A** — BLE·네트워크·비밀번호·결과 화면과 Wi-Fi만 바꾸기 판정이 이미 검증돼 있다. 모드가 둘(추가·네트워크 변경)로 줄어 오히려 단순해진다 |
| 고를 수 있는 대수 | A. 종류별 1대(사육장 1·카메라 1) / B. 종류 상관없이 여러 대 | **A** — Figma 예시가 1+1이고, 상태·결과가 종류별 Map이라 B는 구조 변경이 크다. 2대 이상은 흐름을 한 번 더 돌면 된다 |
| 목록에 무엇을 보이나 | A. 이 계정 기기로 알아본 것만 / B. 전부 보이고 모르는 기기는 비활성 | **A** — 모르는 기기에 Wi-Fi만 보내면 서버에서 판정할 행이 없다. 비활성 줄은 Figma에 없는 문구가 필요하다 |
| 줄 왼쪽 이름 | A. 등록 이름("카메라 4") / B. 종류("카메라") | **A** — 같은 종류가 둘 이상이면 B로는 못 고른다. Figma도 "카메라1"이다 |
| 연결 상태 줄 | A. Figma "네트워크 연결 양호" + 약함·오프라인 문구 추가 / B. 양호만 | **A** — 상태가 나쁜 기기를 찾으러 들어온 흐름이라 약함·오프라인이 더 중요하다 |
| 막대·라이브에서 들어올 때 | A. 그 카메라를 찾으면 미리 체크 / B. 아무것도 안 고른 채 시작 | **A** — 어느 카메라 때문에 들어왔는지 이미 안다. 유저가 해제할 수 있다 |

## 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 근처에 이 계정 기기가 없음(전원 꺼짐·멀다·이 계정 아님) | 목록이 비어 있음 | 기존 빈 상태 문구(`device_add_searching`/`device_add_no_devices`) + [다시 스캔] |
| `hw_id` 짝 맞추기가 실제로 틀림 | 목록에서 기기를 못 알아봄 → 빈 목록 | 이 폰의 기억(`KnownDeviceStore`)도 함께 본다. Task 6에서 틀리면 계획 재검토(실기기 로그 `[device-add] network-match`로 원인 확인) |
| iOS에서 같은 계정 같은 종류 두 기기가 끝 4자리가 같음 | 둘 다 후보 | 후보가 2개 이상이면 알아보지 못한 것으로 친다(목록에서 숨김) — 엉뚱한 행으로 판정하지 않는다 |
| 사육장이 Wi-Fi만으로 같은 행에 안 붙음 | 90초 뒤 "신호가 오지 않아요"(기존 `reconnectMissing`) | Task 6에서 확인되면 `kWifiChangeDeviceEnabled=false` → 사육장은 목록에서 빠짐 |
| 고른 기기가 옛 Wi-Fi로 온라인인 채 진행 | 옛 접속 하트비트를 새 접속으로 볼 위험 | 기존 기준(영수증 뒤에 읽은 `last_seen_at`보다 새 값)을 유지. 알아본 기기만 고를 수 있어 "다른 기기 골랐을 수 있음" 경고 경로는 없앤다 |
| 비밀번호 틀림(`WIFI_FAIL`) | 그 기기 즉시 실패, 다시 시도 가능 | 기존 동작 그대로 |
| 블루투스 꺼짐·권한 없음 | 검색 시작 실패 | 기존 `DeviceAddScanException` 안내 그대로 |
| 행 조회(Supabase) 실패 | 기기를 알아볼 수 없음 | 오류 문구 `network_change_load_failed` + [다시 스캔]으로 재조회 |

## 유저 체험 시뮬레이션

1. 홈 라이브 위 "네트워크 신호가 약하니 점검해 주세요" 막대(어디든)를 누른다. → "네트워크 변경" 화면이 열리고 바로 근처 기기 검색이 시작된다. 제목 "네트워크 변경할 기기 선택" 옆에 검색 중 표시가 돈다. 아래 버튼 [다시 스캔]은 검색 중이라 회색이다.
2. 몇 초 안에 내 기기들이 줄로 나타난다. 왼쪽엔 동그란 아이콘과 내가 붙인 이름("사육장 2", "카메라 4")과 그 아래 회색 "네트워크 연결 양호"(또는 "네트워크 신호 약함"/"오프라인"), 오른쪽엔 기기 광고 이름과 블루투스 세기(-68 dBm)가 있다. 막대를 눌러 들어왔으면 그 카메라 줄은 이미 체크돼 있다. 우리 집 기기가 아니거나 내 계정 기기가 아니면 목록에 없다.
3. 사육장도 체크하면 아래 버튼이 "기기 2개 네트워크 변경"(문구는 사용자 결정 1)으로 바뀐다. 누르면 기기 추가 때와 같은 네트워크 선택 화면(상단 "네트워크 변경") → 비밀번호 화면.
4. 연결을 누르면 카메라부터 차례로 새 Wi-Fi를 받는다. 결과 화면에서 기기마다 "연결됐어요"/"신호가 오지 않아요"가 나온다. 이름·그룹·예약·기록은 그대로다(새 기기로 등록되지 않는다).
5. 홈·카메라 탭 오른쪽 위 관리 버튼을 누르면 메뉴 맨 아래 "네트워크 변경"이 있고, 같은 화면이 아무것도 체크되지 않은 채 열린다.
6. 기기 상세(기기 관리 → 기기)에는 더 이상 [Wi-Fi 바꾸기] 줄이 없다. 라이브가 오프라인일 때의 [네트워크 변경] 버튼은 그 카메라가 미리 체크된 같은 화면으로 간다.

## 근본 원인·전후 동작

- 전: 막대 → 그 카메라 기기 상세. Wi-Fi 변경은 기기 상세·라이브 오프라인에서 **기기 한 대씩**, 근처 기기 중 대상을 유저가 짐작해 고르고(못 알아보면 "이 기기가 맞나요?" 확인), 같은 종류만 목록에 뜬다.
- 후: 막대·관리 메뉴·라이브 오프라인 → 네트워크 변경 화면. 이 계정 기기로 알아본 것만 이름·연결 상태와 함께 뜨고 종류별 1대씩 함께 바꾼다. 기기 상세의 [Wi-Fi 바꾸기] 줄과 `/devices/wifi` 라우트는 없다.

## 검증 방법

1. `flutter analyze` 오류·경고 0.
2. `flutter test test/features/my_cage/ test/features/notification/ test/design/text_scale_overflow_test.dart test/regression/` 통과, 이어서 전체 `flutter test` 통과.
3. 시뮬레이터(iPhone 13 mini): 메뉴 4항목·막대 진입·라이브 오프라인 진입·기기 상세 줄 제거 캡처 → `docs/design-audits/2026-11-16-network-change/RESULTS.md`에 Figma 수치 대조(시뮬레이터엔 BLE가 없어 목록은 위젯 테스트 + 디버그 주입으로만 본다).
4. **실기기(사용자만 확인 가능):** 실제 폰으로 사육장 1·카메라 1의 Wi-Fi를 바꿔 ① 목록에 둘 다 이름으로 뜨는지(`[device-add] network-match` 로그) ② 바꾼 뒤 기기 관리에 행이 늘지 않고 같은 이름으로 온라인이 되는지(운영 DB `devices`/`cameras` 같은 `id`의 `last_seen_at` 갱신).

## 사용자가 정할 것

1. **기기 선택 버튼 문구** — Figma 1913:6573은 "기기 2개 추가"(기기 추가 화면 문구가 남은 것으로 보임). 추천: **"기기 {}개 네트워크 변경"**.
2. **연결 상태 문구(Figma엔 "네트워크 연결 양호"만)** — 추천: 양호 "네트워크 연결 양호" / 약함(−75 dBm 이하, 앱 기존 기준 `kWeakRssi`) "네트워크 신호 약함" / 오프라인 "오프라인" / 값 없음 → 줄 숨김.
3. **연결된 Wi-Fi 이름** — 서버에 없다. 추천: 이번엔 표시하지 않는다(이 폰이 붙인 이름만 알아 다른 폰·재설치면 틀린다). 서버가 `wifi_ssid`를 받으면 그때 상태 줄에 붙인다.
4. **실기기 확인 시점** — Task 6은 사용자 폰이 필요하다. 추천: 구현·병합 전에 확인(사육장 경로가 안 되면 출시 범위가 바뀐다).

## Global Constraints

- 문구(Figma 그대로): 상단 제목 "네트워크 변경"(기존 키 `device_wifi_title`), 본문 제목 "네트워크 변경할 기기 선택", 부제 "사육장 모듈 전원을 켜고 스마트폰 가까이 대어 주세요"(기존 `device_add_select_subtitle`, 1913:6476), 메뉴 "네트워크 변경", 상태 "네트워크 연결 양호".
- Figma 수치(1913:6462): 목록 줄 369×64·면 #F4F4F4·줄 사이 선 #E3E3E3·묶음 r12 / 아이콘 원 36 #3C3C3C(그림 20) / 왼쪽 이름 600·16·줄 19.09·자간 −0.32 #3C3C3C / 오른쪽 광고 이름 600·16 #1E1E1E / dBm 500·14·줄 16.71·자간 −0.28 #949090 + 신호 그림 16 #B4AEAE / 체크 24 / 본문 제목 600·18·줄 21.48·자간 −0.36 #3C3C3C / 부제 500·14 #626262 / CTA 369×56 r12(비활성 #E3E3E3, 글자 600·18·줄 28 #FAFAFA). 상태 줄(1913:7141): 500·14·줄 16.71·자간 −0.28 #949090, 이름 바로 아래.
- 글자 크기는 Figma 그대로 — 임의로 키우지 않는다(`AppTextScaler`).
- 하드코딩 문자열·색 금지(`ko.json` + `context.glass`). `CircularProgressIndicator` 금지(검색 중 표시는 기존 `_PairingProgress`).
- 사육장 제어 명령·BLE 명령 형식(`docs/ble-provisioning-protocol.md`)은 바꾸지 않는다. 네트워크 변경은 `wifiOnly: true`만.
- 버전: `lib/` 변경 → minor bump(현재 main 0.178.0+515 기준 다음 minor), CHANGELOG 한글 항목.
- 건드리지 않는 것: 기기 **추가** 흐름의 동작(등록·자동 그룹·"새 기기로 등록"), `DeviceAddBleAdapter`, `KnownDeviceStore` 저장 형식, `DeviceWifiNameStore`(저장은 계속, 표시만 안 함), 초점 안내 막대 이동(세로 확대 라이브), 서버·DB.

## Review Focus

1. **iOS 끝 4자리 충돌** — 같은 종류 등록 기기 둘이 `hw_id` 하위 2바이트(±2)가 겹치면 그 BLE 기기를 어느 쪽으로도 알아보지 않아야 한다 → Task 1 `matchOwnedDevice 후보가 둘이면 null`.
2. **해제·대체된 행** — `unlinked_at`/`superseded_at`이 있는 행으로 알아보면 안 된다 → Task 2 쿼리 필터 테스트.
3. **미리 체크한 카메라가 목록에 늦게 나타남** — 검색 몇 초 뒤에 떠도 한 번은 자동 체크, 유저가 해제한 뒤엔 다시 체크하지 않는다 → Task 3 `preferred는 처음 알아볼 때 한 번만 고른다`.
4. **계정 전환·화면 닫힘 중 검색 결과** — 닫힌 뒤 행 조회가 끝나도 상태를 쓰지 않는다 → Task 3 `dispose 뒤 owned 응답은 무시`.
5. **메뉴 구분선** — 4항목이 되며 마지막 줄만 선이 없어야 한다(지금 `i == 2` 고정) → Task 5 메뉴 테스트.

---

### Task 1: 도메인 — 등록 기기 알아보기·연결 상태

**Files:**
- Create: `lib/features/my_cage/domain/network_change.dart`
- Test: `test/features/my_cage/network_change_test.dart`

**Context:**
- Depends on: 없음
- Consumes: `DeviceAddCandidate`, `bleMatchesHardware`(`domain/device_add_flow.dart`), `PairTargetKind`, `kWeakRssi`(`domain/sys_health.dart`, −75)
- Produces:
  - `class OwnedNetworkDevice { final PairTargetKind kind; final String id; final String name; final String? hardwareId; final bool? isOnline; final DateTime? lastSeen; final int? wifiRssi; }` (const 생성자, 모두 named)
  - `enum NetworkHealth { good, weak, offline, unknown }`
  - `NetworkHealth networkHealthOf(OwnedNetworkDevice d)`
  - `OwnedNetworkDevice? matchOwnedDevice(DeviceAddCandidate c, List<OwnedNetworkDevice> rows, {String? rememberedId})`
- Must know:
  - 규칙 `networkHealthOf`: `isOnline == false` → offline / `wifiRssi == null` → unknown / `wifiRssi <= kWeakRssi` → weak / 그 외 good. (`isOnline == null`이면 rssi로만 판단.)
  - 규칙 `matchOwnedDevice`: 같은 `kind` 행만 본다. ① `rememberedId`가 그 행 중 하나의 `id`면 그 행. ② 아니면 `bleMatchesHardware(c, row.hardwareId)`가 참인 행이 **정확히 하나**면 그 행, 0개·2개 이상이면 null.
- Acceptance: `flutter test test/features/my_cage/network_change_test.dart` 전부 통과.

- [ ] **Step 1: 실패하는 테스트**

```dart
// 이름: 'networkHealthOf: 오프라인이 rssi보다 우선' 등 — 아래 assertion 그대로
expect(networkHealthOf(dev(isOnline: false, rssi: -40)), NetworkHealth.offline);
expect(networkHealthOf(dev(isOnline: true, rssi: null)), NetworkHealth.unknown);
expect(networkHealthOf(dev(isOnline: true, rssi: -75)), NetworkHealth.weak);
expect(networkHealthOf(dev(isOnline: true, rssi: -74)), NetworkHealth.good);
expect(networkHealthOf(dev(isOnline: null, rssi: -60)), NetworkHealth.good);

// 'matchOwnedDevice: 기억한 id가 hw보다 우선'
expect(matchOwnedDevice(cam('AA:BB:CC:DD:EE:12'), [camRow('c1', hw: 'AABBCCDDEE10'), camRow('c2', hw: 'FFFFFFFFFFFF')], rememberedId: 'c2')!.id, 'c2');
// 'Android MAC 차이 0·2만 같은 기기'
expect(matchOwnedDevice(cam('AA:BB:CC:DD:EE:12'), [camRow('c1', hw: 'AABBCCDDEE10')])!.id, 'c1');
expect(matchOwnedDevice(cam('AA:BB:CC:DD:EE:13'), [camRow('c1', hw: 'AABBCCDDEE10')]), isNull);
// 'iOS 이름 끝 4자리 — 후보가 둘이면 null'
expect(matchOwnedDevice(camNamed('FB2_P4_CAM_EE12'), [camRow('c1', hw: '111111EE10'.padLeft(12, '0')), camRow('c2', hw: '222222EE12'.padLeft(12, '0'))]), isNull);
// '다른 종류 행은 보지 않는다'
expect(matchOwnedDevice(cam('AA:BB:CC:DD:EE:12'), [devRow('d1', hw: 'AABBCCDDEE10')]), isNull);
```

(`cam`/`camNamed`/`camRow`/`devRow`/`dev`는 테스트 파일 안 헬퍼. iOS 경우의 `physicalId`는 UUID 문자열.)

- [ ] **Step 2:** `flutter test test/features/my_cage/network_change_test.dart` → 컴파일 실패(파일 없음) 확인
- [ ] **Step 3:** `network_change.dart`에 위 Produces 그대로 구현
- [ ] **Step 4:** 같은 명령 → 통과
- [ ] **Step 5:** 커밋 `feat(network): 등록 기기 알아보기·연결 상태 도메인`

---

### Task 2: 데이터 — 이 계정 기기 목록(연결 상태 포함)

**Files:**
- Modify: `lib/features/my_cage/data/device_add_registration_repository.dart`
- Test: `test/features/my_cage/device_add_registration_repository_test.dart`(없으면 Create, MockClient 패턴은 `test/features/notification/notification_repository_test.dart:103`)

**Context:**
- Depends on: Task 1
- Produces: `Future<List<OwnedNetworkDevice>> networkDevices(String account)`
- Must know:
  - `devices`: `select('id,name,hw_id,is_online,last_seen_at,sys_state')`, `owner_id = account`, `unlinked_at is null`. rssi = `sys_state['rssi']`(int, 없으면 null).
  - `cameras`: `select('id,name,hw_id,is_online,last_seen_at,clip_stats')`, `owner_id = account`, `unlinked_at is null`, `superseded_at is null`. rssi = `clip_stats['sys']['rssi']`.
  - 이 조회 결과를 `camerasProvider`에 넣지 않는다(CLAUDE.md: `clip_stats`는 heartbeat마다 바뀐다). 화면이 열릴 때·[다시 스캔] 때만 읽는다.
  - 계정 필터는 `.eq('owner_id', account)`, 요청 전후로 `_guard(account)`(같은 파일 `names()` 패턴 — 계정이 바뀌면 중단).
- Acceptance: 테스트가 두 요청의 쿼리 파라미터(`owner_id=eq.a`, `unlinked_at=is.null`, 카메라 `superseded_at=is.null`)와 파싱(rssi 정수·누락 시 null)을 확인하고 통과.

- [ ] **Step 1:** 실패 테스트 — `networkDevices('a')`가 MockClient 응답 `[{id:'d1',name:'사육장 2',hw_id:'AABBCCDDEE10',is_online:true,last_seen_at:'2026-11-16T03:00:00Z',sys_state:{rssi:-68}}]`·`[{id:'c1',name:'카메라 4',hw_id:null,is_online:false,last_seen_at:null,clip_stats:null}]`에서 `[OwnedNetworkDevice(kind: device, id:'d1', wifiRssi:-68, isOnline:true…), OwnedNetworkDevice(kind: camera, id:'c1', wifiRssi:null, isOnline:false…)]`을 돌려주고 위 쿼리 파라미터를 보낸다.
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 통과
- [ ] **Step 5:** 커밋 `feat(network): 네트워크 변경용 기기 목록 조회`

---

### Task 3: 컨트롤러 — 네트워크 변경 모드(대상 모드 대체)

**Files:**
- Modify: `lib/features/my_cage/domain/device_add_flow.dart` (`WifiChangeTarget` 삭제, `DeviceAddState`에 `owned` 추가·`matched`/`targetGone` 삭제)
- Modify: `lib/features/my_cage/presentation/device_add_flow_controller.dart`
- Modify: `lib/features/my_cage/presentation/device_add_flow_route.dart` (provider 배선)
- Test: `test/features/my_cage/device_add_flow_test.dart` (대상 모드 테스트를 네트워크 변경 모드로 옮김)

**Context:**
- Depends on: Task 1, 2
- Consumes: `OwnedNetworkDevice`, `matchOwnedDevice`, `networkDevices`
- Produces:
  - `class NetworkChangeRequest { const NetworkChangeRequest({this.preferredId}); final String? preferredId; }` (`device_add_flow.dart`) — 라우트 extra.
  - `deviceAddNetworkChangeProvider = Provider<NetworkChangeRequest?>((ref) => null, dependencies: const [])` — `deviceAddWifiTargetProvider` 대체. null = 기기 추가.
  - 컨트롤러 생성자: `WifiChangeTarget? target` → `NetworkChangeRequest? networkChange`, `Future<List<OwnedNetworkDevice>> Function()? networkDevices` 추가.
  - `DeviceAddState.owned: Map<String, OwnedNetworkDevice>` — BLE `physicalId` → 알아본 행.
  - 기존 공개 메서드(`scan`/`select`/`loadNetworks`/`connect`/`recheckRegistration`/`continueAdding`/`registerAsNew`) 시그니처 유지.
- Must know:
  - 네트워크 변경 모드에서:
    - `scan()` 시작 때 `networkDevices()`를 한 번 읽어 둔다(실패 → `errorKey: 'network_change_load_failed'`, 다음 `scan()`에서 다시 읽음).
    - 스캔 결과마다 `matchOwnedDevice(c, rows, rememberedId: await _known(c))`로 알아보고 `state.owned`를 채운다. `candidates`는 **알아본 것 중 `supportsWifiChange(kind)`인 것만**.
    - `preferredId`와 같은 행을 처음 알아본 순간, 그 종류에 아직 고른 게 없으면 한 번만 `select`. 이후엔 다시 고르지 않는다(유저 해제 존중).
    - `_existingId(c)` = `state.owned[c.physicalId]?.id`. 등록(JWT) 경로는 이 모드에서 절대 타지 않는다 — 알아보지 못한 기기는 고를 수 없다.
    - `_updateWifi`의 `trusted`는 항상 true(알아본 기기만 고른다). "다른 기기 골랐을 수 있음"(`unverified`) 결과는 이 모드에서 생기지 않는다.
    - 자동 그룹(`_group`)·`completed` 외 기기 추가 전용 처리(`groupConfirmed`, 새 이름)는 부르지 않는다.
  - 기기 추가 모드(`networkChange == null`)의 동작은 바꾸지 않는다 — 기존 테스트가 그대로 통과해야 한다.
  - 판정용 로그: 알아볼 때 `debugPrint('[device-add] network-match name=… kind=… row=… via=memory|hw|none')`(Task 6 실기기 확인용).
  - `ref`/`mounted` 규칙: 비동기 뒤 `_active` 확인 후에만 `state=`.
- Acceptance: `flutter test test/features/my_cage/device_add_flow_test.dart` 통과, 아래 새 테스트 포함.

- [ ] **Step 1: 실패하는 테스트** (페이크 gateway·owned는 기존 파일 헬퍼 재사용)
  - `네트워크 변경은 이 계정 기기로 알아본 것만 보인다` — 후보 3(사육장 hw 일치, 사육장 불일치, 카메라 기억 일치) → `state.candidates.map((c) => c.physicalId)` == 일치 2개, `state.owned[..]!.id` 확인.
  - `preferred는 처음 알아볼 때 한 번만 고른다` — 카메라가 두 번째 스캔 갱신에 나타나면 `selected[camera]` 설정, `select`로 해제 후 다음 갱신에서도 비어 있음.
  - `네트워크 변경 연결은 등록 없이 Wi-Fi만 보낸다` — `connect` 후 gateway 호출이 모두 `wifiOnly: true`, `jwt: ''`, 결과 `outcome == wifiUpdated`, `registeredId == 알아본 행 id`.
  - `기기 목록을 못 읽으면 오류, 다시 스캔하면 재조회` — 첫 `networkDevices` throw → `errorKey == 'network_change_load_failed'`, 두 번째 `scan()`에서 호출 2회.
  - `dispose 뒤 owned 응답은 무시` — 조회 Completer를 dispose 뒤 완료해도 예외·상태 변경 없음.
  - `kWifiChangeDeviceEnabled가 false면 사육장은 빠진다`는 상수라 테스트하지 않는다 — `supportsWifiChange` 경유만 확인(코드 리뷰 대상).
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3:** 구현(대상 모드 코드·`matched`·`targetGone`·`device_wifi_confirm_other` 분기 제거 포함)
- [ ] **Step 4:** `flutter test test/features/my_cage/` 통과
- [ ] **Step 5:** 커밋 `feat(network): 기기 추가 흐름에 네트워크 변경 모드(기기별 Wi-Fi 바꾸기 대체)`

---

### Task 4: 화면 — 네트워크 변경 목록·버튼

**Files:**
- Modify: `lib/features/my_cage/presentation/device_add_flow_screen.dart`
- Modify: `assets/l10n/ko.json`
- Test: `test/features/my_cage/device_add_flow_screen_test.dart`

**Context:**
- Depends on: Task 3
- Consumes: `DeviceAddState.owned`, `networkHealthOf`, `NetworkHealth`
- Produces: `DeviceAddFlowScreen({…, NetworkChangeRequest? networkChange})` — `wifiTarget` 파라미터 대체. 화면 Key: 상태 줄 `network_change_health_<physicalId>`.
- Must know:
  - ko.json 추가(사용자 결정 1·2 확정값으로): `network_change_select_title` "네트워크 변경할 기기 선택", `network_change_selected` "기기 {}개 네트워크 변경", `network_health_good` "네트워크 연결 양호", `network_health_weak` "네트워크 신호 약함", `network_health_offline` "오프라인", `network_change_load_failed` "기기 정보를 불러오지 못했어요. 다시 스캔해 주세요". 삭제: `device_wifi_confirm_other`, `device_wifi_confirm_other_ok`, `device_wifi_next`, `device_wifi_target_gone`, `device_wifi_unverified_title`, `device_wifi_unverified`, `device_wifi_action`, `device_wifi_name` — 각 키가 더는 쓰이지 않음을 `grep`으로 확인한 것만.
  - 모드일 때: 상단 제목 `device_wifi_title`, 본문 제목 `network_change_select_title`, 부제 `device_add_select_subtitle`. 줄 왼쪽 = 아이콘 + `Column(이름 owned.name, 상태 줄)`; 상태 줄은 `NetworkHealth.unknown`이면 그리지 않는다. 오른쪽(광고 이름·dBm·신호 그림)·체크박스는 기기 추가와 같다. 선택 시 CTA `network_change_selected`(args: 선택 수). `device_add_selection_hint`("함께 사용할 기기를…")는 이 모드에서 보이지 않는다.
  - Figma 수치는 Global Constraints. 줄 높이는 상태 줄이 있어도 최소 64(글자 키우면 늘어남).
  - 네트워크 선택·비밀번호 화면은 모드와 무관하게 기존 그대로(상단 제목만 `device_wifi_title`).
  - 결과 화면(`device_add_flow_screen.dart` 1053줄 부근 결과 줄)의 `widget.wifiTarget` 참조: 대상 이름은 `state.owned.values.firstWhere((r) => r.id == result.registeredId).name`으로 바꾼다. "신호가 오지 않아요"(`device_wifi_target_missing`)·[다시 찾기](`device_wifi_retry`)는 유지, `unverified` 분기(`device_wifi_unverified*`)는 삭제(이 모드에서 안 생김).
- Acceptance: 아래 테스트 통과 + `test/design/text_scale_overflow_test.dart`에 네트워크 변경 목록(1.0/1.3/2.0) 추가해 통과.

- [ ] **Step 1: 실패하는 테스트**
  - `네트워크 변경 목록: 등록 이름·연결 상태·Figma 수치` — 상태 `owned`에 `카메라 4`(online, −80) → `find.text('카메라 4')` 600/16 #3C3C3C, `find.text('네트워크 신호 약함')` w500/14/height 16.70703125/14 #949090, 본문 제목 `네트워크 변경할 기기 선택` 600/18, 상단 `네트워크 변경`.
  - `rssi 없으면 상태 줄 없음` — `find.byKey(Key('network_change_health_…'))` findsNothing.
  - `선택하면 '기기 2개 네트워크 변경'` — 사육장·카메라 선택 상태에서 CTA 문구.
  - `기기 추가 화면엔 상태 줄이 없다` — 모드 null이면 기존 렌더 그대로(기존 테스트 유지).
- [ ] **Step 2:** 실패 확인 → **Step 3:** 구현 → **Step 4:** `flutter test test/features/my_cage/device_add_flow_screen_test.dart test/design/text_scale_overflow_test.dart` 통과
- [ ] **Step 5:** 커밋 `feat(network): 네트워크 변경 기기 목록 화면(Figma 1913:6462·6570)`

---

### Task 5: 진입점·라우트 정리

**Files:**
- Modify: `lib/core/router/app_router.dart` (`/devices/wifi` 삭제, `/devices/network` 추가)
- Modify: `lib/shared/widgets/redesign_tab_header.dart` (메뉴 4번째)
- Modify: `lib/features/my_cage/presentation/widgets/live_notice_bar.dart` (신호 약함 이동)
- Modify: `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart` (오프라인 [네트워크 변경])
- Modify: `lib/features/my_cage/presentation/device_detail_screen.dart` (Wi-Fi 줄 삭제)
- Modify: `assets/l10n/ko.json` (`redesign_network_change` "네트워크 변경")
- Test: `test/features/my_cage/live_notice_bar_test.dart`, `test/features/my_cage/webrtc_live_view_test.dart`, `test/features/my_cage/device_management_screen_test.dart`, 헤더 메뉴 테스트(기존 `redesign_tab_header` 테스트 파일 — `grep -rl redesign_tab_header test`로 찾음)

**Context:**
- Depends on: Task 3, 4
- Consumes: `NetworkChangeRequest`, `DeviceAddFlowRoute(networkChange: …)`
- Produces:
  - 라우트 `GoRoute(path: '/devices/network', builder: (_, s) => DeviceAddFlowRoute(networkChange: NetworkChangeRequest(preferredId: s.extra is String ? s.extra as String : null)))`
  - `DeviceAddFlowRoute`: `wifiTarget` 파라미터 → `NetworkChangeRequest? networkChange`.
  - `live_notice_bar.dart`: `liveNoticeTapPath` → `void openLiveNotice(BuildContext context, String kind, String cameraId)` — 신호 약함 `context.push('/devices/network', extra: cameraId)`, 초점 `context.push('/crecam/cameras/$cameraId/live')`.
- Must know:
  - 메뉴: `('/devices/network', 'redesign_network_change')`를 맨 끝에. 구분선 조건 `i == 2` → `i == 마지막 인덱스`(항목 수에서 계산).
  - 기기 상세: `device_wifi_change` 줄과 `deviceWifiNameProvider` 사용 제거. `deviceWifiNameProvider`가 다른 곳에서 안 쓰이면 provider도 삭제(저장소 `DeviceWifiNameStore`는 남긴다 — Global Constraints).
  - 라이브 오프라인 버튼 Key `webrtc_live_wifi_change` 유지, 이동만 `/devices/network` + extra 카메라 id. `showWifiChange` 파라미터 의미 유지.
- Acceptance: 
  - 막대 테스트: 신호 약함 막대 어디를 눌러도 `/devices/network`로 가고 extra가 그 카메라 id, 초점 막대는 기존 경로.
  - 메뉴 테스트: 4항목 순서 `기기 추가/기기 관리/개체 추가 · 관리/네트워크 변경`, 마지막만 구분선 없음, 누르면 `/devices/network`(extra 없음).
  - 기기 상세 테스트: `find.byKey(Key('device_wifi_change'))` findsNothing.
  - 라이브 오프라인 테스트: [네트워크 변경] → `/devices/network`, extra 카메라 id.
  - `grep -rn "devices/wifi\|WifiChangeTarget" lib test` 결과 없음.

- [ ] **Step 1:** 위 Acceptance 테스트 작성 → **Step 2:** 실패 확인 → **Step 3:** 구현 → **Step 4:** `flutter test test/features/` 통과 + `flutter analyze` 0
- [ ] **Step 5:** 커밋 `feat(network): 막대·관리 메뉴·라이브에서 네트워크 변경으로, 기기 상세 Wi-Fi 바꾸기 제거`

---

### Task 6: 검수·문서·버전 (메인)

**Files:**
- Create: `docs/design-audits/2026-11-16-network-change/RESULTS.md` + `captures/`
- Modify: `CHANGELOG.md`, `pubspec.yaml`, `CLAUDE.md`(라이브 오프라인·Wi-Fi 바꾸기 단락의 `/devices/wifi`·기기 상세 [Wi-Fi 바꾸기] 서술을 새 흐름으로), `docs/superpowers/specs/2026-11-14-camera-weak-signal-notice-design.md`(D2 확정)

**Context:**
- Depends on: Task 1~5
- Must know:
  - 시뮬레이터엔 BLE 기기가 없다. 목록 화면은 커밋하지 않는 디버그 주입으로 캡처하고, 캡처 뒤 되돌린다(2026-11-16 막대 검수와 같은 방식).
  - 실기기 확인(검증 방법 4)은 사용자만 가능 — 결과를 RESULTS.md에 기록. 사육장이 같은 행으로 안 붙으면 `kWifiChangeDeviceEnabled=false`로 바꾸고 CHANGELOG에 "사육장은 아직 지원하지 않음"을 적는다(사용자 확인 후).
  - CHANGELOG: 추가(네트워크 변경 흐름·메뉴), 변경(막대 이동·라이브 오프라인 이동), 제거(기기 상세 Wi-Fi 바꾸기).
- Acceptance: 전체 `flutter test` 통과, `flutter analyze` 0, RESULTS.md에 Figma 수치 대조표(메뉴·목록 줄·상태 줄·CTA).

- [ ] **Step 1:** 시뮬레이터 캡처·수치 대조 → RESULTS.md
- [ ] **Step 2:** 문서·CHANGELOG·버전
- [ ] **Step 3:** 전체 테스트·analyze
- [ ] **Step 4:** 커밋 `docs(network): 네트워크 변경 화면 검수·패치노트 (0.179.0+516)`
- [ ] **Step 5:** 사용자 실기기 확인 요청 → 결과 기록 후 병합 여부 결정(사용자)
