# Figma 후속 구현 결과 — 2026-09-15

앱 구현: **완료, 0.107.7+218 / e45f5c9**. 작업 트리 `.worktrees/redesign-20260915`, 브랜치 `codex/figma-redesign-20260915`. 운영 서버·DB 변경 없음. 이번 구현 커밋은 로컬에 저장했으며 push하지 않았다.

[16장 비교 페이지](2026-09-15-followup-captures/preview.html) · [그룹 삭제 서버 추가 요청서](../handoffs/2026-09-15-group-delete-atomic-contract.md)

## 반영 내용

| 범위 | 결과 |
|---|---|
| 그룹 설정 | 사육장/카메라/개체 36px 원형 슬롯과20px glyph, 소속 유무 색 구분, 기기 행 좌측24px·상단16px, 그룹 카드 최소78px와 간격, plus24·높이52 그룹 추가 카드 |
| 기기 상세 | ON 고정 정책을 유지하면서 회색112×40 전원 패널의 중앙 구분선 적용. 사육장·카메라 공통 |
| 온습도 | 상단 눈금 클리핑 수정,6시간 세로 실선·3시간 점선·마커/시간행 경계선 복원. 기존4px 선·색·원본 값·스크러버 유지 |
| 분무 | 원본 SVG를 보존하고 첫 배경 rect만 제외한28/36 글리프 파생본 추가. 마커와 제어 기록에 `deviceMist` 파랑 원 사용 |
| 드롭다운 | 세 탭의 원본 V자 SVG, 흰200px 메뉴·반경12·항목44·선택 Bold·빨강 선택됨·구분선·긴 이름 말줄임 |
| 개체 폼 | 사진 추가 glyph40에 deviceOff, 성별 비선택 두 칸 사이만1px 구분선 |
| 그룹 삭제 | 승인 확인 문구/취소/삭제, 전용 원자적 RPC, 실패 시 기존 그룹·입력 유지, 멱등 재시도, 성공 후 관련 목록 갱신. 운영 RPC 연결은 아래 서버 잔여 |
| MyCre | 확인된 카메라 미연결만 일간·주간 총 활동/평균0 및 빈 그래프. 관계 조회 중/실패는 미연결0 제외. 카메라 연결 CTA로 현재 개체가 선택된 그룹 구성원 선택 진입 |
| 컬러 시스템 | 새 CTA 전경 `buttonForeground`를 GlassPalette 생성자·선언·양 테마·copyWith·lerp에 추가. VIVA Fill/Back 사용, CTA218×56·좌우24px |

Y축 마스크는 위로7px 확장하면서 아래 끝은 기존 시간행 경계에 유지했다. 계획의 단순 높이14px 증가를 그대로 적용하면 시간 글자 윗부분을 덮을 수 있어 높이는7px만 늘렸다.

## 검증

- `flutter analyze --no-pub --no-fatal-infos`: 에러0·경고0, 기존 info6. [로그](2026-09-15-followup-captures/analyze.txt)
- 전체 `flutter test --no-pub`: **859통과,6건너뜀**. [요약](2026-09-15-followup-captures/tests.txt)
- 마지막 CTA 여백/전경 역할색 적용 후 관련 MyCre·흰배경 테스트 **7통과**. [요약](2026-09-15-followup-captures/final-style-tests.txt)
- 일반 `lib/main.dart` 타깃 iOS simulator debug 및 Android debug APK 성공. [iOS](2026-09-15-followup-captures/ios-build.txt), [Android](2026-09-15-followup-captures/android-build.txt)
- 그룹 삭제 repository 단일 RPC·미지원 오류, controller 실패 후 입력/구성원 유지·동일 request_id 재시도, UI 취소0회 쓰기·실패 화면 유지·성공 시 한 번 복귀/갱신 검증.
- 외부 네트워크 없는 임시 PostgreSQL에서 소유권 거부·삭제 직전 강제 오류 전체 rollback·원본 자료 보존·활동 구간 종료·멱등 응답·payload 충돌 검증. 전체 transaction rollback 후 임시 컨테이너 종료. [SQL 로그](2026-09-15-followup-captures/sql-verification.txt)
- iPhone17/iOS26.4에서16장 재촬영. 그룹 삭제 취소, 공통 드롭다운 선택, MyCre 주간 스크롤과 고정 흰 헤더, 성별 선택 변경 확인. 모든 값은 로컬 가상 fixture이며 네트워크/실기기 명령 없음.
- 최초 전체 테스트에서 긴 미번역 선택 키가 메뉴를 넘친 문제를 수정했고, 분무 glyph 전환을 기존 테스트 기대값에 반영한 뒤 전체 통과했다.

## 시각 판정과 범위

기존 차이9항목에 해당하는 코드 규격을 반영했고 그룹·전원·차트·분무·V자·개체 폼을 새 캡처로 확인했다. Figma 원본과 앱의 화면 폭393/402pt, 가상 이름·측정값·상태바·safe area·서버 미지원 평균 안내의 차이는 유지한다.

추가 메뉴 그림자는 현재 Talk to Figma 응답에 blur/offset/spread 수치가 없다. 화면에 그림자를 적용했지만 **그림자 수치의 일치 판정은 보류**한다. 카메라 라이브·썸네일은 로컬 검수의 비연결 상태이며 실제 영상 픽셀 대조 대상이 아니다. Android는 이번에 빌드만 검증했고 에뮬레이터 화면 대조는 하지 않았다. 폼 하단, 모든 확대 글자 크기/다크 테마 조합까지 새 캡처로 검증한 것은 아니다.

## 서버 잔여

`redesign_delete_group_v1`은 기존 공통 그룹/활동 이력 초안과 연계한 **검토용 SQL**이다. 격리 검증은 운영 배포 증거가 아니다. 이관훈님이 공통 writer·소유자 잠금·이력 갱신과 운영 RPC를 연결해야 실제 계정에서 그룹 삭제를 사용할 수 있다. 앱은 미지원 시 오류만 표시하며 개별 해제 반복으로 우회하지 않는다. [추가 요청서](../handoffs/2026-09-15-group-delete-atomic-contract.md)에 계약과 담당을 명시했다.

MyCre 초기0과 로컬 메모를 서버 데이터로 쓰는 작업은 없다. petcam-lab에 이번 그룹 삭제를 위한 R2 삭제 기능을 요청하지 않는다.

## 커밋

- `b94295c` /0.107.3+214: 그룹 관리·원자적 삭제 앱 계약 및 검토 SQL.
- `d961cfe` /0.107.4+215: 온습도 격자·눈금과 분무 팔레트.
- `58e4641` /0.107.5+216: 공통 드롭다운.
- `ac6c8bb` /0.107.6+217: 개체 폼.
- `e45f5c9` /0.107.7+218: MyCre 미연결 분기·CTA·컬러 역할.

검수 재현용 진입점은 [텍스트 보관본](2026-09-15-followup-captures/simulator_qa_entrypoint.dart.txt)에만 남겼다. 임시 Dart 진입점은 제거했고 일반 앱 빌드에 포함하지 않는다.

시뮬레이터 복원 확인: 일반 앱을 재설치·실행한 뒤 비바나트 로그인/둘러보기 화면을 확인했다. 가상 데이터 검수 메뉴와 표시가 제거됐다. 데스크톱 복사본은 `/Users/baek/Desktop/Vivanaut_Simulator_2026-09-15_Followup/preview.html`이다.
