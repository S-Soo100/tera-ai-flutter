# 사육장·카메라 BLE Wi-Fi 프로비저닝 프로토콜

> **단일 진실 소스.** 사육장(`terra-iot`)·카메라(`FB2_P4_CAM`) 기판을 Wi-Fi에 연결하는 BLE 규격과 앱 구현 계약.
> 원본 스펙: `~/Desktop/사육장 ble_protocol.md`, `~/Desktop/camera BLE_WIFI_PROVISIONING.md`
> 관련 문서: terra-server IoT 계약 `~/Downloads/APP_INTEGRATION.md`, DB 스키마 `docs/supabase-schema.md`
> 최종 갱신: 2026-09-25 (재등록 시 새 행 정정·BLE 실패 분류·카메라 우선 연결) · 2026-09-18 (사육장 앱 경유 등록 복원 — 펌웨어 요청서 `~/Desktop/APP_REQUEST_DEVICE_PAIRING_2026-09-17.md`)

## 0-A. 2026-09-18 개정 — 사육장은 기기가 직접 서버 등록 (현행)

펌웨어 대조 결과 **사육장 펌웨어는 처음부터 `NAME:`+JWT를 받아 기기가 `POST /devices/pair`를 호출하는 방식**이었다. 2026-07-02 개편에서 앱이 이 명령을 빼면서(아래 §0 (a) 방식) 9/7 이후 신규 등록이 0건이 됐다(펌웨어는 `NAME:`이 없으면 조용히 등록을 건너뜀).

| 대상 | 앱 → 기기 시퀀스 | 완료 판정 |
|---|---|---|
| 사육장 `terra-iot` | `UNPAIR` → `SSID:` → `PASS:` → `NAME:<기본 이름>` → `JWT_BEGIN <길이>` → `JWT:<청크>`×N → `CONNECT` | `PAIR_OK <device_id>` → `devices`에서 `owner_id`+`device_id`로 확인되면 **등록 완료**. `PAIR_OK`가 없거나 `PAIR_FAIL <사유>`면 **등록 대기** — 결과 화면에 사유(구 펌웨어/`PAIR_FAIL` 사유/무응답, `DeviceRegistrationIssue`)를 밝히고 **사육장은 다시 연결 가능**(⚠️ 2026-09-25 정정: UNPAIR 뒤 재등록하면 서버 `pair_device`가 순수 INSERT라 **새 `device_id`로 새 행**이 생긴다 — 운영 DB에서 같은 `hw_id`가 여러 행. 늦게 등록된 앞 행은 해제 없이 남을 수 있다). 앱은 id를 추측하거나 목록 차이로 새 기기를 판정하지 않는다 |
| 카메라 `FB2_P4_CAM` | `SSID:` → `PASS:` → `NAME:` → (`NAME_OK`면 `JWT_BEGIN`/`JWT`) → `CONNECT` | `UNPAIR`는 보내지 않는다(플래시 때 개발 계정으로 된 등록이 지워질 수 있음). `NAME:`에 `ERR:UNKNOWN_CMD`/무응답인 구 펌웨어는 JWT 없이 Wi-Fi만 연결하고 등록 대기로 표시한다. (2026-09-25: 운영 카메라 펌웨어 fb2-p4 0.1.0은 NAME/JWT를 받아 **매번 새 `camera_id`로 등록**한다 — 운영 DB 확인) |
| 스캔 목록 '이미 등록됨' (2026-09-21) | (명령 없음) | 등록을 마친 기기도 몇 분간 광고한다(카메라는 3분 뒤 꺼짐, 관훈님 회신). 이 폰이 등록한 기기(BLE 주소+광고 이름 → 행 id, Hive `known_camera_*`/`known_device_*`)이고 그 행이 이 계정에 해제 없이 남아 있으면 목록에 '이미 등록됨'을 붙이고 아래로 내린다(`KnownDeviceStore`, `DeviceAddState.registered`). 사육장 기억은 표시 전용 — 연결하면 늘 새로 등록 |
| 카메라 Wi-Fi 변경 (2026-09-21) | `SSID:` → `PASS:` → `CONNECT` (`NAME`·`JWT` 생략) | 이 폰이 등록한 카메라(BLE 주소+광고 이름 `FB2_P4_CAM_<MAC 하위 2바이트>` → `cameras.id`, Hive `known_camera_<계정>_<주소>`)이고 그 행이 이 계정에 해제 없이 남아 있으면 이 경로. 펌웨어는 JWT가 없으면 pair를 호출하지 않고 재부팅 뒤 NVS의 기존 `camera_id`로 재접속한다(app_ble_prov.c `have_jwt`). JWT를 보내면 매번 새 `camera_id`로 등록돼 행이 늘어난다. 90초 안에 `last_seen_at`이 갱신되지 않으면 결과 화면에 '새 카메라로 등록' |

- 응답 확인: `UNPAIR`는 미지원 펌웨어의 `ERR:UNKNOWN_CMD`·무응답을 삼키고 진행한다. `NAME:`에 `ERR:UNKNOWN_CMD`·무응답이면 구 펌웨어로 보고 JWT를 보내지 않는다(그 외 `ERR:`는 실패). `NAME_OK` 뒤에는 `JWT_BEGIN_OK`와 `JWT_OK <길이>`가 필수 — 없거나 `ERR:`거나 길이가 다르면 **`CONNECT`하지 않고 실패**(다시 시도 안전).
- JWT: 등록 직전에 `refreshSession()`으로 갱신한 access token(`freshAccessTokenProvider`). 갱신 실패 시 유효한 현재 토큰. 청크 길이는 협상된 MTU−7(최대 200).
- 기본 이름: 종류별 접두(`device_add_device`/`device_add_camera`) + 사육장·카메라 이름 전체에서 쓰지 않는 번호(`nextManagementName`, 재설계 확정 기획 §7).
- 그룹 배정: 등록 요청에 그룹 id가 없어 등록 뒤 사육장 연동 화면에서 배정(Supabase 직결 UPDATE, RLS owner). 펌웨어 `ENC:`(§2-4)가 생기면 시퀀스에 추가 검토.
- 로그: 자격증명·JWT가 흘러나가지 않도록 BLE SDK 로그를 끄고(`suppressCredentialLogging`) 명령 내용은 남기지 않는다.
- 2026-09-25 앱 동작: `CONNECT` 전에 끝난 실패는 `DeviceProvisionFailure`(ble·session·rejected)로 나눠 비밀번호 오류(`WIFI_FAIL`)와 구분해 안내한다. 사육장·카메라를 함께 고르면 카메라부터 보낸다(3분 광고). 이미 등록된 사육장을 고르면 "새 기기로 등록된다" 확인을 받는다. "새 카메라로 등록"은 새 등록 성공 뒤 옛 `cameras` 행을 REST `unlink`한다.
- 구현: `DeviceAddBleAdapter.provision`(`device_add_ble_adapter.dart`) + `DeviceAddFlowController`/`DeviceAddRegistrationRepository`, 화면 `DeviceAddFlowRoute`(구 `/smart-cage/devices/pair`·`/crecam/cameras/pair`도 이 흐름으로 연결). 테스트 `test/features/my_cage/device_add_ble_adapter_test.dart`. (2026-09-18 main의 `sendWifiCredentials(registration:)`/`PairingRegistrar` 구현은 재설계 병합 때 이 흐름으로 통합·제거)

## 0. 페어링 아키텍처 결정 (2026-07-02 — 사육장은 §0-A로 대체, 카메라는 유지)

**앱의 역할은 "기판을 Wi-Fi에 붙이는 것"까지다.** 기기 인증 토큰 발급·서버 등록(owner 바인딩)은 앱이 하지 않는다.

### 근거 (DB 실측, 2026-07-02)

| 사실 | 함의 |
|------|------|
| `devices`·`cameras`의 `token_hash` **NOT NULL** (bcrypt `$2b$12$…`, 60자) | 기기↔MQTT 인증 비밀번호가 필수. 없는 기기는 존재 불가 |
| `owner_id` **NOT NULL** | 주인 없는 기기 row 불가 |
| 두 테이블 **INSERT RLS 정책 없음** (SELECT/UPDATE/DELETE만, `auth.uid() = owner_id`) | 앱(authenticated)의 직접 INSERT 불가 → 서버(service_role)만 등록 가능 |

즉 "토큰 발급 + row INSERT"는 서버 로직(원래 REST `/devices/pair`·`/cameras/pair`)의 몫이고, 앱이 대신할 수 없다. **토큰을 기판에 주입하는 BLE 명령도 이 프로토콜에 없다.**

### 채택 방식 (a): 기판·DB 사전 세팅

1. 기판에 토큰을 미리 심고, `devices`/`cameras` row(`device_id`·`token_hash`·`owner_id`)를 미리 등록해 둔다.
2. 앱은 BLE로 **Wi-Fi만** 붙인다.
3. 기판이 자기 토큰으로 서버(MQTT) 로그인 → telemetry/clip 저장 시작.
4. row의 `owner_id`가 이미 사용자 계정이므로 앱 목록(RLS SELECT)에 자동 표시.

→ **앱은 `devices`/`cameras`를 읽기(목록)만 한다. INSERT/UPDATE/토큰 처리 없음.**

### 향후 확장 (미구현 — 자리만)

"앱에서 새 기판을 완전 자동 등록"하려면 다음 중 하나가 필요(현재 프로토콜에 없음):

- **(b) 펌웨어 self-register**: Wi-Fi 연결 후 기판이 chip_id + 자체 토큰으로 서버 등록. `owner_id` 바인딩 방식 확정 필요.
- **pair API화**: 앱이 `POST /devices/pair`·`/cameras/pair`(JWT) 직접 호출. 추가로 필요한 것:
  - 서버의 앱-직접-호출 지원
  - 발급 토큰을 기판에 주입하는 BLE 명령 (예: `TOKEN:<token>`)
  - 기판이 식별자를 앱에 알리는 BLE 응답 (예: `DEVID:<chip_id>`)

## 1. GATT 스펙 (사육장·카메라 공통)

| 항목 | UUID | 속성 | 방향/용도 |
|------|------|------|-----------|
| Service | `12345678-1234-1234-1234-123456789abc` | Primary | — |
| TX | `12345678-1234-1234-1234-123456789abd` | Notify | 기기→앱 (상태·스캔결과) |
| RX | `12345678-1234-1234-1234-123456789abe` | Write / Write No Response | 앱→기기 (명령) |

- 앱은 TX를 **구독(subscribe)** 해야 응답을 받는다.
- 모든 명령/응답은 **UTF-8 문자열**.

## 2. 명령 / 응답 프로토콜

### 앱 → 기기 (RX write)

| 명령 | 제한 | 설명 |
|------|------|------|
| `SCAN` | — | 주변 Wi-Fi 스캔 시작 |
| `SSID:<이름>` | 최대 32자 | 접속할 SSID |
| `PASS:<비번>` | 최대 64자 | Wi-Fi 비밀번호 |
| `CONNECT` | SSID 필수 | 설정값으로 연결 시도 |
| `UNPAIR` | 사육장, 펌웨어 §2-2 | 저장된 서버 자격증명 삭제 → `UNPAIR_OK`. 다음 `CONNECT`에서 새로 등록 |
| `NAME:<이름>` | 사육장 | 등록 시 기기 이름 → `NAME_OK` |
| `JWT_BEGIN <길이>` | 사육장 | JWT 수신 시작 → `JWT_BEGIN_OK` |
| `JWT:<청크>` | ≤200자, 사육장 | JWT 조각. 다 받으면 `JWT_OK <길이>` |

### 기기 → 앱 (TX notify)

```
[스캔]  SCANNING → SCAN:<count> → AP:<no>,<ssid>,<rssi>,<channel> (개수만큼 반복) → SCAN_END
        실패: SCAN_FAIL / NO_AP_FOUND(사육장)
[설정]  SSID_OK / PASS_OK
[연결]  CONNECTING → WIFI_OK | WIFI_FAIL
[등록]  UNPAIR_OK / NAME_OK / JWT_BEGIN_OK / JWT_OK <길이> / PAIR_OK <device_id> | PAIR_FAIL <401|timeout|no_name|server_5xx> (PAIR_* 는 펌웨어 §2-1 이후)
[에러]  ERR:NO_SSID / ERR:UNKNOWN_CMD / ERR:NO_CONNECT_CB(카메라)
```

## 3. AP 파싱 규칙 (중요)

`AP:<no>,<ssid>,<rssi>,<channel>` — **ssid에 콤마가 포함될 수 있다.**

→ `AP:` 접두 제거 후 **맨 앞 토큰 = no, 맨 뒤 토큰 = channel, 뒤에서 둘째 = rssi**로 분리하고, **가운데 나머지 전체를 ssid**로 재조합한다(콤마 포함 SSID 안전 처리).

스캔 항목은 약 80ms 간격으로 오며, `SCAN_END`까지 받은 뒤 목록을 확정한다.

## 4. 디바이스 구분

사육장·카메라가 **같은 Service UUID**를 광고하므로 **BLE 광고 이름**으로 구분한다.

| 종류 | 광고 이름 |
|------|-----------|
| 사육장 | `terra-iot` |
| 카메라 | `FB2_P4_CAM` |

각 페어링 화면은 자기 종류의 이름만 스캔 목록에 표시한다.

## 5. 기종별 차이

| 항목 | 사육장 `terra-iot` | 카메라 `FB2_P4_CAM` |
|------|--------------------|---------------------|
| 스택 / 칩 | — | NimBLE / ESP32-P4 (FireBeetle2) |
| MTU | 256 | — |
| 최대 동시 연결 | 3 | — |
| 광고 간격 | 500~510ms | — |
| write 최대 | (MTU 256) | 255 바이트 |
| "AP 없음" 응답 | `NO_AP_FOUND` | (`SCAN_FAIL`) |
| 고유 에러 | — | `ERR:NO_CONNECT_CB` |
| 디스크립터 | — | `0x2901` (WiFi Status / WiFi Command 라벨) |
| ⚠ 선결조건 | — | C6 esp-hosted 슬레이브 펌웨어로 광고 미출력 가능 → **스캔에 잡히는지 우선 확인** |

## 6. 앱 구현 매핑

| 요소 | 위치 |
|------|------|
| Repository | `lib/features/my_cage/data/ble_pairing_repository.dart` |
| Wi-Fi AP 모델 | `lib/features/my_cage/domain/wifi_access_point.dart` |
| 종류 enum | `PairTargetKind { device, camera }` |
| 사육장 페어링 화면 | `device_pairing_screen.dart` → 라우트 `/smart-cage/devices/pair` |
| 카메라 페어링 화면 | `camera_pairing_screen.dart` → 라우트 `/crecam/cameras/pair` |
| 비밀번호 자동저장·자동채움 | `lib/features/my_cage/data/wifi_credentials_store.dart` (2026-09-11) |

**앱 흐름:** BLE 스캔(이름 필터) → 기기 선택 → BLE 연결 → `SCAN` → AP 목록 표시 → 선택 + 비번 입력 → (사육장: `UNPAIR` 선행 + `NAME`/`JWT` 삽입, §0-A) `SSID`/`PASS`/`CONNECT` → `WIFI_OK` → `PAIR_OK` 확인 시 등록 완료, 아니면 등록 대기 → 기기 목록 갱신.

**비밀번호 자동저장·자동채움 (2026-09-11):** `WifiCredentialsStore`가 SSID→비밀번호 맵을 `flutter_secure_storage`(iOS Keychain / Android Keystore)에 보관한다. 저장 시점은 **`WIFI_OK` 수신 후뿐** — 틀린 비밀번호가 남지 않고, 같은 SSID 재성공 시 최신 값으로 덮어쓴다. AP 선택·수동 SSID 입력 시 저장값을 자동 채우고(사용자가 수정하면 안내 문구 제거), AP 목록에는 "비밀번호 저장됨" 배지가 뜬다. 사육장·카메라가 같은 `WifiProvisioningView`를 쓰므로 한쪽에서 성공한 비밀번호를 다른 쪽 페어링에서 바로 재사용한다. 기기 로컬 저장(계정 무관·동기화 없음), 저장 실패는 조용히 무시(편의 기능이지 페어링 요건이 아님).

## 7. 실기기 확인 포인트

- **카메라 `FB2_P4_CAM` 광고가 BLE 스캔에 잡히는지** 최우선 확인 (C6 펌웨어 이슈).
- 사육장 MTU 256 / 카메라 write 255바이트 한계 준수.
- `WIFI_OK` 후 기판이 실제로 서버에 telemetry/clip을 올리는지(사전 세팅된 토큰 유효성) 확인.
