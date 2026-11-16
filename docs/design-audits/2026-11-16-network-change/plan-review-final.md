# 교차 검수 결과 (Codex + Claude) — 네트워크 변경 흐름 계획

- 대상: `docs/superpowers/plans/2026-11-16-network-change-flow.md` (r1, 커밋 `85c97227`)
- 검수자: Codex CLI(자유 관점) / Claude 새 컨텍스트 서브에이전트(4렌즈)
- 2026-11-16. 아래 판단은 메인이 코드·문서로 다시 확인한 뒤 내렸다.

## 요약
- Codex 12건, Claude 23건 / 공통 지적 8건. 반영 결과는 계획 r2.

## 🔴 2모델 공통 — 수정(전부 채택)
1. **Task 3~5 커밋 경계가 깨진다** — Task 3에서 지운 `WifiChangeTarget`·`matched`·`targetGone`을 라우터·기기 상세·라이브·화면·테스트가 Task 5까지 참조한다. → r2: 새 모드를 **옆에 추가**하고, 옛 모드 삭제는 마지막 task 단독 커밋.
2. **결과 화면은 한 대만 그린다** — `_wifiUpdated()`가 `state.results.values.first`만 그린다(`device_add_flow_screen.dart:1052`). 두 대를 바꾸면 두 번째 결과가 숨는다. → r2: 네트워크 변경은 기기별 결과 목록(사용자 결정 추가 — Figma에 결과 화면 없음).
3. **[새 기기로 등록]이 남으면 JWT 등록으로 샌다** — 결과 화면 `if (missing)`에 조건 없이 뜨고 `registerAsNew` → `_replacing` → 등록. → r2: 네트워크 변경 모드에선 UI에서 숨기고 컨트롤러도 거부.
4. **iOS 끝 4자리 오인 + trusted 무조건 true** — 근처 다른 계정 기기가 내 행으로 보일 수 있고, 그 기기를 고르면 잘못된 짝을 기억한다. → r2: 한 행에 맞는 BLE 후보가 둘 이상이면 모두 숨김, hw로만 알아본 기기는 trusted 아님.
5. **옛 Wi-Fi로 온라인인 기기는 성공을 입증 못 한다** — 이 흐름의 대표 진입(신호 약함)이 온라인 기기다. → r2: 기존 `wasOnline`·`unverified` 장치를 살린다(지우지 않음).
6. **비동기 매칭·자동 선택의 순서** — 늦은 응답이 네트워크 단계에서 기기를 자동 추가할 수 있다. → r2: 자동 선택은 `step == scan`일 때만, 원본 후보를 따로 두고 행 로드·스캔 갱신마다 다시 맞춘다.
7. **`_known`이 후보마다 Supabase를 부른다** — 행 목록은 이미 있다. → r2: 로컬 기억(`KnownDeviceStore.load`)만 읽고 행 목록과 맞춘다.
8. **카메라는 켜진 뒤 3분만 광고한다**(`docs/ble-provisioning-protocol.md:16`, 관훈님 회신) — 온라인 카메라는 목록에 안 나온다. → r2: 최대 리스크로 올리고, 실기기 확인을 Task 0으로 앞당기며, 전원 재연결 안내를 사용자 결정 1번으로.

## 🟡 단독 지적
| 출처 | 지적 | 판단 |
|---|---|---|
| Codex | 연결 직전 소유권 재검증 없음(검색 뒤 해제·대체) | **채택** — 보내기 직전 `owned(kind,id)`가 null이면 실패로 끝, 등록으로 넘어가지 않음 |
| Codex | 버전·CHANGELOG를 마지막 문서 커밋에 몰면 "같은 커밋" 규칙 위반 | **채택** — 첫 `lib` 커밋에서 0.179.0 올리고 이후 task는 같은 항목에 덧붙임 |
| Codex | 종류별 1대 제한은 확정 요구가 아님 | **채택** — 사용자 결정으로 명시 |
| Codex | 추천안이 결정처럼 본문에 섞임 | **채택** — 사용자 결정 항목 표시 |
| Claude | `errorKey`는 `copyWith`마다 지워진다 | **채택** — `ownedLoadFailed` 유지 플래그 |
| Claude | 새 provider를 `deviceAddFlowProvider.dependencies`에 넣어야 함(릴리스 root 기본값 사고) | **채택** — Must know + 라우트 통과 테스트 |
| Claude | `continueAdding`·`_home()` pop·`device_wifi_retry` 조건이 대상 모드 기준 | **채택** — 새 모드 동작 명시 |
| Claude | `firstWhere` orElse 없음 | **채택** — `firstWhereOrNull` |
| Claude | 기기 삭제 확인 문구가 [Wi-Fi 바꾸기]를 가리킴(`ko.json:300`, `device_detail_screen.dart:360`) | **채택** — Task 5 범위 |
| Claude | 헤더 메뉴 테스트 파일 없음, 마이크레 탭도 같은 헤더 | **채택** — 테스트 파일 명시, 마이크레 노출은 사용자 결정 |
| Claude | `device_wifi_name`은 ko.json 키가 아님 | **채택** — 목록 정정 |
| Claude | `ble-provisioning-protocol.md:19` 갱신 누락 | **채택** |
| Claude | 연결 상태(단발)와 막대(연속 판정) 불일치, 파싱은 `SysHealth` 재사용 | **채택** — 문구 결정에 적고 `SysHealth.fromCameraRow/fromDeviceRow` 재사용 |
| Claude | iOS 사육장 광고 이름 `terra-iot`에 끝자리가 없으면 hw 매칭 불가 | **채택** — Task 0 확인 항목 |
| Claude | `unverified` 장치가 죽은 코드가 됨 | 5번 공통 지적 반영으로 **해소**(살림) |
| Claude | `crecam_live_network_change` 키 중복 | **기각** — 메뉴 문구용 새 키 대신 기존 키 재사용으로 정리(중복 제거) |
| Claude | preferred 자동 체크는 불필요 | **보류** — 전원을 껐다 켜라는 안내(사용자 결정 1)를 따르면 그 카메라가 다시 광고해 쓸모가 생긴다. 결정 1이 "안내 없음"이면 뺀다 |

## 💡 직관 질문
- **삭제 가능:** preferred 자동 체크(위 보류 조건).
- **최대 리스크:** "근처 블루투스에 내 기기가 보인다"는 전제. 켜져 있는 카메라는 3분 뒤 광고를 멈추고, iOS에서 사육장은 `hw_id`로 못 알아볼 수 있다. 그러면 기기 상세 진입점만 사라지고 빈 목록이 된다.
- **먼저 프로토타입:** 지금 main의 `/devices/wifi` 흐름 + `[device-add] wifi-target` 로그로 실기기 확인(Task 0) — 온라인 카메라·사육장이 스캔에 잡히는지, 매칭이 맞는지, 사육장이 같은 행으로 붙는지.
