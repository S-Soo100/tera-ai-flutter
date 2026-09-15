# Figma 재설계 구현 결과

기준: 사용자 승인 기획과 후속 그룹명 규칙. 작업 브랜치 `codex/figma-redesign-20260915`, 작업 트리 `.worktrees/redesign-20260915`. 기존 `main`은 변경하지 않았다.

Flutter 화면·상태·저장소·라우트 구현을 완료했다. 새 DB 계약은 격리 PostgreSQL에서 검증한 **검토용 초안**이며 운영 적용은 하지 않았다. 따라서 그룹 변경·계정별 영상 숨김·개체 보존형 삭제·새 연결 이력은 서버 적용 전 실제 사용 완료 상태가 아니다. 하단의 외부 의존성과 실물 검증을 릴리스 조건으로 유지한다.

## 구현 범위와 검증 연결

| 기획 | 구현 | 주요 검증 |
|---|---|---|
| §1–2 공통 | 흰 화면/스크롤 상단, 그룹명 우선 ID 선택 헤더, 관리·계정 액션, 원본 배율·하단 내비게이션 | header/layout/theme 테스트, SVG 픽셀 및 원본 해시, Home 상태 캡처 |
| §3 Home | 사육장 없음/단독/카메라 연결, fan·fan2 시간 선택/타이머, LED 20–100%/10% 단위, 분무 3초·5초 잠금, LCD 20자 | control/fan2/LCD/ACK 회귀, Home fixture |
| §4 환경 | 일/주 수치·차트, 결측 선 끊김, 지표별 가중 평균, 독립 fan/fan2 로그, 실패 재시도 | env/control log/command history 테스트, 일·주 캡처 |
| §5 Camera | 라이브/3열 영상/기간 조회, 모든 영상 메모 편집·북마크 전용 메모 카드, 계정별 숨김과 재생 큐 갱신 | memo/visibility/feed/player 테스트, 세로·가로·320px 캡처 |
| §6 MyCre | 프로필/일간/주간, KST 자정·월요일, 연결 구간으로 활동 합집합, 정확/추정·결측 구분, 기존 리포트 진입 유지 | activity aggregation/repository/provider/history 테스트, MyCre 상태 캡처 |
| §7 연결/관리 | 사육장+카메라 선택, Wi-Fi, 부분 성공 유지, PAIR_OK 후 소유 행 확인, 그룹 추가/이동/제외/이름, ON 고정 표시 | BLE protocol/flow/registration/management 테스트, 연결 3단계·관리 캡처 |
| §8 개체 | 크레스티드 신규 등록, 기존 종·모프 보존, 사진·성별·날짜·체중·메모·그룹, 미저장 이탈, 실패 입력 유지 | form/catalog/save/repository 테스트, 원본 보존 SQL |
| §9 일정·보조 | 기존 일정 유지와 fan2 확장, 기존 deep link, 신규 정적 관리 경로, 연결 후 그룹을 유지한 개체 등록 | schedule/route tests, group preselect·dirty back 검증 |

메모는 Hive의 계정+영상 범위이며 서버 전송하지 않는다. 북마크의 기존 `clip_favorites` 동기화는 유지한다. 새 메모 색은 직전 새 색과 다르게 배정하고 편집 중에는 고정한다. 영상 숨김은 원본 활동/북마크/메모/R2를 삭제하지 않는다.

## 실제 사용자 흐름 확인

- 홈에서 그룹 이름을 선택하면 해당 사육장의 값과 연결 카메라가 바뀐다. 사육장만 있으면 라이브 공간이 생기지 않는다. 데이터가 없거나 오프라인이면 `--`와 비활성 제어로 보인다.
- 팬을 누르면 시간을 선택하고 시작해야 명령이 전송된다. 취소는 명령을 보내지 않는다. 성공 ACK가 없는 동작을 성공으로 표시하지 않는다.
- 영상에서 메모를 저장하면 북마크 목록에만 색 카드가 보인다. 북마크 해제는 메모를 지우지 않는다. 영상 삭제 확인 후 서버 숨김 성공 때만 목록과 재생 큐에서 빠진다.
- BLE 두 기기 중 하나가 성공하면 성공 상태를 유지한다. 재시도는 실패한 대상만 처리하고 등록 결과가 불확실하면 등록 조회로 확인한다. 기존 그룹과 연결할 때는 사용자가 선택하고 이동을 확인한다.
- 등록 완료에서 새 도마뱀 등록으로 이동하면 이번 그룹이 미리 선택된다. 저장 실패·이탈 취소에서 입력과 사진을 유지한다. 개체 삭제는 프로필과 소속을 숨기되 원본 행을 보존한다.
- MyCre는 관측·연결 근거가 있을 때만 수치를 만든다. 새 이력 계약이 없으면 안내와 재시도를 표시하며 기존 카메라 리포트는 계속 연다.

## Figma 대조와 렌더 자료

Talk to Figma 채널 `wvkqunn6`에서 읽기 전용으로 다시 측정했다. 기본 폭 393, 상태바 62, 헤더 369×44, 좌우 여백 12, 라이브 369×271, Home 수치 카드 약69px. 내비게이션은 위 여백12·아이콘24·간격4·라벨14.32·하단 기준26이며 실제 장치의 더 큰 safe inset은 보존한다.

관리 SVG는 viewBox 44 안에 도형이 들어 있으므로 **44로 표시**한다. 이를24로 축소해 작아지던 부분을 수정했다. 온습도 배지는 현재 Figma의 배경 #C00306/#192553와 흰 글리프를 함께 보존한다. Talk to Figma 플러그인이 SVG 옵션을 받아도 PNG로 고정 export하는 것을 소스에서 확인했으며, 기존 SVG의 배경 rect만 바꾼 runtime 사본을 현재 3배율 PNG와 픽셀 비교했다. [변환 원장](../../assets/figma/2026-09-15/supplemental/manifest.json)의 경로는 저장소 루트 기준으로 해석한다.

Camera 기간 버튼은 시각95×40/터치95×44, 첫 영상 y572, 개체 이름/종 칸은369×65로 실측했다. 라이브 확대17px·사진 편집24px는 부모의 tight constraints에 의해 확대되지 않게 가운데 배치했다. 320px 폭·글자1.7배·긴 이름/기간에서도 넘침이 없었다. 키보드 캡처는300px inset 시뮬레이션이며 실제 OS 키보드는 포함하지 않는다.

사용자 원본 SVG70+PNG4는 해시가 그대로다. 추가 배지2는 기존 원본을 덮어쓰지 않았다. 새 PNG4는 `ExactAssetImage(scale: 3)`로 사용한다. [에셋 역할·소비처](2026-09-15-redesign-asset-map.json)에 미사용 변형까지 보관했다.

캡처는 테스트 fixture로 실행한 실제 Flutter 렌더이며, 실제 계정·영상 스트림·실물 BLE 성공의 증거가 아니다. 상태바 시계/신호는 OS 영역이라 fixture 이미지에 넣지 않았다. 라이브/썸네일은 네트워크 없는 대역을 사용했다.

| 화면 | 캡처 |
|---|---|
| Home | [연결](2026-09-15-redesign-implementation/redesign-home-linked.png), [사육장 단독](2026-09-15-redesign-implementation/redesign-home-device.png), [빈 상태](2026-09-15-redesign-implementation/redesign-home-empty.png), [스크롤](2026-09-15-redesign-implementation/redesign-home-scrolled.png) |
| Camera | [메인](2026-09-15-redesign-implementation/redesign-camera-main.png), [스크롤](2026-09-15-redesign-implementation/redesign-camera-scrolled.png), [빈 상태](2026-09-15-redesign-implementation/redesign-camera-empty-isolated.png) |
| 개체 등록 | [첫 화면](2026-09-15-redesign-implementation/redesign-pet-first.png), [스크롤](2026-09-15-redesign-implementation/redesign-pet-scrolled.png), [키보드·긴 이름](2026-09-15-redesign-implementation/redesign-pet-keyboard-long-name.png) |
| 환경 | [일간](2026-09-15-redesign-implementation/widget-env-daily.png), [주간](2026-09-15-redesign-implementation/widget-env-weekly.png) |
| 플레이어 | [세로](2026-09-15-redesign-implementation/widget-player-portrait.png), [가로](2026-09-15-redesign-implementation/widget-player-landscape.png), [320px](2026-09-15-redesign-implementation/widget-player-portrait-narrow.png) |
| MyCre | [일간](2026-09-15-redesign-implementation/mycre-populated.png), [주간](2026-09-15-redesign-implementation/mycre-week.png), [빈 상태](2026-09-15-redesign-implementation/mycre-empty.png) |
| 메모 | [세로](2026-09-15-redesign-implementation/memo-portrait.png), [가로](2026-09-15-redesign-implementation/memo-landscape.png), [6색](2026-09-15-redesign-implementation/memo-six-colors.png) |
| 관리·연결 | [목록](2026-09-15-redesign-implementation/management-inventory.png), [그룹](2026-09-15-redesign-implementation/management-group-review.png), [검색](2026-09-15-redesign-implementation/pairing-scan.png), [Wi-Fi](2026-09-15-redesign-implementation/pairing-credentials.png), [완료](2026-09-15-redesign-implementation/pairing-results.png) |

## 서버 확인과 원본 보존 검증

- 실제 연결된 Supabase public schema를 읽기 전용으로 확인했다. 대상 ID는 UUID이며 `devices.device_id`/`cameras.camera_id`는 펌웨어 식별자 TEXT다. 개인 데이터 행·키·비밀값을 기록하지 않았다.
- `user_hidden_clips`, `pet_camera_assignments`, `redesign_*` RPC, `pets.deleted_at`은 운영에 아직 없다.
- 기존 pet 물리 삭제는 `media`/`pet_events` FK cascade를 일으킨다. 초안은 `deleted_at`+소속 해제+조회 RLS로 프로필을 숨기고 원본을 보존한다. 기존 기기/카메라/영상 DELETE는 재사용하지 않는다.
- 격리된 PostgreSQL 17 컨테이너에서 실제 대상 테이블의 column/FK 구조와 합성 2계정 fixture로 RPC·RLS·원본 보존·멱등 재시도를 실행하고 ROLLBACK했다. 운영 DDL은 실행하지 않았다.
- 재현: `tools/verify_redesign_sql.py`. 고정 이름의 로컬 격리 컨테이너만 사용하며 운영 URL을 받지 않는다. `supabase/drafts/` 파일은 모두 검토용 BEGIN/ROLLBACK이다.
- 공개 카탈로그만 읽어 크레스티드 DB17/로컬23 모프 차이를 대조했다. [등록 카탈로그 근거](2026-09-15-registration-catalog.md). 유전자 정의·원격 데이터는 수정하지 않았다.

## 운영 적용 및 실물 검증 대기

| 항목 | 담당/현재 상태 | 앱 동작·남은 조건 |
|---|---|---|
| 앱 전용 숨김 원장 | 앱 팀 직접 적용 가능, 초안·로컬 검증 완료 | 운영 RLS/table 적용 전 숨김 저장은 실패 안내 |
| 그룹/개체 RPC·배정 이력·보존형 삭제 | 앱 팀 초안 + 이관훈님 공통 write 합의 필요 | 기존 웹·서버 writer도 owner lock/history protocol 사용 필요. 기존 사용자 이력은 감사한 범위만 승계 |
| 이름 원자 할당/Unicode | 이관훈님 + 앱 팀 | 동시 등록 이름은 서버 원자 보장 필요. SQL 초안은 Hangul/ASCII 외 UAX29 검증 지원 전 명시 실패; 앱은 grapheme 10자 |
| 안전한 기기 등록 해제·재소유 | 이관훈님 | MQTT registry/token 폐기, 과거 영상 권한 보존 계약 대기. 기존 hard DELETE 금지, 새 unlink RPC 초안은 의도적으로 미지원 반환 |
| 활동 interval | petcam-lab 배포 완료 | owner-activity-v1 API 연동 완료. [수신 계약](../references/2026-09-15-petcam-activity-handoff.md). 서버 활동 배포와 앱 배정 이력 적용은 별개 |
| coverage·지표별 valid count | petcam-lab/이관훈님 | 관측 완료 여부 미확정이면 평균 `--`; 빈 영상 목록을 유효 관측0으로 추측하지 않음 |
| 하이라이트 공개 배치·timer push 보완 | petcam-lab/이관훈님 | 실제 배치/공개 시각 및 종료 의미 계약 대기. 촬영 시각을 공개 시각으로 대체하지 않음 |
| 실제 Android/iOS+ESP32 | 실물 QA | BLE 동시/부분 연결, 펌웨어 fan2/LED/mist, 절전·백그라운드 타이머, 카메라 재생/공유/사진 권한 E2E 미실행 |

Android 플랫폼의 흰 상단 픽셀 테스트와 시뮬레이션 렌더는 통과했지만, 물리 Android edge-to-edge 합성 검증을 대신하지 않는다. Figma 기준 폭 외에서는 버튼 크기와 safe area를 지키며 간격을 줄인다. 전체 전원 ON 고정과 제어 기록의 근사치 표시는 사용자 승인 사양이다.

## 최종 실행 결과

- 전체 회귀: `flutter test --no-pub --reporter expanded` 848개 통과, opt-in 캡처6개 제외. 마지막 간격·SVG 제약 보정 후 전체 재실행도 동일하게 통과했다. 별도 Camera/Pet opt-in4개와 관련 집중28개, 빈 Camera 격리 캡처1개도 통과했다. 빈 화면 헤더의 실제 어두운 픽셀을 별도 검사해 SVG 로드 누락을 구분했다.
- 분석: `flutter analyze --no-pub --no-fatal-infos` 오류0, 경고0, 기존 info6.
- 에셋: 사용자 원본74개 SHA256 유지, SVG70 및 PNG4 로드/배율 통과. 추가 온습도 SVG2는 현재 Figma 3배율 PNG와 평균 채널 차이2.5% 미만 기준 통과.
- 격리 SQL: 그룹 재시도 중복 없음, 계정 간 hide/rename 거부, 원본 clip/favorite/media/event 보존, 삭제 프로필 SELECT 제외·연결 이력 종료, 모든 변경 ROLLBACK. 검증 컨테이너 종료.
- 최종 `0.107.1+212` Android debug APK 빌드 통과(12.2초), iOS simulator debug app 빌드 통과(13.1초). 산출물은 `build/app/outputs/flutter-apk/app-debug.apk`, `build/ios/iphonesimulator/Runner.app`. [검증 원장·해시](2026-09-15-redesign-implementation/verification.json).
- iPhone 17 / iOS 26.4 시뮬레이터에 최종 앱을 설치·실행해 [로그인 화면](2026-09-15-redesign-implementation/ios-simulator-login.png) 정상 표시를 확인했다. 실제 계정 로그인과 BLE 조작은 하지 않았다.
- 실제 폰·펌웨어 E2E는 미실행. 위 테스트를 실물 검증 완료라고 해석하지 않는다.

## 저장 단위

- `4765561` / `0.106.0+210`: 도메인·계정별 저장소·검토용 SQL과 데이터 검증.
- `fb964d0` / `0.107.0+211`: 승인 화면·상태 흐름·에셋 소비처·UI 회귀.
- `65a8788` / `0.107.1+212`: 라우터 연결을 독립 저장, 정적 경로와 기존 deep link 보존.
- 보고서·스크린샷·카탈로그/외부 계약 기록은 별도 문서/검증 커밋으로 저장한다. 원격 push·운영 DB 적용은 하지 않았다.
