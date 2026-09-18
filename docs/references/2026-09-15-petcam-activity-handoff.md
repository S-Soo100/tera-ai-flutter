# Flutter 핸드오프 — MyCre 활동 구간 API 연동 (2026-09-15)

> 대상: `tera-ai-flutter` 레포에서 작업하는 Claude/Codex 에이전트
> 서버 상태: DB와 API 모두 production 배포 완료
> API 주소: `https://api.tera-ai.uk`
> 서버 기준 커밋: `56d673a` (`main`, `origin/main` 반영 완료)

---

## 한눈에 보는 결론

- MyCre 활동 그래프에 쓸 실제 활동 구간 API가 배포됐어.
- GME 분석이 있는 영상은 실제 `moving` 구간을 줘.
- 과거 영상처럼 GME 결과가 없으면 기존 `effective_activity_sec`를 영상 시작점부터 배치한 추정 구간을 줘.
- 영상 자체가 없는 시간은 활동 0으로 만들지 않고 `no_video`로 구분해.
- KST 일간·주간 집계와 개체–카메라 연결 이력 적용은 Flutter가 담당해.
- 수집 completeness, 기기 해제 후 과거 접근권, 하이라이트 공개 배치 메타데이터는 이번 배포에 포함되지 않았어.

---

## 붙여넣기용 작업 프롬프트

```text
레포: /Users/baek/myProjects/tera-ai-flutter

먼저 해당 레포의 AGENTS.md, CLAUDE.md와 작업 규칙을 읽고 현재 main 기준으로 작업해.

목표:
MyCre 활동 그래프를 petcam-api의 owner activity interval 계약에 연결해. 개체 식별 AI를 추가하는 작업이 아니다. 앱이 가진 개체–카메라 연결 이력으로 조회 범위를 자르고, 서버가 반환한 활동 구간을 KST 일간·주간 그래프로 집계한다.

서버 배포 상태:
- production DB migration 완료
- petcam-api production 배포 완료
- base URL: https://api.tera-ai.uk
- 서버 commit: 56d673a
- 전체 서버 테스트: 2,987 passed, 5 skipped
- 외부 확인: GET /health = 200
- 인증 없는 GET /activity/intervals = 401

인증:
- 기존 petcam-api 호출과 같은 Supabase access token을 사용한다.
- Authorization: Bearer <Supabase JWT>

엔드포인트:
GET /activity/intervals

필수 query:
- camera_id: UUID, 현재 사용자 소유 카메라
- from: timezone이 포함된 ISO 8601 시작 시각, 포함
- to: timezone이 포함된 ISO 8601 종료 시각, 미포함

선택 query:
- limit: 기본 200, 1~500
- cursor: 직전 응답의 next_cursor를 그대로 전달하는 opaque 문자열

시간 계약:
- 조회 범위는 [from, to) 반열림 구간이다.
- 한 요청의 최대 범위는 31일이다.
- 앱에서는 from/to를 UTC로 보내고 응답도 UTC instant로 처리해.
- cursor를 해석하거나 직접 만들지 마.
- has_more=true이면 같은 camera_id/from/to에 next_cursor만 붙여 다음 페이지를 받는다.

개인정보를 제거한 응답 예시:
{
  "camera_id": "11111111-1111-4111-8111-111111111111",
  "from": "2026-09-14T15:00:00+00:00",
  "to": "2026-09-15T15:00:00+00:00",
  "contract_version": "owner-activity-v1",
  "intervals": [
    {
      "start_at": "2026-09-14T15:03:10+00:00",
      "end_at": "2026-09-14T15:03:42+00:00",
      "quality": "exact"
    },
    {
      "start_at": "2026-09-14T16:20:00+00:00",
      "end_at": "2026-09-14T16:20:18+00:00",
      "quality": "legacy_estimate"
    }
  ],
  "video_clip_count": 5,
  "exact_clip_count": 2,
  "fallback_clip_count": 3,
  "fallback_reasons": {
    "missing": 1,
    "pending": 1,
    "failed": 1
  },
  "data_status": "mixed",
  "has_more": false,
  "next_cursor": null
}

필드 의미:
- intervals: 같은 카메라에서 겹치거나 맞닿은 활동 구간을 서버가 합집합한 결과
- quality=exact: GME가 실제로 측정한 moving 구간
- quality=legacy_estimate: GME 정본이 없어서 기존 effective_activity_sec를 영상 시작점부터 배치한 호환 구간
- quality=mixed: exact와 legacy_estimate가 겹쳐 하나로 합쳐진 구간
- video_clip_count: 조회 범위와 겹치는 유효 영상 수
- exact_clip_count: exact 근거를 사용한 영상 수
- fallback_clip_count: 기존 활동 초 fallback을 사용한 영상 수
- fallback_reasons: fallback 원인이 missing/pending/failed인 영상 수
- data_status=exact: 모든 영상이 exact
- data_status=mixed: exact와 fallback 영상이 함께 있음
- data_status=legacy_estimate: 영상은 있지만 모두 fallback
- data_status=no_video: 조회 범위에 영상 자체가 없음

0과 결측 처리:
- video_clip_count > 0이고 intervals가 비어 있으면 "영상은 있었고 활동은 0"으로 처리할 수 있다.
- data_status=no_video이면 활동 0으로 평균 분모에 넣지 마. 영상이 없는 결측이다.
- 과거 영상은 GME 분석이 없어도 legacy_estimate로 계속 표시한다. 이 fallback은 owner가 승인한 정책이다.
- 현재 카메라가 온라인이라는 이유로 과거 날짜를 수집 완료로 판단하지 마.
- 이 API의 video_clip_count는 존재하는 영상 수이지 하루 전체의 수집 completeness 증명이 아니다.

앱 구현 범위:
1. API DTO, datasource/repository를 추가한다.
2. 현재 앱의 개체–카메라 연결 이력을 기준으로 연결 기간과 조회 기간의 교집합만 요청한다.
3. 새 개체 연결 시작 전 활동은 그 개체에 귀속하지 않는다.
4. 카메라가 바뀐 개체는 이전·새 카메라의 각 연결 기간을 조회해 이어 붙인다.
5. 각 응답 구간을 연결 시작/종료, 조회 시작/종료 경계로 한 번 더 clip한다.
6. pagination과 여러 연결 기간의 결과를 합친 뒤 겹치거나 맞닿은 구간을 방어적으로 다시 union한다.
7. UTC instant를 KST 경계로 나눈 뒤 시간별·일간·주간 초를 계산한다.
8. 시간당 최대 3,600초가 되고 시간별 합, 일간 합, 주간 합이 서로 일치하게 한다.
9. quality와 data_status는 모델에 보존한다. 기술적인 quality 문자열을 사용자 화면에 그대로 노출하지는 마.

확정 집계 규칙:
- 일간: KST 00:00 이상 ~ 다음 날 00:00 미만
- 주간: KST 월요일 00:00 이상 ~ 다음 월요일 00:00 미만
- 일간 총합: 선택한 날짜의 활동 시간
- 일간 비교 평균: 선택일을 제외한 직전 7일 중 완료일 평균. 완료된 0은 포함하고 결측일은 제외
- 주간 총합: 해당 주 활동 시간. 이번 주는 오늘 진행분 포함
- 주간 평균: 해당 주의 완료일만 사용하고 진행 중인 오늘은 제외

중요한 제한:
- petcam-api 활동 API만으로는 하루 전체의 카메라 수집 completeness를 증명할 수 없다.
- 정확한 평균 분모의 "관측 완료일" 판정은 terra-server 수집 coverage 계약이 연결된 뒤 확정한다.
- 그 계약이 아직 앱에 없다면 no_video를 0으로 간주하는 새 로직을 만들지 말고, 기존 앱의 완료일 판정을 유지하면서 TODO와 제한을 명시해.
- API는 현재 카메라 소유권을 검사한다. 기기 등록 해제나 소유자 변경 뒤 과거 접근권 승계는 별도 서버 계약이 필요하다. 우회하지 마.

오류 처리:
- 400: 시간 범위/시간대/cursor 오류 — 개발 로그를 남기고 일반 오류 상태
- 401: 인증 만료 — 기존 인증 갱신 흐름 사용
- 404: 카메라가 없거나 현재 사용자 소유가 아님 — 연결 정보를 새로고침하고 해당 범위는 표시하지 않음
- 422: UUID 또는 limit 형식 오류 — 앱 버그로 처리
- 502: 활동 데이터 일시 조회 실패 — 재시도 가능한 오류 상태
- 503: 서버의 활성 GME 계약 설정 오류 — 재시도 가능한 서버 오류 상태

필수 테스트:
- KST 23:59:50~다음 날 00:00:10 활동은 두 날짜에 각각 10초
- 같은 카메라 00~20초와 10~30초는 합집합 30초
- 영상이 있고 활동 구간이 없으면 완료된 0초로 유지
- no_video는 활동 0이 아니라 결측
- 개체가 12:00에 연결되면 12:00 이전 활동 제외
- 카메라 변경 시 각 연결 기간의 기록이 이어짐
- pagination 중복이나 페이지 경계에서도 이중 합산 없음
- legacy_estimate 응답도 기존 과거 그래프에 표시됨
- 한 시간 합계가 3,600초를 넘지 않음

이번 작업에서 건드리지 않을 것:
- highlight_batch_id, 승인 스냅샷, 실제 공개 시각 연동
- 영상 메모 서버 저장
- 사용자 숨김을 공유 RLS나 활동 통계에 섞는 변경
- R2 원본 삭제
- petcam-lab의 서버 측 KST 일간/주간 집계 추가

완료 보고에는 아래만 짧게 적어:
- 변경 파일
- 사용한 API 모델과 상태 처리
- 테스트 명령과 결과
- 수집 completeness 또는 과거 접근권 때문에 남은 TODO
```

---

## Flutter 팀이 알아야 할 미지원 범위

이번 서버 배포로 해결된 건 “영상이 존재할 때의 활동 구간”이야. 아래는 별도 협의가 필요해.

- 하루 전체가 정상 촬영됐는지 판단하는 수집 coverage
- 기기 해제·소유자 변경 후 기존 사용자 과거 영상 접근권
- `highlight_batch_id`, 승인 스냅샷, 실제 공개 시각을 포함한 하이라이트 공개 조회 계약

따라서 Flutter는 없는 정보를 추정해서 채우지 않고, 위 항목은 기존 동작을 유지하거나 TODO로 남겨야 해.
