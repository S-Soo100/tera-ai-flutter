# Final Design 앱 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Standard 작업은 메인이 순차 실행한다. 신규 화면·계약이 포함된 X 작업은 프로젝트 CAOF의 Critical 절차를 따른다.

**Goal:** 승인된 요청 1~8을 누락 없이 구현하고, 실제 앱과 Final Design의 차이를 화면별 검증 증거로 닫는다.

**Architecture:** 홈·온습도, 카메라 목록, 플레이어·하이라이트를 각각 검증 가능한 작업으로 분리한다. 안정된 계정/기기 식별자를 조회 경계로 사용하고, 파일 캐시·읽음·북마크 작업은 화면 수명과 분리한다. 서버가 보장하지 않는 평균·도착시각·기기 명령은 클라이언트에서 만들어 내지 않는다.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase, Hive, http, flutter_svg, video_player, flutter_webrtc, easy_localization.

**Spec:** [승인된 설계](2026-09-13-app-design-review.md), [Final Design 감사](../design-audits/2026-09-13-final-design.md), [추출 SVG 30개](../design-audits/2026-09-13-svg/README.md).

## Global Constraints

- 현재 단계는 구현 계획 작성이다. 체크박스는 앱 구현 완료를 뜻하지 않는다. 기준 HEAD는 `5b7e1ec`, 앱 버전은 `0.97.0+187`이다.
- 사용자 확정: **해당 하이라이트 재생 시작 시** 읽음 처리. 진입·초기화·시크만으로 읽음 처리하지 않는다.
- 이번 사용자 요구가 과거의 가로 강제, 회전 금지, 최근 하루 자동 선택, 팬 즉시 시작 정책보다 우선한다.
- 상태 관리 Riverpod, 데이터 접근 Repository, 색상 GlassPalette, 문구 ko.json, 로딩 shimmer. 새 setState·CircularProgressIndicator를 추가하지 않는다.
- 날짜: 환경=달력 자정, 밤 활동=현행 22~06시, 활동 귀속=07시. 서버 하이라이트 dayKey의 20시 경계는 별도 계약 문제다.
- UI 구현 전 승인 설계 §2의 `[화면] → [조작] → [반응] → [감정]`을 해당 작업과 대조한다. X 작업은 별도 체험 설계를 먼저 완성한다.
- 문서·원본 SVG는 보존하고 실행용 파생 SVG를 `assets/icons/`에 둔다. Figma 접근은 Talk to Figma MCP만 사용한다.
- 기존 패키지를 우선 사용한다. 프로젝트 최신 규칙상 신규 패키지는 사전 승인 대상이 아니며, 도입하면 이유와 버전을 기록한다.
- 기능별 순차 수정. 각 커밋 전에 관련 테스트와 `flutter analyze --no-pub` 에러 0 확인. lib 변경 커밋은 당시 버전에서 의미 버전·build 번호를 올린다. 자동 push하지 않는다.
- 구조 교체는 독립 커밋으로 되돌릴 수 있게 한다. 수정/검증 실패 루프는 최대 3회. 코드 리뷰는 프로젝트의 사용자 실행 `/code-review` 규칙을 따른다.

## 실행 순서와 담당 파일

| 순서 | 작업 | 결과 | 상세 계획 |
|---|---|---|---|
| 0 | G0 계약 확인 착수 | 평균 유효 개수·하이라이트 공개 배치의 사실/부족분 명시 | 이 문서 |
| 1 | A1 공통 디자인 | SVG 매핑, Asset_v2 역할별 색상, 내비게이션 | [홈·온습도](2026-09-14-home-env-implementation.md) |
| 2 | H1~H3 | 대표값·주간 최저·팬 시간 선택·일정 문구 | [홈·온습도](2026-09-14-home-env-implementation.md) |
| 3 | C0~C3 | 스크롤 원인 재현/수정→전체 기간→무한 목록→캐시 | [카메라 목록](2026-09-14-camera-feed-implementation.md) |
| 4 | P1~P2 | 세로 기본/수동 가로, Figma 조작계, 조용한 북마크 | [플레이어·하이라이트](2026-09-14-player-highlights-implementation.md) |
| 5 | P3 | 공개된 밤 묶음의 도착 카드와 실제 재생 읽음 | [플레이어·하이라이트](2026-09-14-player-highlights-implementation.md) |
| 6 | X1~X2 | MyCre 활동 화면, 기기 연결 v3·그룹 관리의 계약/상세 설계 후 구현 | 이 문서 |
| 7 | V1 | 기능 회귀·실기기·Figma 화면 비교 및 차이 보고 | 이 문서 |

G0는 첫 작업으로 확인하되, 계약이 부족하면 H1의 과거 평균 연결과 P3의 실제 API 연결만 대기한다. 주간 차트·팬·스크롤·캐시·플레이어·북마크는 진행할 수 있다. C0 진단을 끝내기 전에 스크롤 원인을 확정해서 보고하지 않는다.

권장값은 승인 설계의 기본안으로 실행한다: 페이지 60개, 캐시 200MB, 팬 10분/30분/1시간/2시간 및 기존 계속 켜기 유지, 선택 후 시작, X는 카드 숨기기, 동률 최고/최저 전체 표시. 불필요한 재승인을 받지 않는다.

## 요청별 추적

| 원 요청 | 구현 작업 | 합격 기준 |
|---|---|---|
| 1 오늘/과거 대표값 | G0, H1 | 오늘 최신값, 과거 정확한 평균, 데이터 없음 구별 |
| 2 주간 최저 연회색 | H2 | 동률·빈 날짜 포함 최고/일반/최저 구별 |
| 3-1 스크롤 튐 | C0, C2 | 중간 위치에서 상태 갱신·추가 로딩 시 offset 유지 |
| 3-2 연결 배지 | C2 | 상단 왼쪽 배지만 제거, 실제 오류/재연결 UX 유지 |
| 3-3 업데이트 날짜 | C2, P3 | 업데이트 오늘/어제/N일 전, 하이라이트는 publishedAt |
| 3-4 전체 기간/무한 | C1, C2 | 200개 초과·날짜/시간대 경계·동일 시각 누락 없음 |
| 3-5 썸네일 캐시 | C3 | 캐시 히트 presign 0회, 오프라인 재방문 표시 |
| 3-6 기간 라벨 | C1, C2 | 최초 기간 설정, 적용만 변경, 취소 유지, 해제 복원 |
| 4-1 도착 카드 | G0, P3 | 전날 밤 ready 묶음, 실제 재생 전 미읽음 |
| 4-2 SVG | A1, P1, P3 | 실제 노드와 매핑한 SVG로 교체 |
| 5 전체화면 | P1 | 세로 진입→버튼으로 가로, 재생/세션 유지 |
| 6 북마크 무토스트 | P2 | 즉시 아이콘 반영, 마지막 의도 반영, 실패 복구 |
| 7 팬·일정 | H3 | 시작 전 명령 0건, 시작 연타 1건, 일정 라벨 |
| 8 모든 디자인 차이 | A1, 각 화면 작업, X1, X2, V1 | 감사 목록 각 항목에 적용/계약대기/비대상 이유·증거 기록 |

## G0: 서버 계약을 실행 가능한 입력으로 확정

**Files:** 생성 `docs/plans/2026-09-14-data-contract-check.md`. 읽기 `docs/supabase-schema.md`, `docs/supabase-setup.md`, `~/Downloads/APP_INTEGRATION.md`, `lib/features/my_cage/data/{supabase_module_control_repository,highlight_repository}.dart`, `lib/features/my_cage/domain/{telemetry_bucket,nightly_highlight}.dart`.

**산출 계약:** H1은 지표별 `mean + validCount` 또는 `sum + validCount`; P3는 영속 배치 ID·촬영 구간·공개시각·ready·소속 클립 목록을 소비한다. 아래는 필요한 필드이며 기존 서버가 이미 지원한다는 뜻이 아니다.

- [ ] 집계 SQL/서버 문서에서 `sample_count`와 각 평균의 필터 조건을 대조한다. 온도 2개·습도 1개만 유효한 raw fixture로 반환 count를 검증한다. 공통 count가 지표별 count와 다르면 재사용하지 않는다.
- [ ] 확인 결과에 근거 파일/SQL, 실제 응답 fixture, 유효값 규칙, 시간대, 권한 범위를 기록한다. 부족하면 지표별 유효 count/sum 제공을 변경 요청 사항으로 작성한다. 서버 저장소를 식별하지 못했다면 파일 경로·API를 추측하지 않는다.
- [ ] 하이라이트의 `batchId, cameraId, captureStart, captureEnd, publishedAt, status, clips` 제공 여부를 확인한다. 22~06시 수집/20시 dayKey/07시 활동 귀속을 표로 분리하고 공개 완료 기준·재선정 시 ID 안정성·빈 밤·읽음 다중 기기 동기화 범위를 확정한다.
- [ ] 부족한 계약의 요청/응답 예시와 수락 조건을 같은 문서에 작성한다. 외부 전송은 하지 않는다. 앱 로컬 읽음 저장은 구현 가능하지만 publishedAt을 startedAt/현재시각으로 대체하지 않는다.
- [ ] 결과를 H1/P3의 fixture로 연결하고 문서만 독립 커밋한다: `docs: define telemetry and highlight contract requirements`.

## X1: MyCre 활동 화면 실행 패키지

**Files:** 생성 `docs/plans/2026-09-14-mycre-activity-design.md`; 조사 `lib/features/my_pets/presentation/my_pets_screen.dart`, `lib/features/my_cage/presentation/highlights_controller.dart`, `lib/features/my_cage/data/motion_clip_repository.dart`, `lib/features/home/presentation/home_set_providers.dart`. Figma `945:4384`, `945:4596`, `994:13348`.

**범위:** 요청 8에 포함하되 기존 개체 CRUD·리포트를 임의로 삭제하지 않는다. 이 작업의 첫 산출물은 신규 화면을 실제로 구현할 수 있는 독립 설계/계획이다. 데이터 계약이 미확정인 상태에서 아래를 이미 상세 구현 완료로 표시하지 않는다.

- [ ] 세 Figma 프레임의 개체 선택·일간/주간 전환·빈 상태를 노드/치수/텍스트별로 추출하고 현재 화면과 표로 대조한다.
- [ ] `[화면] 개체 카드 → [조작] 날짜/일주일 전환 → [반응] 동일 개체의 활동 집계/차트 변경 → [감정] 활동 변화를 이해` 흐름에 개체 없음·카메라 없음·수집중·데이터 없음·오류·자정/07시 경과를 덧붙인다.
- [ ] `motionSeconds`와 시간별 집계가 사용하는 effective activity 정의를 확인하고 일간/주간 합계가 같은 입력에서 일치하는 fixture를 만든다. raw duration 합계로 몰래 대체하지 않는다. 집계 귀속·0과 미수집 구별·API 조회 상한을 설계에 명시한다.
- [ ] 그 결과로 화면/Provider/Repository/라우트/테스트 파일을 정확히 나눈 구현 계획을 설계 문서에 작성한다. 기존 CRUD·개체 선택 진입 경로와 보존할 기능을 명시한다.
- [ ] 프로젝트 CAOF Critical 기준으로 구체화된 신규 동작만 확인받고 flutter-dev에 그 작업의 파일 소유권을 지정한다. 앞서 승인된 요청 1~7은 재승인 대상이 아니다. 구현 후 개체 전환 시 오래된 응답 미노출·일/주 합계·화면 비교를 검증한다.

## X2: 기기 연결 v3·그룹 관리 실행 패키지

**Files:** 생성 `docs/plans/2026-09-14-device-v3-design.md`; 조사 `lib/features/my_cage/presentation/{camera_pairing_screen,device_pairing_screen,enclosure_settings_screen}.dart`, `lib/features/my_cage/presentation/widgets/wifi_provisioning_view.dart`, `lib/features/my_cage/data/wifi_credentials_store.dart`, `lib/features/home/data/enclosure_set_repository.dart`, `lib/features/home/domain/enclosure_set.dart`, `lib/core/router/app_router.dart`, `docs/ble-provisioning-protocol.md`. Figma `971:1590` 내 활성 v3 화면.

- [ ] 통합 검색→1/2개 선택→네트워크→비밀번호→연결중→결과→함께/따로→그룹관리의 화면/상태 전이를 도식화한다. 각 전이에 취소·다시 시도·부분 성공·백그라운드 전환을 포함한다.
- [ ] 그룹은 베타 기준 사육장/카메라/개체 각 1개, 이름 10자·중복 검사, 기존 소속 교체 확인을 기준안으로 구체화한다. 글자 수는 사용자 표시 문자 기준, 중복 범위와 서버 원자적 검증은 계약에 명시한다.
- [ ] 현행 BLE가 Wi-Fi 설정만 수행하고 owner/등록은 사전 세팅임을 계약에 명시한다. 다기기는 장치별 세션을 순차 진행하고 장치별 성공/실패를 유지한다. 성공하지 않은 전체 그룹을 완료로 표시하지 않는다. 비밀번호 저장은 WIFI_OK 후 기존 secure storage 경로를 재사용한다.
- [ ] 전원·그룹 원자 갱신·등록·삭제·LCD 이름 동기화의 실제 REST/펌웨어 지원 여부를 확인한다. 네트워크 online 값을 전원 on으로 치환하지 않는다. 미지원 조작은 가능한 API처럼 문서화하지 않는다.
- [ ] 확정된 계약을 기준으로 새 화면/라우트·상태기계·저장소·테스트별 구현 계획을 작성하고 CAOF Critical 절차로 진행한다. 실패 장치만 재시도·다른 계정 그룹 접근 차단·두 번째 기기 실패의 부분 성공 유지·그룹 교체 원자성을 수락 기준으로 삼는다.

## V1: 통합 검증·화면별 결과 보고

**Files:** 생성 `docs/design-audits/2026-09-14-implementation-results.md`, 비교 캡처는 `docs/design-audits/2026-09-14-implementation/`; 갱신 `CLAUDE.md`, `docs/prd-vivnanaut-app.md`, `docs/prd-implementation-gap.md`의 이번 변경과 충돌하는 항목만 수정.

- [ ] 각 세부 계획 테스트를 실행하고 마지막 변경 후 `flutter analyze --no-pub`, `flutter test`, `flutter build apk --debug`를 실행한다. iOS 재생·회전·BLE는 실제 iOS 실행 검증도 별도로 기록한다.
- [ ] 393pt 기준 및 작은 화면/큰 글자에서 홈·환경 일/주간·카메라 다일 목록·하이라이트·북마크·플레이어 세로/가로를 캡처해 감사 프레임과 비교한다. 치수·간격·폰트·색·SVG·safe area·컨트롤 상태를 항목별 판정한다.
- [ ] 실제 카메라에서 중간 스크롤 중 상태 이벤트/탭 복귀/추가 로딩, 라이브 회전 왕복, 캐시 재시작/오프라인, 팬 시작 전 무명령/시작 ACK를 확인한다. 테스트 대역 통과를 실장치 통과로 보고하지 않는다.
- [ ] 감사의 활성 150개 프레임/컴포넌트 목록을 화면군별 추적한다. 150개를 각각 독립 앱 화면으로 세지 않는다. v1/v2·ASIS·Refer·폐기 시안은 적용 제외 근거를 기록한다. X1/X2 계약대기 항목이 있으면 요청 8 전체 완료로 보고하지 않는다.
- [ ] 변경 파일·커밋·수행 테스트·실측 증거·남은 계약을 결과 문서에 기록한다. lib 포함 각 작업의 버전 증가를 확인하고 마지막 검증 결과와 함께 커밋한다.

## 계획서 작성 검증

이 문서는 구현 전 계획이다. 앱 코드 수정, 새 서버 계약 구현, 실기기 재현 완료를 주장하지 않는다. 세부 테스트의 신규 파일과 인터페이스는 앞으로 생성할 대상이다. 현재 존재하는 파일과 새로 만들 파일을 각 작업에서 구분한다.

- 요청 1~8의 추적표와 승인된 읽음 조건을 대조했다. 계획 4개의 로컬 문서 링크 누락은 0건이다.
- 2026-09-14 `flutter analyze --no-pub`: error 0, warning 0, 기존 info 7건으로 종료코드 1. 완전 무진단 통과로 보고하지 않는다.
- 문서만 변경했으므로 앱 기능 테스트·빌드·실장치 검증은 이번 계획 작성에서 실행하지 않았다. 각 작업과 V1에 적힌 명령은 구현 단계의 수락 기준이다.
