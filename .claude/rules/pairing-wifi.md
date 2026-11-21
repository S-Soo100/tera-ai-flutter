---
paths:
  - "lib/features/my_cage/data/ble_*.dart"
  - "lib/features/my_cage/data/wifi_credentials_store.dart"
  - "lib/features/my_cage/data/device_wifi_name_store.dart"
  - "lib/features/my_cage/data/known_device_store.dart"
  - "lib/features/my_cage/data/device_add_*.dart"
  - "lib/features/my_cage/presentation/device_add_flow_*.dart"
  - "lib/features/my_cage/presentation/*_pairing_screen.dart"
  - "lib/features/my_cage/presentation/widgets/wifi_reconfigure_menu.dart"
  - "lib/features/my_cage/domain/device_add_flow.dart"
  - "lib/features/my_cage/domain/network_manage.dart"
---
# 기기 등록·Wi-Fi 규칙

프로토콜 SOT: `docs/ble-provisioning-protocol.md`(§0-A 시퀀스 표, §8 앱 구현 메모).

## 등록
- 공용 구현은 `DeviceAddFlowRoute`다. `camera_pairing_screen.dart`(`/crecam/cameras/pair`)는 그 흐름을 여는 진입점이다. 옛 래퍼 `WifiProvisioningView`는 쓰는 곳이 없어 2026-11-21에 삭제했다.
- `WIFI_OK`는 등록 완료가 아니다. `PAIR_OK`의 ID와 현재 계정 소유 행을 확인해야 완료다. ID 추측이나 목록 차이로 등록을 판정하지 않는다.
- 카메라에는 `UNPAIR`를 보내지 않는다. `NAME:`을 모르는 구 펌웨어면 JWT를 보내지 않는다. JWT 확인(`JWT_BEGIN`/`JWT_OK`)이 실패하거나 길이가 다르면 `CONNECT`를 보내지 않는다.
- 재등록하면 서버가 **새 행**을 만든다(이름·그룹·예약·기록이 끊긴다). 등록된 사육장 재연결은 경고를 거치고, "새 카메라로 등록"은 새 등록 성공 뒤 옛 행을 unlink한다. 예외: 다른 계정 등록으로 `superseded_at`이 찍힌 카메라는 새로 등록하면 서버가 같은 행을 돌려준다. 그 컬럼은 cameras에만 있다(devices 조회에 넣으면 400).

## Wi-Fi만 바꾸기
- 진입점은 `/devices/network`(`NetworkManageRequest`)다. `/devices/wifi`(`WifiChangeTarget`)는 옛 단일 대상 경로로, 실기기 확인 뒤 지운다. 새 진입점을 `/devices/wifi`로 만들지 않는다.
- `SSID/PASS/CONNECT`만 보내 등록을 유지한다. 판정은 대상 행의 `last_seen_at`. 사육장 쪽 스위치는 `kWifiChangeDeviceEnabled`.
- 대상임을 알아보지 못한 BLE 기기는 진행 전에 확인 모달을 거친다. 그 기기를 골랐는데 대상이 원래 Wi-Fi로 온라인이면 `unverified`다. 성공을 단정하지 않고 BLE 주소를 기억하지 않는다(잘못 기억하면 다음 등록이 Wi-Fi 변경으로 샌다).

## 저장
- Wi-Fi 비밀번호는 `WIFI_OK` 뒤, 사용자가 "기억하기"를 골랐을 때만 저장한다(`WifiCredentialsStore`, secure storage, 계정별 격리).
- 연결된 Wi-Fi 이름은 서버 `wifi_ssid`가 있으면 우선, 없으면 `DeviceWifiNameStore`, 모르면 `--`. 로그아웃 때 지운다.
