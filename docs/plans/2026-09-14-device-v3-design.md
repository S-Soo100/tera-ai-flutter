# 기기 연결 v3·그룹 관리 실행 패키지

상태: Figma 971:1590의 활성 v3 화면/메모와 기존 BLE·그룹 코드를 대조했다. 서버 등록/그룹 원자 갱신/전원 계약이 부족하여 신규 통합 플로우를 기존 연결 UI에 덮어쓰지 않았다.

## 체험 전이

`검색 → 종류별 최대 1개 선택 → 네트워크 → 비밀번호 → 장치별 순차 연결 → 결과 → 함께/따로 → 그룹/개체 배정`.

- [화면] 사육장·카메라 검색 결과 → [조작] 각 1개 선택 → [반응] ‘기기 2개 추가’ 활성 → [감정] 연결 대상이 명확함.
- [화면] 공통 Wi-Fi 입력 → [조작] 연결 → [반응] 각 장치 진행/성공/실패 별도 표시 → [감정] 무엇이 완료됐는지 이해.
- [화면] 첫 장치 성공·두 번째 실패 → [조작] 실패 항목 재시도 → [반응] 성공 장치 결과 유지 → [감정] 처음부터 반복하지 않음.
- [화면] 연결 진행 → [조작] 닫기 → [반응] 중단/계속 확인. 중단은 미완료 BLE 세션만 정리하고 성공 등록은 취소된 것처럼 표시하지 않음.
- [화면] 사육장+카메라 성공 → [조작] 함께 사용 → [반응] 실제 저장 완료 후 그룹 생성 → [감정] 묶음의 의미가 명확함.
- [화면] 그룹 편집 → [조작] 이미 다른 그룹에 속한 항목 선택 → [반응] 기존 소속 표시·교체 확인 후 원자 갱신 → [감정] 이전 그룹의 변화 이해.

백그라운드 중 BLE 세션 종료 시 재개 화면은 장치별 결과를 유지한다. 비밀번호는 WIFI_OK 이후 기존 secure storage 경로로 저장한다. 실패한 입력을 기억하지 않는다.

## 확정 가능한 기준

최신 v3 메모의 베타 한도: 사육장/카메라/개체 각 1개. 이름 10개 사용자 표시 문자(`characters`), 같은 계정 내 trim 후 같은 이름 중복 방지. 소속 항목도 선택 목록에 표시하고 교체 확인. 빈 그룹, 미배정, 삭제와 그룹 제외는 별도 상태. 기기 종류 정렬은 사육장→카메라→개체.

기존 `enclosure_set_repository.dart`는 enclosures/devices/cameras/pets 네 소스를 읽어 첫 항목으로 조립한다. 이 읽기 모델은 여러 저장소를 한 트랜잭션으로 쓰는 API가 아니다. 기존 BLE는 Wi-Fi 설정만 수행하며 등록·owner는 사전 세팅이라는 `docs/ble-provisioning-protocol.md` 계약을 유지한다.

## 서버에 필요한 계약

| 동작 | 현재 근거 | 필요한 보장 |
|---|---|---|
| 새 기기 등록/claim | Wi-Fi provisioning, owner 사전 세팅 | 계정에 등록하는 idempotent API, BLE 식별자↔서버 UUID 매핑 |
| 그룹 생성·소속 교체 | 각 저장소의 개별 배정 | owner 범위 원자 트랜잭션·한도·이름 중복·동시 편집 충돌 |
| 이름 변경 | 개별 모델 이름 | DB 이름과 LCD 이름 동기화 책임/재시도 |
| 기기 전원 켬/끔 | online/telemetry만 확인 | 실제 power 명령/상태/ACK. online을 전원으로 치환 금지 |
| 그룹 삭제/제외 | 별도 DB 관계 | 삭제 vs 소속 해제, 기기·영상 보존 범위 명시 |

## 구현 파일과 검증 순서

1. `my_cage/domain/device_setup_state.dart`: scanning/selected/network/provisioning/result, 장치별 결과 맵. 단일 전체 성공 bool 금지.
2. `my_cage/presentation/device_setup_controller.dart`: 기존 BLE repository를 장치별 순차 호출, 취소·timeout·부분 성공·복귀 처리.
3. `my_cage/presentation/device_setup_screen.dart`: Figma v3 단계 UI. 기존 `wifi_provisioning_view.dart`를 공통 단계 위젯으로 재사용할 수 있는 범위만 추출.
4. `home/data/enclosure_group_repository.dart`: 확정 REST/transaction adapter. UI에서 개별 기기 UPDATE를 여러 번 호출하지 않는다.
5. `home/presentation/group_management_screen.dart`, `group_editor_sheet.dart`, `group_member_picker.dart`: 베타 한도, 10자/중복, 소속 교체, 완료 전 저장중 상태.
6. `core/router/app_router.dart`: 통합 추가/관리 라우트 등록, 기존 단일 장치 pairing 딥링크는 유지/리다이렉트.
7. 테스트: 두 번째 기기 실패 후 첫 번째 결과 유지·실패만 재시도·취소 성공분 보존·WIFI_OK 전 비밀번호 미저장·다른 계정 응답 무시·그룹 교체 충돌 시 원상태 유지·사용자 표시문자 한도.

신규 다기기 플로우와 그룹 쓰기는 CAOF Critical로 계약 확정 뒤 flutter-dev에 파일 소유권을 할당한다. 기존 종류별 페어링/그룹 배정은 이번 빌드에서 계속 사용할 수 있다.
