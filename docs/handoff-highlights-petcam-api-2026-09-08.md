# 하이라이트 피드 전환 핸드오프 — terra-server → petcam-api `/highlights` (2026-09-08)

> 대상: Flutter 앱 담당자. 브랜치 **`feat/highlights-petcam-api`**(커밋 `5427acd`, main 미머지, 10파일 +261/−91).
> 백엔드는 이미 배포돼 있음(petcam-api fly v3, `https://api.tera-ai.uk`). 이 브랜치를 머지·빌드하면 앱에서 바로 새 하이라이트가 보인다.
> 서버 계약·운영 배경 전체는 petcam-lab `docs/handoff-prompts/2026-09-08-app-highlight-api-handoff.md`.

## 1. 한 줄 요약

하이라이트가 **"AI가 행동을 알아본 영상"** 에서 **"움직임 규칙으로 자동 판정된 영상 + 사람이 확인한 영상"** 으로 바뀌었다. 판정 기준(규칙 v0)은 운영자가 몇 주간 라벨링 웹에서 조정하고, 조정 즉시 앱 결과에 반영된다. 앱은 기준을 몰라도 되고, 서버가 준 `reason` 문구를 그대로 보여주면 된다.

## 2. 왜 바꿨나 (배경 두 줄)

- 옛 피드는 terra-server가 VLM 행동 라벨(탈피·음수 등)로 골랐는데, VLM 호출을 멈춰서 새 영상엔 라벨이 안 붙는다.
- 새 피드는 GME(게코 움직임 측정) 숫자로 모든 영상에 자동 `O/X`를 붙이고, 라벨링 웹에서 사람이 확정한 값이 우선한다. 판정 정의는 DB 함수 한 곳에만 있어서 라벨링 웹과 앱이 항상 같은 결과를 본다.

## 3. 브랜치에서 바뀐 것

| 파일 | 변경 |
|---|---|
| `lib/features/my_cage/data/highlight_repository.dart` | base URL `EnvConfig.backendUrl`(=`BACKEND_URL`, `https://api.tera-ai.uk`), 경로 `/highlights`, 쿼리 `since`·`limit`(1~100 클램프 유지). `http.Client` 주입 가능(테스트용, 기본값 `http.Client()`). 404 → 빈 목록, 그 외 → `BackendException` (동작 동일) |
| `lib/features/my_cage/domain/nightly_highlight.dart` | `vlmAction / confidence / careLevel` **삭제** → `cameraId, cameraName, durationSec, source('human'\|'rule'), reason, ruleVersion, decidedAt` 추가, `isHumanConfirmed` getter. `fromJson`은 null 허용 |
| `lib/features/my_cage/domain/nightly_report.dart` | `drinkCount / eatCount / shedCount` 삭제 → `highlightCount`. `activityMinutes`·`isQuiet` 그대로 |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | `highlightRepositoryProvider`가 `baseUrl: EnvConfig.backendUrl`. `terraServerUrl`은 다른 곳(IoT·motionSeconds)에서 계속 씀 |
| `lib/features/my_cage/presentation/nightly_report_view.dart` | 요약 카드: 행동별 3개 카운트 → "✨ 하이라이트 N개" 하나. 카드 배지 = `reason`(없으면 "하이라이트"), 사람 확인이면 체크 아이콘(`_HighlightCard.confirmedKey`). `reportActionLabel` 삭제 |
| `assets/l10n/ko.json` | 추가 `nightly_count_highlight`, `nightly_highlight_count`, `highlight_badge_auto`, `highlight_badge_confirmed` / 삭제 `nightly_count_drink·eat·shed`(소비처 없음) |
| `test/features/my_cage/…` | `nightly_highlight_test`·`nightly_report_test`·`highlights_screen_test` 새 모델로 갱신, `highlight_repository_test` 신규(`MockClient`: 경로·쿼리·Bearer·파싱·클램프·404/503) |

건드리지 않은 것: `highlights_screen.dart`, `highlight_group.dart`(72시간 묶음), 재생·즐겨찾기·썸네일 — 전부 `clipId/startedAt`만 쓰므로 그대로. 어젯밤 리포트의 활동시간(`motionSeconds`)도 기존 경로 그대로.

검증 결과: `flutter analyze` 새 이슈 0(기존 info 7개는 무관 파일), `flutter test` 관련 5파일 39개 통과.

## 4. 서버 계약 (앱이 받는 것)

`GET /highlights?since=<ISO8601 UTC>&limit=<1..100>` · 헤더 `Authorization: Bearer <Supabase access_token>` (다른 petcam-api 호출과 동일)

```json
{
  "highlights": [
    {
      "clip_id": "…uuid…",
      "camera_id": "…uuid…",
      "camera_name": "거실",
      "started_at": "2026-09-07T18:12:03+00:00",
      "duration_sec": 60.6,
      "media_ready": true,
      "source": "rule",
      "reason": "움직임 12.4초 · 최장 연속 6.1초",
      "rule_version": "hl-rule-v0",
      "decided_at": null
    }
  ],
  "count": 1, "has_more": false, "next_cursor": null, "rule_version": "hl-rule-v0"
}
```

- `source`: `"human"` = 라벨링 웹에서 사람이 O로 확정(규칙보다 우선) / `"rule"` = 자동 판정.
- `reason`: 규칙이 읽은 숫자 그대로. 카드에 그대로 노출해도 됨(현재 브랜치가 그렇게 함).
- `rule_version`: `rule` 항목만 채워짐, `human`은 `null`. 운영자가 규칙을 바꾸면 이 값이 바뀌고 `rule` 항목의 결과가 즉시 바뀐다(저장값이 아니라 조회 시 계산).
- `media_ready=false`면 원본이 삭제된 영상 — 재생 버튼을 막거나 숨길 것(현재 브랜치는 아직 안 씀 → §6 후속).
- 본인 소유 카메라(`cameras.owner_id`) 영상만 온다. 카메라가 없으면 빈 목록.
- 정렬 `started_at` 내림차순. `since`는 포함 하한, 생략 가능. `cursor`는 이전 응답 `next_cursor`(불투명, 현재 앱은 미사용 — `limit=100` 한 페이지).
- 오류: `401` 인증 · `422` 범위 밖 · `400` since/cursor 손상 · `404` 활성 규칙 없음(운영 사고) · `502` DB · `503` GME 계약 미해결 · `504` 계산 시간 초과(재시도).
- `GET /highlights/rule` → `{version, params, activated_at}` 활성 규칙. 앱 표시에는 불필요, 디버그용.

**기대하지 말 것:** 행동 이름(`vlm_action`), `confidence`, `care_level`. 행동 분류는 별도 단계에서 다시 온다.

## 5. 머지 전 확인 순서

1. `feat/highlights-petcam-api` 체크아웃 → `flutter analyze`, `flutter test test/features/my_cage/`.
2. 실기기/시뮬레이터에서 **마이 크레 > 리포트 탭**: "하이라이트 N개 + 활동시간" 요약, 카드 배지에 `reason` 문구, 사람 확정 항목엔 체크 아이콘.
3. **하이라이트 화면**(`/crecam/highlights`): 72시간 묶음·배너·재생·즐겨찾기가 이전과 같은지.
4. 빈 목록이면: 라벨링 웹(`label.tera-ai.uk`) `전체` → `하이라이트 O` 필터로 해당 카메라에 O가 있는지 대조. 새 카메라·야간 영상 없으면 정상적으로 빔.
5. 로그에서 `GET /highlights` 200 확인. 401이면 토큰 만료(기존 petcam-api 호출과 같은 갱신 경로).

## 6. 후속(이 브랜치에 안 넣은 것)

- `media_ready=false` 항목 재생 차단 UI.
- `next_cursor` 페이지네이션(지금은 최대 100건 한 페이지 — 30일치가 100건을 넘으면 오래된 것이 잘림).
- 어젯밤 리포트 "조용한 밤" 문구는 `isQuiet`(하이라이트 0개) 그대로 — 카피 재검토 여지.
- terra-server `/clips/highlights`는 앱이 더 이상 호출하지 않음. 삭제는 하지 말고 "앱 미사용" 표시만(그쪽 개발자에게 별도 전달).

## 7. 운영 배경 (질문 받으면)

라벨링 웹 회원들이 매일 자동 판정을 `O/X`로 확정하고, 운영자는 주 1회 유지율을 보고 규칙 숫자(현재 "움직임 ≥10초 또는 연속 ≥5초")를 바꾼다. 그래서 같은 영상의 하이라이트 여부가 규칙 변경 뒤 달라질 수 있고, 이게 의도된 동작이다. 앱은 `rule_version`을 로그에 남기면 "그때 왜 하이라이트였지"를 추적할 수 있다.
