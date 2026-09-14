# MyCre 활동 화면 실행 패키지

상태: Figma·기존 코드 대조 완료, 데이터 정확성 계약 대기. 이번 구현에서 기존 개체 CRUD/리포트는 보존했다. 신규 화면 완료로 세지 않는다.

## 화면 근거와 체험

Talk to Figma `CreActivity`(802:2383), 최종 945:4384/945:4596/994:13348: 393pt 폭, 개체 프로필(이름·성별·모프·체중), 선택 날짜와 시간별 활동, 주간 날짜 범위·총 활동/평균·요일별 막대. Figma의 ‘오전 6~7시 62분’ 등 샘플은 실제 활동 계약으로 사용하지 않는다.

| 화면 | 조작 | 반응 | 체험 |
|---|---|---|---|
| 선택 그룹의 개체 프로필·일간 그래프 | 날짜 이동 | 같은 개체의 해당 날짜 집계로 교체 | 날짜별 변화 이해 |
| 주간 그래프 | 전/다음 주 | 동일 입력의 일간 합계 7개와 총합·평균 | 일/주 수치 일치 |
| 프로필/상단 선택 | 다른 개체 선택 | 이전 응답을 버리고 새 카메라 범위 조회 | 데이터가 섞이지 않음 |
| 개체 없음 | 개체 추가 | 기존 `/my-pets/add` 진입 | 기존 등록 유지 |
| 카메라 없음 | 연결 안내 | 기존 연결 진입 | 0 활동으로 오인하지 않음 |
| 수집중/조회 실패 | 기다림/재시도 | 수집상태/에러 분리 | 미수집을 0으로 읽지 않음 |
| 화면 열린 채 07시 경과 | 조작 없음 | 활동일/집계 창 재평가 | 날짜와 데이터 일치 |

## 확인된 계약과 부족분

`MotionClipRepository.motionSeconds`는 `motionSecondsByHour`의 합을 반환하므로 동일 24시간 입력의 합계는 일치한다. 그러나 `_loadActivityRows`는 effective view 실패 시 raw duration으로 fallback하며, row의 수집 완결 여부를 제공하지 않는다. 이 값을 정확한 새 활동 분석 지표로 조용히 재사용하지 않는다. 기존 리포트 동작은 그대로 둔다.

필요한 확정: effective 활동 구간의 겹침 제거 여부/시간 경계 분할, 24시간 활동일 07~07 vs 자정 기준, 미수집/관측 0/진행중 구별, 일평균의 분모(관측완료일만인지), row 상한 및 페이지 정렬. 권장: 합집합한 실제 활동 구간을 시각 버킷에 배분하고 완료일만 평균 분모로 사용하며 분모를 반환한다.

fixture: 23:59:50~00:00:10 활동은 10초씩 두 버킷, 겹치는 두 20초 활동은 단순 40초 합 금지. 월 10분·화 관측 0·수 미수집이면 완료일 평균 5분, 분모 2. 현재 API가 이 fixture를 보장하는지는 미확인이다.

## 구현 파일과 순서

1. `my_pets/domain/activity_summary.dart`: 일/주 합계·coverage 모델. `activity_window.dart`: 확정된 경계 계산.
2. `my_pets/data/activity_repository.dart`: owner/camera/window별 확정 API adapter. 기존 raw fallback과 분리, 응답 상한을 넘는 조회는 pagination.
3. `my_pets/presentation/activity_providers.dart`: `(owner, pet, camera, day/week)` 키, stale 응답 배제, 날짜 경계 timer.
4. `my_pets/presentation/my_cre_activity_screen.dart`, `widgets/activity_day_chart.dart`, `activity_week_chart.dart`, `activity_pet_header.dart`: Figma 최종 프레임과 동일 구조. 기존 `my_pets_screen.dart` 목록은 ‘개체 추가·관리’ 진입으로 보존. 편집/삭제 기존 라우트 유지.
5. `core/router/tab_branches.dart`의 MyCre 진입만 새 화면으로 교체. 딥링크와 기존 `/my-pets/add`/편집은 보존.
6. domain 합계/분모/경계 fixture, provider 전환, 개체 없음·미수집·오류 위젯 테스트, 393pt 및 큰 글자 비교.

신규 화면인 CAOF Critical 작업이다. 서버 계약 확정 후 위 파일을 flutter-dev에 할당하며, 이번 승인된 기존 화면 수정과 별도 커밋으로 진행한다. 현재는 불확실한 활동 수치를 사용자에게 노출하지 않는다.
