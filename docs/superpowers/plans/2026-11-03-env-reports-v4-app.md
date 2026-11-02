# v4 일일·주간 온습도 분석 카드 Implementation Plan (r2)

> **구현 방식 (CAOF):** Critical 트랙 — 새 데이터 소스 2개(`env_daily_reports`·`env_weekly_reports`) + 새 파일 5개 이상(전역 CAOF "4+ 파일·새 시스템"). 2026-11-03 사용자 지시("검수 반영해서 구현까지 바로 진행") — /검수 반영 후 GATE 3 대기 없이 구현한다. 검수 결과: [`reports-plan-review-final.md`](../../design-audits/2026-11-02-env-alerts-v4/reports-plan-review-final.md). Steps use checkbox (`- [ ]`) syntax.

**Goal:** 온습도 상세의 지난 날짜 화면에 서버 일일 분석 카드를, 주간 화면의 각 차트 아래에 서버 주간 분석 카드와 예외 안내(`notices`)를 그린다.

**Architecture:** 서버가 문구까지 완성해 저장한 두 테이블을 RLS 직결 SELECT + Realtime으로 읽는다(쓰기 없음). 카드 JSON은 도메인 모델 하나(`EnvReportCard`)로 파싱하고, 실시간 이탈 카드와 같은 겉모양을 공용 위젯(`EnvInsightCard`)으로 뽑아 세 카드가 함께 쓴다. 페이지(날짜·주)마다 provider family 하나 — 조회 후 그 기기 행의 INSERT/UPDATE를 받고, 끊겼다 붙으면 다시 조회한다.

**Tech Stack:** Flutter, Riverpod(StreamProvider.autoDispose.family), supabase_flutter(`bindResilientChannel`), easy_localization.

**Spec:**
- 서버 `terra-server` `feat/weekly-analysis-v4` — `docs/APP_DAILY_ANALYSIS_2026-11-02.md`, `docs/APP_WEEKLY_ANALYSIS_2026-11-02.md`, `docs/APP_V4_HANDOFF_2026-11-02.md`
- 서버 재회신(하루 경계 08:00 KST 확정, 표시는 행 구간 값) — [`docs/handoffs/2026-11-02-env-alerts-v4-server-questions.md`](../../handoffs/2026-11-02-env-alerts-v4-server-questions.md) §6
- Figma 온습도 분석 `1610:6572` — [`figma-structure-analysis.md`](../../design-audits/2026-11-02-env-alerts-v4/figma-structure-analysis.md) A14·A15~A18·A27·A28(일일), A19·A20~A25·A29~A34(주간)

## Global Constraints

- 문구는 서버 `title`·`lines`·notice `title`/`body` **그대로**. 앱이 문장을 잇거나 고치지 않는다. 구간 캡션(D3)은 행의 `window_start`/`window_end` 값으로만 만든다.
- 집계 구간은 서버 기준(일일 08:00~다음 날 08:00 KST, 주간 월 08:00~다음 월 08:00). 앱은 페이지 → 행 매칭만 한다(D1·D2).
- 카드 `status`는 `danger`/`caution`/`normal` — `alerts.severity`와 섞지 않는다.
- 카드 `null`·행 없음·모르는 `code`/`status`는 오류가 아니다.
- 읽기 전용: RLS 본인 기기 SELECT(2026-11-03 운영 확인). 쓰기·RPC 없음.
- 문자열 `ko.json`, 색 `context.glass`/VIVA 역할색, 글자 크기 Figma 그대로. 로딩 표시는 아래 D9(선택 콘텐츠라 자리 없음 — 실시간 카드 선례).
- lib 변경 커밋마다 버전 + CHANGELOG. 버전은 병합 직전 main보다 한 칸 위.
- 건드리지 않는 것: 오늘 화면 실시간 이탈 카드 동작(`openEnvAlertsProvider`, `EnvAlertCard`의 키·문구), 일간 그래프·범위 바·제어 기록, `WeekRangeChart`(막대·헤더·축), 자정 기준 페이징(`EnvDay`·`WeekRange`), 서버 스위치·테이블.

## 유저 체험 시뮬레이션 (기준: 2026-11-04 수요일 10시, 서버 분석 스위치 켜짐 가정)

1. 홈 → 온습도 상세(일간, 오늘 11/4). 기존과 같다 — 이탈 중이면 실시간 카드, 아니면 카드 없음.
2. ← 눌러 **11/3**. 그래프 아래에 회색 작은 글씨 "11/3 08:00 ~ 11/4 08:00 분석", 그 아래 회색 카드 두 줄: **[온도]** 빨간 칩 "높은 온도가 기록됐어요" / "14:00~14:30 적정 온도보다 최대 +1.8℃ 이탈". 구분선 아래 **[습도]** 남색 칩 "건조를 주의해 주세요" / "22:00~11/4 08:20 적정 습도보다 최대 -9% 이탈". 캡션 덕에 카드의 "02:00" 같은 시각이 그래프의 같은 날 새벽이 아니라는 걸 안다.
3. 11/3에 이벤트가 없고 수집이 충분 → 온도 줄만 "주간과 야간 모두 적정 온도를 유지했어요". 습도는 이벤트 없으면 서버가 카드를 안 만든다. 둘 다 없으면 캡션도 카드도 없다.
4. 아침 08:30에 어제 화면을 열어 둔 채 09:05가 지나 서버가 2차로 고쳐 쓰면 카드가 그 자리에서 바뀐다(Realtime UPDATE). 설정 화면에 갔다 와도, 앱을 내렸다 올려도 끊긴 사이 변화는 다시 조회로 맞춘다.
5. 행이 없으면(스위치 꺼짐·생성 전) 아무것도 없다. 조회 실패면 카드 자리에 "분석을 불러오지 못했어요 · 다시 시도".
6. [주간] → ← 눌러 **지난주 10/26~11/1**. 온도 막대 차트 아래 12 띄우고 카드: 흰 칩 **경고** "주간 중 위험 온도가 감지되었어요" / "총 2회 위험 온도 발생. 적정 온도보다 최대 4.1℃ 이탈". 36 아래 습도 차트, 그 아래 **주의** "사육장이 건조한 날이 많았어요".
7. 그 주 습도 수집이 3일 미만 → 습도 카드 자리에 안내 "주간 분석을 위한 데이터를 모으고 있어요" / "최소 3일의 데이터가 필요해요". 수집이 끊겼던 주(ERR_DISCONNECT)는 안내 면이 먼저, 8 띄우고 카드 면.
8. 이번 주(11/2~11/8) → 주간 카드 없음(11/9 월 09:05 이후 생성). 이번 주 화면을 연 채 월요일 09:05를 넘기면? 그 주는 여전히 "이번 주" 페이지가 아니게 되지만 화면은 페이지를 바꾸지 않는다 — 다음 진입 때 보인다. 서버의 첫 주간 행은 v4를 켠 뒤 **온전히 시작한 첫 주**부터다.

## 가정

| # | 가정 | 상태 |
|---|---|---|
| G1 | 두 테이블 존재·RLS 본인 기기 SELECT·Realtime publication 포함·비어 있음 | **확인**(운영, 2026-11-03 MCP: 열 9개씩, 정책 `own env_*_reports select`, `supabase_realtime` 포함, 0행) |
| G2 | `report_date`·`week_start`는 `date`, `window_*`는 timestamptz | **확인**(같은 조회) |
| G3 | 일일 행은 1차 INSERT 뒤 최대 1번 UPDATE, 주간은 한 번 INSERT | 서버 문서 §3·§1 |
| G4 | 폰 시간대가 KST가 아니어도 페이지 달력 날짜 = 서버 날짜로 맞춘다 | 결정 — 해외 사용자 극소, 한계 |
| G5 | 카드 JSON 형식은 서버 생성기 배포 전 문서 기준 | **미확인** — 서버 3단계 뒤 실데이터로 확인 |

## 결정 (D)

| # | 질문 | 결정 | 이유 |
|---|---|---|---|
| D1 | 일간 페이지 D에 어떤 행? | `report_date = D`. 오늘 페이지에는 그리지 않는다 | Figma A14. 오늘 것은 다음 날 생성 |
| D2 | 주간 페이지에 어떤 행? | `week_start = 그 주 월요일`. 이번 주 페이지에는 그리지 않는다 | 서버 §1 |
| D3 | 그래프(자정)와 카드(08시) 구간 차이 | **카드 위 캡션 "M/D HH:mm ~ M/D HH:mm 분석"**(행 `window_*`, 로컬 시각) — 일일만. 주간은 "월~일" 표시가 기획이라 캡션 없음. 서버에 "구간 시작일 다음 날 시각에도 날짜 표기" 요청(질의서) | 검수 최대 리스크. Figma 밖 추가 — 사용자가 정할 것 ① |
| D4 | 갱신 | 조회 + Realtime INSERT/UPDATE(기기 필터) + 재합류 재조회. 시간으로 거르지 않는다 | 서버 §3 권장, 검수 공통 2 |
| D5 | 주간 `lines` 여러 줄 | 줄마다 따로 | 잇려면 앱이 문장부호를 만들어야 한다 — 사용자가 정할 것 ② |
| D6 | 주간 `notices` 모양 | 같은 겉모양, 칩 없이 제목 16/600 + 본문 14/500(자간 −2%). 안내 면과 카드 면은 **별도 회색 면**, 사이 8. ERR_NO_DATA는 카드 대신, ERR_DISCONNECT는 카드 위 | Figma에 안내 디자인 없음 — 사용자가 정할 것 ③ |
| D7 | 모르는 `status` | 주간 칩 생략, 나머지 그림 | 어휘 확장 대비 |
| D8 | 주간 막대 이탈일 강조(A19) | 범위 밖 → **0.167.2 처리**: 강조는 이탈일이 아니라 주간 최고·최저 날이었다(날짜 어긋남 없음). 적정 띠·습도 축 상한 함께 | 막대(자정)와 이벤트(08시) 날짜 어긋남 — 후속 |
| D9 | 로딩 | 처음 로딩은 자리 없음 → 데이터가 오면 카드가 끼어든다(**레이아웃 밀림 수용**). 재조회 중엔 이전 값 유지(`skipLoadingOnReload`) | 대부분 페이지는 카드가 없어 스켈레톤이 오히려 깜빡임. 실시간 카드 선례 — 사용자가 정할 것 ④ |
| D10 | 조회 실패 | 카드 자리에 한 줄 안내 + 다시 시도(provider invalidate) | 안 그리면 "이벤트 없음"으로 오해 |
| D11 | 오늘·이번 주 판정 | 화면이 `envDetailNowProvider`(1분 틱)로 `day.containsNow`·`week.end > now` 판정 — provider를 아예 watch하지 않는다 | 자정 넘김에도 판정이 굳지 않게 |

## 사용자가 정할 것 (구현은 위 결정대로 진행, 바꾸면 해당 줄만 수정)

1. **일일 카드 구간 캡션**(D3) — Figma 밖. → **확정(2026-11-03 사용자): 이대로 둔다.**
2. **주간 카드 줄 분리**(D5) — → **확정(2026-11-03 사용자 "Figma대로"): 한 문단으로 잇는다.** 앞 줄이 마침표 없이 끝나면 ". ", 마침표로 끝나면 " "(서버 `weekly_analysis.py` 줄 형식 확인 — Figma A20과 같은 결과). 0.167.1
3. **주간 안내 디자인**(D6) — "Figma대로" → Figma에 안내 디자인이 없어 **카드와 같은 Figma 겉모양(칩 없음) 유지**.
4. **로딩 중 레이아웃 밀림 수용**(D9) — "Figma대로" → Figma에 로딩 상태가 없어 **현행 유지**(최종 배치는 Figma와 같음).

## 실패 시나리오

| 상황 | 결과 | 막는 곳 |
|---|---|---|
| 스위치 꺼짐·생성 전 | 행 없음 → 아무것도 없음 | 정상 |
| 카드 JSON 일부 깨짐 | `element`·`title` 문제면 그 카드만 빠짐, `lines`가 목록 아님 → 줄 없이 카드 유지 | Task 1 |
| 기기 바꿈 | 옛 기기 카드 | provider가 기기 id를 `(hasValue,id)` select로 watch, 조회·구독 모두 `device_id` eq(Task 3) |
| 계정 전환 | 이전 계정 카드 | `currentUserProvider` id select-watch(Task 3) |
| 페이지 빨리 넘김 | 늦은 응답이 다른 날에 | family 키 = 날짜/주, 실시간 행도 키 일치할 때만 반영(Task 3) |
| 오늘 페이지 | 일일·실시간 카드 겹침 | 오늘은 일일 provider를 watch하지 않음(Task 5) |
| 주간 차트 조회 실패 | 카드·안내까지 숨음 | 섹션을 차트 상태와 분리(Task 5) |
| 끊김·복귀 | 2차 갱신 놓침 | 재합류 재조회(Task 3) |

## 검증 방법 (구현 전 확정)

- `flutter analyze` 에러 0, `flutter test test/features/home/env_report_test.dart test/features/home/env_report_repository_test.dart test/features/home/env_report_providers_test.dart test/features/home/env_report_cards_test.dart test/features/home/env_alert_card_test.dart test/features/home/env_detail_screen_test.dart test/design/text_scale_overflow_test.dart` PASS, 마지막 `flutter test` 전체.
- iPhone 13 mini 시뮬레이터: ① 운영(빈 테이블)으로 지난 날·주간 화면이 기존과 같은지 ② **미리보기 진입점**(작업 공간에만, 커밋 안 함 — `ProviderScope` override로 리포트 픽스처 주입)으로 A14·A19 상태를 띄워 Figma와 캡처·측정 대조(카드 좌우 16/12, 그래프→카드 22, 차트→카드 12, 카드→습도 차트 36, 칩·글자 수치). 결과는 RESULTS에.
- 실데이터 카드는 서버 3단계 뒤 — **사용자만 확인 가능**(서버 협조).

## Review Focus

1. **그래프와 카드 구간 혼동** → 캡션이 행 구간을 그대로 보인다 → Task 5 `daily_caption_shows_report_window`.
2. **오늘·이번 주는 조회도 하지 않는다** → 진짜 provider + 호출 수 세는 가짜 저장소 → Task 5 `today_does_not_query_daily_report`, `this_week_does_not_query_weekly_report`.
3. **2차 갱신·끊긴 뒤 복귀** → Task 3 `realtime_update_replaces_card`, `rejoin_refetches`.
4. **차트 조회 실패여도 주간 카드는 보인다** → Task 5 `weekly_cards_survive_chart_error`.
5. **ERR_DISCONNECT + 카드** → Task 4 `disconnect_notice_above_card`(완료).

---

### Task 1: 리포트 도메인 — ✅ 완료(r1, 테스트 12)

**Files:** `lib/features/home/domain/env_report.dart`, `test/features/home/env_report_test.dart`

r2 추가:
- `EnvDailyReport`·`EnvWeeklyReport`에 `final DateTime? windowStart; final DateTime? windowEnd;`(timestamptz → `toLocal()`, 파싱 실패 null).
- 테스트 추가: `lines`가 문자열·Map이면 줄 없이 카드 유지, `window_*` 파싱.

### Task 2: 조회 저장소 — ✅ 완료(r1, 테스트 4)

r2 변경(**Produces**):
- select에 `window_start,window_end` 추가.
- `Stream<EnvDailyReport?> watchDaily(String deviceId, DateTime date, {required EnvReportSubscribe subscribe})`, `Stream<EnvWeeklyReport?> watchWeekly(String deviceId, DateTime monday, {required EnvReportSubscribe subscribe})`.
- `typedef EnvReportSubscribe = VoidCallback Function(String table, String deviceId, {required void Function(Map<String, dynamic> row) onRow, required VoidCallback onRejoined});` — 채널은 구독하는 provider의 Ref 수명에 묶어야 해서 저장소가 만들지 않는다(`EnvAlertRepository.watchOpen`과 같은 이유).
- 동작: 구독 먼저 → 조회 → 방출. 실시간 행은 `device_id`와 키(`report_date`/`week_start`)가 같을 때만 파싱해 방출. 같은 값이면 다시 내보내지 않는다(`==`). 처음 조회 실패는 오류 방출(이후 실시간 행이 오면 그 값으로 회복). 재합류 → 다시 조회(실패는 무시, 이전 값 유지).
- 테스트(`env_report_repository_test.dart` 추가): `realtime_update_replaces_card`, `other_date_row_ignored`, `rejoin_refetches`, `first_fetch_error_then_row_recovers`.

### Task 3: provider `envDailyReportProvider`·`envWeeklyReportProvider`

**Files:**
- Create: `lib/features/home/presentation/env_report_providers.dart`
- Test: `test/features/home/env_report_providers_test.dart`

**Context:**
- Depends on: Task 2
- Produces: `final envDailyReportProvider = StreamProvider.autoDispose.family<EnvDailyReport?, EnvDay>`, `final envWeeklyReportProvider = StreamProvider.autoDispose.family<EnvWeeklyReport?, WeekRange>`.
- Must know: 기기는 `currentDeviceIdProvider.select((a) => (hasValue: a.hasValue, id: a.valueOrNull))` — 값 모르면 방출 없는 스트림(로딩), id null이면 `Stream.value(null)`. 계정 `currentUserProvider.select((u) => u?.id)` null이면 `Stream.value(null)`. 구독은 `bindResilientChannel`(이름 `env-daily-$id-$date` / `env-weekly-$id-$monday`, INSERT·UPDATE, filter `device_id eq`). 시간으로 거르지 않는다(D4·D11 — 화면 몫).
- Acceptance: 테스트(진짜 provider, `envReportRepositoryProvider`를 호출 기록하는 가짜로) — (a) 기기 바꾸면 새 기기로 다시 조회 (b) 계정 없으면 null·조회 0회 (c) 기기 모름이면 로딩 유지.

### Task 4: 카드 위젯 — ✅ 완료(r1, 테스트 8 + 기존 실시간 카드 테스트 PASS)

`EnvInsightRow`는 **데이터 클래스**(위젯 아님), `lineLetterSpacing`은 글자 크기 배수(−0.03 = −3%). `EnvAlertCard.rowKey`는 줄 Row에 그대로 붙는다(기존 테스트가 확인). r2 변경 없음 — 안내·카드 별도 면·사이 8은 이미 그렇게 구현했다.

### Task 5: 온습도 상세 배선 + 버전

**Files:**
- Modify: `lib/features/home/presentation/env_detail_screen.dart`, `assets/l10n/ko.json`(`env_report_window` = "{} ~ {} 분석")
- Modify: `test/features/home/env_detail_screen_test.dart`, `test/features/home/env_v4_screen_fixtures.dart`, `test/design/text_scale_overflow_test.dart`
- Modify: `pubspec.yaml`(minor), `CHANGELOG.md`

**Context:**
- Depends on: Task 3, 4
- Must know:
  - 오늘 판정 = `envDetailNowProvider` 값으로 `day.containsNow(now)`, 이번 주 = `!week.end.isAfter(now)`의 반대. 오늘·이번 주면 provider를 **watch하지 않는다**.
  - 일간(지난 날): `ref.watch(envDailyReportProvider(day))` → `.when(skipLoadingOnReload: true, ...)`. 데이터+카드 → 그래프 끝 22 → 캡션(14/500 lh18 `textTertiary`, 좌우 16+12=28 들여 — 각주 위치 규칙) → 8 → 카드(좌우 **16**) → 20 → 제어 기록. 카드 없음·로딩 → 기존 26. 오류 → 22 + `env_report_load_failed` + `InlineRetry`(invalidate) + 20.
  - 캡션 시각 형식 `M/d HH:mm`(로컬, `DateFormat('M/d HH:mm')`), `window_*` 없으면 캡션 생략.
  - 주간: 지난 주면 `ref.watch(envWeeklyReportProvider(week))`를 차트 `rowsAsync`와 **따로** 본다. 레이아웃: 온도 차트(또는 오류·로딩 자리) → [섹션 있으면 12 + 섹션 + 36, 없으면 40] → 습도 차트 → [섹션 있으면 12 + 섹션]. 좌우 12(차트와 같은 Padding). 오류면 첫 섹션 자리에 안내 + 다시 시도 한 번.
  - 픽스처: `envV4DetailOverrides`에 두 provider override(기본 `Stream.value(null)`). 글자 배율 테스트에 "지난 날 일일 카드+캡션", "주간 카드+안내" 추가.
- Acceptance: 테스트

```dart
testWidgets('today_does_not_query_daily_report', ...);      // 진짜 provider + 가짜 저장소: watchDaily 0회
testWidgets('this_week_does_not_query_weekly_report', ...);
testWidgets('지난 날 일일 카드 — 그래프 아래·제어 기록 위, 좌우 16', ...);
testWidgets('daily_caption_shows_report_window', ...);      // "11/2 08:00 ~ 11/3 08:00 분석"
testWidgets('지난 날 행 없음 → 카드·캡션 없음', ...);
testWidgets('daily_report_error_retry', ...);
testWidgets('주간 — 온도·습도 차트 아래 각 섹션, 간격 12/36', ...);
testWidgets('weekly_cards_survive_chart_error', ...);
```

- [ ] 실패 테스트 → 배선 → PASS → 전체
- [ ] 커밋 2개: ① `refactor(env): 온습도 상세 카드 겉모양 공용화(EnvInsightCard)`(patch, 동작 같음) ② `feat(env): 일일·주간 온습도 분석 카드`(minor) — 각각 버전·CHANGELOG

### 마무리

- RESULTS에 시뮬레이터 캡처 대조 + 의도된 차이(D3·D5·D6·D8·D9).
- 질의서에 "③④ 앱 준비(0.167.x) — 3단계는 앱 배포 후" + "다음 날 시각 날짜 표기 요청"(D3) 추가.
