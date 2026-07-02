# 사육장·카메라 BLE Wi-Fi 프로비저닝 프로토콜

> **단일 진실 소스.** 사육장(`terra-iot`)·카메라(`FB2_P4_CAM`) 기판을 Wi-Fi에 연결하는 BLE 규격과 앱 구현 계약.
> 원본 스펙: `~/Desktop/사육장 ble_protocol.md`, `~/Desktop/camera BLE_WIFI_PROVISIONING.md`
> 관련 문서: terra-server IoT 계약 `~/Downloads/APP_INTEGRATION.md`, DB 스키마 `docs/supabase-schema.md`
> 최종 갱신: 2026-07-02

## 0. 페어링 아키텍처 결정 (가장 중요)

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

### 기기 → 앱 (TX notify)

```
[스캔]  SCANNING → SCAN:<count> → AP:<no>,<ssid>,<rssi>,<channel> (개수만큼 반복) → SCAN_END
        실패: SCAN_FAIL / NO_AP_FOUND(사육장)
[설정]  SSID_OK / PASS_OK
[연결]  CONNECTING → WIFI_OK | WIFI_FAIL
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

**앱 흐름:** BLE 스캔(이름 필터) → 기기 선택 → BLE 연결 → `SCAN` → AP 목록 표시 → 선택 + 비번 입력 → `SSID`/`PASS`/`CONNECT` → `WIFI_OK` → 기기 목록 provider invalidate(사전 등록된 기기가 뜸).

## 7. 실기기 확인 포인트

- **카메라 `FB2_P4_CAM` 광고가 BLE 스캔에 잡히는지** 최우선 확인 (C6 펌웨어 이슈).
- 사육장 MTU 256 / 카메라 write 255바이트 한계 준수.
- `WIFI_OK` 후 기판이 실제로 서버에 telemetry/clip을 올리는지(사전 세팅된 토큰 유효성) 확인.
