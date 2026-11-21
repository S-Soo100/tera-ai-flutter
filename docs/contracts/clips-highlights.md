# 카메라 영상·플레이어·하이라이트 계약

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

아래 "Final Design 사용자 변경 결정"은 `CLAUDE.md`의 같은 이름 절 전체다. 환기팬 줄은 [사육장 제어 계약](cage-control.md), 온습도 줄은 [온습도 계약](env-telemetry.md)에도 같은 문장이 있다.

## Final Design 사용자 변경 결정 (2026-09-14) — 머리말

이번 결정이 아래 과거 회전 금지/팬 원탭/하루 조회 정책보다 우선한다. 브랜치 `codex/final-design-implementation`; 결과는 `docs/design-audits/2026-09-14-implementation-results.md`.

## 플레이어 방향

카메라 라이브·클립 확대는 세로 진입, 명시 버튼으로 가로 전환. 커뮤니티 플레이어는 이번 변경 범위 밖이다.

## 환기팬 실행 방식

꺼진 환기팬은 시간 선택→시작으로 실행. 선택/취소만으로 명령을 보내지 않는다. 일정 & 타이머 문구는 ‘일정’. → **2026-09-19 사용자 결정으로 홈 진입 문구는 ‘기기 예약 설정’으로 통일**(Figma 1107:10445·예약 화면 제목과 일치, `redesign_home_schedule_settings`).

## 영상 목록 조회

카메라 영상 기본 전체 기간, 60개 복합 커서 pagination, 로컬 썸네일 200MB 캐시. 카메라 상태 갱신이 feed를 초기화하지 않는다.

## 온습도 값

오늘 온습도는 유효한 실시간, 과거는 지표별 valid count를 사용한 평균. 서버 count 미지원은 `--`, 마지막 값/단순 평균 대체 금지.

## 하이라이트 읽음·공개 정책 (정책 v2 포함)

공개 하이라이트 배치의 실제 재생 진전으로 읽음 처리. 공개 배치/시각은 현재 서버 미지원이며 촬영시각을 도착으로 대체하지 않는다. → **예외(2026-09-19 사용자 결정): 카메라 탭 하이라이트 카드는 "업데이트 N일 전"을 표시** — 서버 `published_at`이 있으면 그 값, 없으면 최신 밤 묶음 day_key의 **다음 날**을 올라온 날로 본다(`latestHighlightAtProvider`). **안 본 최신 공개 묶음이 있으면 카드는 "새 하이라이트"**(배너와 같은 읽음 기준·같은 선택 함수 `latestPublishedHighlight`, 재생하면 원래 문구 — 2026-09-19 사용자 결정). 하이라이트 목록 헤더·도착 배너는 기존 규칙 유지. 상세 계약은 `docs/plans/2026-09-14-data-contract-check.md`. → **정책 v2(2026-09-19 사용자 확정, 위 추정·"도착을 만들지 않는다"를 대체):** ① 카메라 탭 전체 영상 목록 = **하이라이트 규칙 O 전부**(petcam-api `/highlights` cursor 페이지 → `PassedClipFeedSource`, 그리드·플레이어 필름스트립 공용 `passedClipFeedSourceProvider`). 미통과 영상은 완전히 숨김(북마크·커뮤니티는 무관). **판정 전 영상은 일단 보여준다**(2026-09-21 사용자 결정, `PendingClipLoader` — 기준점은 가장 최근 통과분 촬영 시각, 맨 위 페이지에만 붙이고 미통과 확정 시 빠진다). **활동시간 = 통과 영상 길이의 합**(2026-09-21 사용자 결정, `PassedClipActivityRepository` — 구 `/activity/intervals`의 "실제 움직인 구간"은 폐기, `HttpActivityRepository`는 계약 디코더로만 존치). ② 하이라이트 = **밤 D 20:00~D+1 08:00 KST만, D+2일 08:00 KST 공개** — 앱이 시간으로 게이트하고 publication을 합성한다(`highlight_night_policy.dart` `applyNightPolicy`, KST=UTC+9 고정 계산). 검수 지연은 기다리지 않는다. ③ 시스템 푸시 `highlight.ready`는 petcam-lab 08:00 작업(0건이면 미발송) — 미배포 동안 앱 안 도착 배너만. SOT `docs/superpowers/specs/2026-09-19-highlight-policy-v2-design.md`. **미결: 어젯밤 리포트의 하이라이트 영역은 현행 유지(기획서 §6).**

## SVG mask·신규 역할색

Final Design runtime SVG의 불투명 alpha mask는 흰 mask로 정규화한다. 원본 export는 보존한다. 신규 역할색은 `envTempValue/envHumidValue`, `envTempPeak/envHumidPeak`, `envBarNeutral/envBarMinimum`, `navSelected/navUnselected`.
