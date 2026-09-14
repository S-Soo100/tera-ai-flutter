# Final Design 구현·1차 보정 결과

작업 공간 `.worktrees/final-design`, 브랜치 `codex/final-design-implementation`, 버전 `0.100.1+193`.
사용자 승인 범위: 구현 → 시뮬레이터 비교 → 1차 수정. 아래는 수행한 범위와 아직 수행하지 못한 범위를 구별한 기록이다.

## 요청별 결과

| 요청 | 구현/검증 | 남은 사항 |
|---|---|---|
| 1 오늘 실시간/과거 평균 | 오늘은 센서 정상·기기 일치·12초 최신성을 만족해야 표시. 마지막 차트값 fallback 제거. 지표별 valid count 가중 평균 구현·fixture 검증 | 실제 DB에 `t_a_valid_count` 없음(42703 확인). 과거 값은 해당 지표 count 미지원이면 `--`/평균 데이터 준비 중. 서버 평균 연동 미완 |
| 2 주간 최저 | 최고 강조/일반 회색/최저 연회색, 동률·빈 날짜·단일 유효일 분기. 헤더 색과 그래프 색 분리 | 9/7~9/13 실제 주간 데이터 최고/최저 색 확인 |
| 3-1 스크롤 튐 | feed query를 계정/카메라 ID/명시 기간으로 고정. 기존 items 유지, lazy sliver·live keepAlive. 300개 중간 위치에서 카메라 갱신 후 offset 1px 이내, feed/라이브 생성 횟수 유지 | 실제 카메라 Realtime/복귀 실측 |
| 3-2 연결 배지 | 라이브 상단 좌측 연결됨/연결끊김 배지 제거 | 실제 연결 실패 화면은 유지 |
| 3-3 업데이트 | 오늘/어제/N일 전, 시간 단위 제거. 북마크는 저장시각 사용 | 하이라이트 공개시각 계약 미지원이면 업데이트 정보 없음 |
| 3-4 전체 기간 | 기본 전체 기간, 60개 복합 `(started_at,id)` 커서/중복 제거/끝 판정/추가 로딩 재시도 | 로그인된 앱에서 날짜 경계를 넘어 연속 로딩 확인 |
| 3-5 썸네일 | owner/camera/clip/version 키, 디스크 hit에서 presign 0회, 200MB LRU, 중복 다운로드 합침, 원자 rename, 중단 파일 정리, 계정 전환 시 정리 | 실제 이미지/오프라인 재방문 실측 |
| 3-6 기간 설정 | 최초 기간 설정, 적용 시만 날짜 변경, 취소 유지, 전체 기간 해제 | 자동 테스트 통과 |
| 4-1 도착/읽음 | optional 공개 배치 adapter, 실제 playhead 진전 시 읽음, 초기화/버퍼링/seek 제외, owner/camera/batch별 Hive 영속. X 숨김과 읽음 분리 | 현행 featured API에 불변 공개 배치/시각 없음. 실제 도착 카드 연동 미완 |
| 4-2 SVG | 원본 33개 확보, 런타임 매핑/alpha mask 호환 보정. 팬·분무·냉각·LED on/off 원본 적용 | 전체 150개 프레임의 픽셀 검수 완료를 의미하지 않음 |
| 5 전체화면 | 클립·라이브 세로 기본, 명시 회전, 세로 복원. 컨트롤·썸네일 스트립·시간대 나머지 페이지 조회. 회전 왕복 controller 생성 1회 검증 | iOS 실제 클립/라이브 세로 진입·수동 가로·세로 복귀 확인 |
| 6 북마크 | 진행/성공/해제 토스트 제거, 즉시 아이콘 변경, 직렬 최종 의도, 백그라운드 유지, transient 재시도, 실패 복구. 오프라인 삭제 tombstone으로 재등장 방지 | 실제 다운로드/갤러리·네트워크 검증 |
| 7 홈 | 팬 시간 선택→시작, 취소 무명령·중복 제출 방지, 직전 선택 제안, 켜짐→끄기 유지. 일정 라벨 | 실제 팬 ACK/자동 OFF 실기기 검증 |
| 8 추가 변경 | 팔레트/헤더/아이콘/그리드 모서리 1차 보정, MyCre와 연결 v3의 구체적 실행 패키지 작성 | MyCre·연결 v3 신규 플로우는 데이터/원자 갱신 계약 대기 |

## 검증 증거

- 기준 전체 테스트: 611개 통과.
- 이번 전체 회귀: **644개 통과**, opt-in 캡처 1개 skip. 로그 `/tmp/final-design-tests-verified.log`.
- 별도 진단 캡처 테스트 3개 통과: 환경 일간/주간·팬 시트, 393pt→852×393→320×568 클립 회전, 라이브 회전 왕복. `/tmp/final-design-capture-final.log`.
- 계정 전환 중 북마크 다운로드, 다른 계정 삭제 차단, 오프라인 삭제 재등장 방지, 캐시 재시작·동시 요청·계정 정리 경합을 테스트했다.
- 241개 동일 타임스탬프 fixture에서 60개 커서 페이지를 끝까지 순회해 누락/중복을 검증했다.
- 오늘 최신성/0 센티넬/다른 기기/센서 실패와 온습도별 다른 valid count 및 미지원 처리 3개 테스트 추가.
- 정적 분석: **error 0 / warning 0 / 기존 info 7**. info 때문에 종료코드는 1이다. 로그 `/tmp/final-design-analyze-verified.log`.
- iOS simulator debug 빌드 성공(최종 소스, 14.1초), `build/ios/iphonesimulator/Runner.app`. Android 최종 debug 빌드 로그 `/tmp/final-design-apk-verified.log`.
- `git diff --check` 통과. 실제 카메라·팬 장치 검증은 대역 테스트와 구분한다.
- 시뮬레이터 추가 보정 후 전체 회귀 **644개 통과**, opt-in 캡처 1개 skip: `/tmp/final-design-simulator-tests-final.log`.
- 추가 보정 후 정적 분석은 error 0 / warning 0 / 기존 info 7: `/tmp/final-design-simulator-analyze-final.log`.
- 추가 보정 후 iOS simulator debug 빌드 성공(19.6초): `/tmp/final-design-simulator-build-final.log`.

## 위젯 캡처 비교와 1차 수정

아래는 **실제 앱 위젯 + 주입한 테스트 데이터**를 Flutter test 렌더러로 캡처한 것이다. 시뮬레이터 스크린샷이 아니다. 회색 영상/썸네일은 영상 없는 대역이며 카메라 화질·지연을 검증하지 않는다. 시스템 상태바는 포함하지 않는다.

- [온습도 일간](2026-09-14-implementation/widget-env-daily.png), [주간](2026-09-14-implementation/widget-env-weekly.png)
- [세로 플레이어](2026-09-14-implementation/widget-player-portrait.png), [가로 플레이어](2026-09-14-implementation/widget-player-landscape.png)
- [팬 시간 선택](2026-09-14-implementation/widget-fan-duration.png)

Figma `941:1834`, `941:1928`, `945:3245`, `945:3428`, `945:4043`와 대조했다. 수정한 차이:

1. SVG alpha mask의 회색 mask fill이 런타임에서 옅게 합성되는 문제 → 실행 파생본의 불투명 mask만 흰색 정규화. 원본 export/path/viewBox 보존.
2. 24pt 화살표가 44pt 터치 컨테이너를 채워 커지는 문제 → Center로 glyph 치수 고정.
3. 원본 36pt 조작 SVG를 24pt로 축소해 작아진 문제 → 36pt glyph/44pt 터치면, 간격 조정.
4. 주간 대표값/막대색 혼용 → 대표값 `C00306/192553`, 막대 `D61619/2E408C` 분리.
5. lazy 그리드가 매 행을 따로 둥글게 자르는 문제 → 전체 시간대 row offset/total 기준 모서리 계산.
6. 긴 기간 라벨/처음부터 버튼 overflow → Wrap/Flexible. 작은 화면 회전 후 overflow 없음 확인.
7. 라이브 세로 확대의 검은 전체 배경 → 공통 헤더/세로 영상/수동 가로 버튼 배치.

재실행: `flutter test --dart-define=CAPTURE_DESIGN=true test/design/final_design_capture_test.dart`.

## 시뮬레이터 비교·추가 보정

- iPhone 17/iOS 26.4에서 로그인 데이터를 보존하며 최신 소스를 실행했다. 아래 `sim-*.png`는 CUA로 저장한 실제 시뮬레이터 화면이다.
- 홈/팬: 시간 시트에서 1시간 선택 후 닫아도 팬 꺼짐 유지. 실제 팬 시작 명령은 보내지 않았다.
- 온습도: 오늘 대표값과 홈 실시간 값 일치, 과거 평균 미지원 안내, 지난 주 최고/일반/최저 막대색을 실제 데이터로 확인했다.
- 카메라: 첫 페이지 썸네일 로드, 연결 배지 제거, 기본 기간 설정, 취소 시 기본 문구 유지, 9/13~9/14 적용, 전체 기간 해제를 확인했다.
- `Page_Down`으로 오전 5시부터 전날 오후 11시까지 이동했다. 라이브 시각이 갱신되는 동안 스크롤 위치가 상단으로 튀지 않았고 날짜 경계를 넘어 다음 구간이 이어졌다.
- 실제 클립: 세로 진입, 60초 영상 재생, 수동 가로, 세로 복귀. 라이브: 세로 진입, 수동 가로, 닫기 후 세로 복원.
- 실제 16개 클립의 하단 목록을 Apple Photos형 중앙 필름스트립으로 변경했다. 일반 썸네일은 28×40, 중앙 선택 썸네일은 40×48이며 이전·다음 화살표를 제거했다. 탭은 즉시 전환·중앙 이동하고, 드래그는 중앙 후보만 갱신한 뒤 놓을 때 가장 가까운 영상을 1회 로드한다. 세로와 가로에서 같은 중앙 축을 확인했다.
- 북마크를 추가하고 해제해 원상복구했다. 두 동작 모두 토스트 없이 아이콘만 즉시 바뀌었다.
- 하이라이트 목록은 실제 영상으로 표시된다. 공개 배치 정보가 없어 도착 카드 읽음은 서버 연동 미완이다.
- 추가 보정: 카드 업데이트 문구 말줄임 제거, 가용 폭에서 한 줄 축소 표시, Figma `945:4172/4180`의 아이콘 배경 `#3C3C3C`와 카드 간격 8 적용, 상세/탭 공용 상태바 색 복원.
- 썸네일 비율은 export PNG에서 달라 보였으나 원본 노드 `945:4198` 등의 121.67×113과 구현이 일치해 변경하지 않았다.
- 실제 오프라인 캐시 재방문과 팬 실기기 ACK/자동 OFF는 미검증이며 자동 테스트 결과와 구별한다.
- 스크린샷: [홈](2026-09-14-implementation/sim-home.png), [팬](2026-09-14-implementation/sim-fan-duration.png), [오늘](2026-09-14-implementation/sim-env-today.png), [과거](2026-09-14-implementation/sim-env-past.png), [주간](2026-09-14-implementation/sim-env-weekly.png), [카메라](2026-09-14-implementation/sim-camera-after.png), [스크롤](2026-09-14-implementation/sim-camera-scroll.png), [클립 세로](2026-09-14-implementation/sim-player-portrait.png), [클립 가로](2026-09-14-implementation/sim-player-landscape.png), [라이브 세로](2026-09-14-implementation/sim-live-portrait.png), [라이브 가로](2026-09-14-implementation/sim-live-landscape.png), [하이라이트](2026-09-14-implementation/sim-highlights-after.png).

## 이전 검증 제한 이력

- iPhone 17/iOS 26.4, UDID `908C03D0-7C02-4CB1-8EB2-6F181A0FCFB9`에서 초기 flutter run 성공. CUA 첫 확인은 로그인 화면이었다.
- 이후 CUA는 “The Mac is locked and automatic unlock could not unlock it”을 반환했다. 사용자 직접 로그인 이후 위 범위를 실제 확인하고 추가 보정했다.
- 앱 설정 Supabase의 0-row schema probe: `telemetry_30m.t_a_valid_count` 미존재(42703). 익명 motion_clips 조회는 가시성 함수 권한 오류(42501)여서 실제 행을 읽지 않았다.
- 개발용 테스트 계정으로 로그인해 카메라·영상 메타 두 페이지를 조회하는 검증은 자동 승인 검토가 “해당 계정과 데이터 접근에 명시적 사용자 승인 없음”으로 거부했다. 자격증명/데이터를 출력하거나 다른 경로로 우회하지 않았다. 해당 읽기 검증 승인을 별도 요청했다.

## 계약/후속 패키지

- [평균·공개 하이라이트 계약](../plans/2026-09-14-data-contract-check.md)
- [MyCre 활동 실행 패키지](../plans/2026-09-14-mycre-activity-design.md)
- [기기 연결 v3·그룹 실행 패키지](../plans/2026-09-14-device-v3-design.md)

기존 MyCre CRUD/리포트, 종류별 BLE 연결, 커뮤니티 플레이어는 유지했다. Refer/ASIS/버린 시안/연결 v1·v2는 최신 v3와 혼합 적용하지 않았다. 활성 150개 항목의 원본 목록은 기존 Final Design 감사에 보존했고, 신규 MyCre/연결 v3를 이번 앱 구현 완료로 세지 않는다.

## 커밋

- `c22a012` 공통 SVG/역할색
- `aab530f` 주간 최저·동률
- `44c063e` 팬 선택→시작·일정
- `f343b64` 카메라/플레이어/데이터 adapter·위젯 1차 보정
- `e9b2a0b` 실제 시뮬레이터 비교 후 카드·상태바 보정
- `35e0225` Apple Photos형 중앙 영상 필름스트립
