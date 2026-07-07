# 교차 검수 결과 (Codex + Claude) — 활동량 UI 개선 (홈·크레캠)

> 대상: 저장된 기획 문서가 아니라 인라인 기획→구현된 **코드 변경 diff**
> 변경: 홈 '활동량 분석 요약' 더미→실 motion_clips + 크레캠 '간단 활동량'에 24시간 그래프
> 파일 8개(신규 2/수정 6), 검수일 2026-07-07

## 요약
- **Codex(gpt-5.5)**: 5건 (중간 3 / 낮음 2)
- **Claude 서브에이전트**: 12건 (높음 3 / 중간 3 / 낮음 6) — **실 DB(leegawnhun 계정) 대조 검증 포함**
- **2모델 공통 지적**: 1건 (쿼리 5000 상한 + total·그래프 스냅샷 불일치)
- 두 모델이 대체로 **상보적**으로 서로 다른 결함을 발견 → 이종 교차의 효과

---

## 🔴 2모델 공통 — 수정 권장

### C1. `.limit(5000)` 무정렬 + total/그래프 별도 쿼리 스냅샷 불일치
- 출처: **Codex**(motion_clip_repository.dart:87, my_cage_providers.dart:253·263) + **Claude**(중간 D)
- `motionSeconds`(총합)와 `motionSecondsByHour`(그래프)가 **별개 쿼리**이고 둘 다 `.order()` 없는 `limit(5000)`.
  - 5000 초과 시 비결정적 truncation → 총합과 막대합이 서로 다른 5000개를 집어 **수치 불일치** 가능.
  - 크레캠 `today`처럼 데이터 유입 중인 구간은 두 쿼리 사이 시점차로도 미세 불일치.
- **판단: 채택(부분).** 현재 카메라당 ~100건/일이라 실피해 없음(헤드룸 ~50배). 단 **cheap insurance**로 두 쿼리에 `.order('started_at')` 추가 → 초과해도 동일 부분집합을 집어 불일치 제거. 완전 pagination은 1인 개발 스코프에 과잉, 보류.

---

## 🟡 단독 지적 — 채택/기각 판단

### 🔴 High (Claude 단독, 실 DB 검증)

### S1. 홈 대표 카메라 = "최신 등록"이 실제 주력 카메라를 가림 — **채택(제품 결정 필요)**
- 출처: Claude (home_screen.dart:342 `cameras.first.id`)
- 실계정 확인: 첫 번째(created_at DESC)는 **P4 Cam 2(dev)**(clip 743, 마지막 07-06)인데, 정작 활발히 녹화 중인 **P4 Cam(dev)**(clip 2649, 07-07 녹화중)가 가려짐. "대표=최신등록"이 "대표=주력"과 어긋나 **조용한 카메라를 대표 지표로** 노출.
- 근거: "데이터 정확성=생명 직결" 원칙과 충돌. 승인된 가정("가장 최근")이었으나 실 계정에서 오해 유발 확인 → **사용자 재결정 필요**(아래 질문).

### S2. 홈 활동 카드에 카메라 이름 없음 — **채택**
- 출처: Claude (`_ActivityContent`)
- 계정에 카메라 2대인데 카드에 이름이 없어 "이 활동량이 어느 카메라/개체 것"인지 식별 불가. S1을 완화하는 최소 조치이기도 함 → **카메라 이름 라벨 추가**.

### S3. 크레캠 기본 `today` → 미래 시간대가 '무활동'과 구분 안 됨 — **채택**
- 출처: Claude (camera_detail_screen.dart:68 `_activityRange = today`)
- 크레캠은 `today`로 열림. 차트는 아직 안 온 저녁 시간을 `0`으로 받아 **무활동(흐린 3px 스텁)과 똑같이** 그림 → 오후에 열면 "저녁 내내 안 움직임"으로 오해. (홈은 `yesterday` 완결일이라 무관.)
- **수정: 경과 시각 이후 버킷을 시각적으로 구분**(미래 버킷 muted/생략). `HourlyActivityChart`에 `activeHours` 파라미터 추가.

### 🟡 Medium

### S4. `DateTime.now()` autoDispose 캐시 → 07:00/자정 롤오버 지연 — **기각(수용)**
- 출처: Claude (my_cage_providers.dart:255·265)
- autoDispose라 화면 이탈→재진입 시 재평가됨. 홈을 07:00 넘겨 계속 응시하는 경우만 stale → invalidation 타이머는 과잉. 수용.

### S5. max 정규화 → 2초 하루와 3시간 하루가 같은 막대 높이 — **기각(설계 의도)**
- 출처: Claude (hourly_activity_chart.dart:58) + 관련 Codex 없음
- 막대는 **시간 패턴(언제)**을, 절대량은 옆의 total 숫자가 담당. 홈·크레캠 모두 total을 병기 → 수용 가능. 스파크라인 표준 관행.

### S6. 1시간 경계 걸침 클립을 시작 버킷에 전량 귀속 — **기각(문서화된 근사)**
- 출처: **Codex**(cage_activity.dart:84)
- 07:59:30 시작 90초 클립이 08시에 반영 안 됨. 단 motion 클립은 대개 수초~1분이라 왜곡 미미하고 **코드 주석에 이미 "근사"로 명시**. duration 분할은 1인 스코프 과잉. 수용.

### 🟢 Low — 대부분 채택(간단 정리)

- **S7. 크레캠 `Color(0xFF222222)` 하드코딩** (Claude, camera_detail_screen.dart:393) — **채택**. "하드코딩 색상 금지" 위반(기존 부채) → `onSurface` 교체.
- **S8. ko.json "어젯밤 총 활동 시간" vs 실제 낮 포함 범위 모순** (**Codex**, ko.json:37) — **채택**. "어제 총 활동 시간"으로 정정.
- **S9. 차트 로딩/데이터 높이 불일치 → 로드 후 카드 튐** (**Codex**, hourly_activity_chart.dart:47) — **채택**. 크레캠 로딩 스켈레톤 72→~92로 정렬.
- **S10. `_cageActivityProvider` 중복 래퍼** (Claude) — **채택**. 크레캠도 `motionActivityProvider` 직접 watch로 통일.
- **S11. `CageActivity` 클래스 주석 stale**? (Claude, cage_activity.dart:11) — **기각(오탐, 검증됨)**. `CageActivity`는 `ClipRepository.getActivity()`가 **camera_clips.has_motion**로 채우는 별개 경로 → 주석이 실제로 맞음. 리뷰어가 신규 `motion_clips` 경로(=`motionSecondsByHour`, CageActivity 안 씀)와 혼동. 바꿨으면 오히려 틀릴 뻔.
- **S12. 홈 hourly 에러=빈 SizedBox(retry 없음), cameras 에러=조용히 숨김** (Claude, home_screen.dart:429) — **부분 기각**. 홈 대시보드는 에러로 어지럽히지 않는 게 나음(total은 '—' 표시). 숨김은 의도. 수용.
- **S13. DST 마지막 버킷 누락** (Claude, cage_activity.dart:84) — **기각**. KST는 DST 없음, 주석에 인지됨. 이식 시만 주의.
- **S14. 홈 `_LiveCard` 더미 24.5°C/68% 잔존** (Claude) — **기각(범위 외)**. 이번 작업 범위 아님 → 별도 팔로업.

---

## 💡 직관 질문 답변

- **삭제/단순화 가능한 것**: `_cageActivityProvider` 별칭 제거(크레캠도 `motionActivityProvider` 직접). 나머지(버킷 순수함수·공용 위젯·포맷터 분리)는 적절히 얇음 — 과잉설계 아님.
- **최대 리스크**: 홈이 "최신 등록" 카메라를 말없이 대표로 잡아, **멈춘/조용한 카메라의 어제 활동**을 대표 지표로 보여주는 것(라벨도 없어 오인 확정). = S1+S2. 데이터 정확성=생명 원칙과 정면 충돌 → 최우선.
- **우선 실기기 확인**: ① leegawnhun 로그인 → 홈이 어느 카메라를 잡는지 + total 숫자와 막대가 맞는지 대조. ② 크레캠을 **오후에 기본(today)으로** 열어 미래 시간대가 실제 무활동과 구분되는지 확인. (데이터 공백 우려는 해소 — motion_clips 3392건 전부 leegawnhun 소유, 07-07까지 최신.)

---

## 조치 결과 (2026-07-07 적용 완료)
- **적용**: S1(활성=최근 모션 카메라 선정, 사용자 채택), S2(카메라 이름 라벨), S3(미래 버킷 흐리게), S7(하드코딩 색 제거), S8(라벨 "어제 총 활동 시간"), S9(스켈레톤 높이 92 정렬), S10(`_cageActivityProvider` 제거), C1(양 쿼리 `.order()` 추가)
- **기각**: S4·S5·S6·S11(오탐)·S12·S13 — 위 근거 참조
- **팔로업(미적용)**: S14(_LiveCard 더미 온습도), 완전 pagination(데이터 급증 시)
- 검증: `flutter analyze` 신규 이슈 0 · 버킷팅 테스트 11개 통과 · debug 빌드 성공
