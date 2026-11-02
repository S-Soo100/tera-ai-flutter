# 교차 검수 결과 (Codex + Claude) — v4 앱 1단계 계획

대상: `docs/superpowers/plans/2026-11-02-env-alerts-v4-app.md` (`35ae053` 시점). 2026-11-02.
검수자에게는 목표와 계획만 줬다(Claude는 계획이 가리키는 심볼 존재 확인용으로 코드 읽기 허용).

## 요약
- Codex: 26건, Claude: 25건 / 공통 지적: 11건
- 메인이 직접 확인한 Claude 단독 주장: `notification_events_type_check` 제약 존재(`20260916000000…sql:11`), 우선순위 CASE는 `claim_notification_outbox`(`20260915000000…sql`), `deviceListProvider`는 1회 조회(`supabase_module_providers.dart:31`), 알림함 카테고리 목록·Android 채널에 `env` 없음(`notification_center_screen.dart:141`, `firebase-message.mjs:24`) — 모두 사실.

## 🔴 2모델 공통 — 수정
| # | 지적 | 반영 |
|---|---|---|
| 1 | D1: 펌웨어 기본 −1.5 때문에 새 기기도 "보정 켜짐 −1.5"로 보임 → 체험 4·6, Task 4 픽스처 모순. 회신이 "공장값에 더해서"면 `toDeviceValue` 외에 꺼짐 판정·표시·반영 비교도 바뀜 | 체험·픽스처를 D1에 맞게 다시 씀. 영향 범위를 `TempOffset` 한 파일 4곳으로 명시. 보정 Task를 맨 뒤로 |
| 2 | 보정 저장 확인: 15초 시간 초과에도 보낸 값을 표시, 끄기 확인 절차 없음, 구독 준비 순서·같은 값·중복 저장 미정 | 1차 판정 = REST 응답 `{id}`의 commands 행 `result == ok`, 보조 = `temp_offset_c` 일치. 끄기도 같은 흐름. 오프라인이면 저장 막음 |
| 3 | 현재 측정 온도 = `t_a − offset`을 서로 다른 갱신 시점 값으로 계산 | 새 텔레메트리가 올 때까지 이전 계산값 유지, 오래된 값이면 흐리게 |
| 4 | 기존 보정값이 ±4℃를 넘으면 편집기·`TempOffset.of`가 깨짐 | `fromSigned`는 throw하지 않고 "범위 밖" 상태. 화면은 값 표시 + 편집 시 4.0으로 맞춤 |
| 5 | Task 3이 Task 7(`envAlertPrefsProvider`)·Task 4·5 화면에 기대는데 의존성에 없음 | Task 순서를 1→2→7→5→3→6→8→9→4로 바꾸고 의존성 수정 |
| 6 | 이탈 알림 토글 저장·실패 원복·연속 조작 미정 | 필드 하나씩 upsert, 실패 시 원복, 테스트 추가 |
| 7 | Task 6 Realtime: 최초 조회와 구독 사이·재연결·앱 복귀 시 놓친 변경 | `bindResilientChannel` + `onRejoined` 재조회, 저장소 테스트 추가 |
| 8 | "푸시는 타이틀만"과 Task 8 본문 생성이 충돌 | 푸시 body는 빈 문자열이 아니라 기기 이름만(제목은 서버 title). Global에 "알림 본문 = 사육장 이름" 명시 |
| 9 | 푸시 탭이 `/env-detail`만 열어 다른 사육장 화면으로 감 | `payload.device_id`로 `selectedHomeDeviceIdProvider` 전환 후 이동 |
| 10 | 스텝에 안 맞는 기존 저장값(18.3)이면 저장이 영영 비활성 | 읽을 때 스텝에 맞춤(`fromSettings`가 반올림까지) |
| 11 | 검증 명령 목록 누락(Task 2·7 테스트, app_notification, env_detail, 마이그레이션 테스트) / N2 근거 Task가 문서마다 다름 | 목록 정리, N2 근거는 Task 1·5로 통일 |

## 🟡 단독 지적
| 출처 | 지적 | 판단 |
|---|---|---|
| Claude | `notification_events_type_check` CHECK 제약 미변경 → INSERT 실패, CASE에 ELSE 없음 | **채택** — DROP/ADD 명시 |
| Claude | 계약 수정 후 `notification-ingest` 재배포 단계 없음, 202 duplicate는 SQL로 못 봄 | **채택** — 순서 고정: 마이그레이션 → ingest 재배포 → 서버 회신 |
| Claude | 우선순위 CASE 위치는 `claim_notification_outbox` | **채택** |
| Claude | `Device`는 1회 조회라 저장 후 `tempOffsetC`가 안 바뀜 | **채택** — 보정 화면은 전용 구독(`deviceOffsetProvider`), 저장 후 `deviceListProvider` invalidate |
| Claude | 수신 끔 SQL 기본값·위치 미정 | **채택** — `notification_event_after_insert` outbox INSERT 직전 `COALESCE(pref, true)` |
| Claude | 주의→경고 시 행이 새로 생기는지 | **확인됨(서버 문서 §1)** — 기존 행 종료 후 새 행, 시각 같음. 지표별 열린 행 최신 1개만 그린다 |
| Claude | 체험 1의 "바 양끝 = 최저·최고"와 Task 6 "전체 바 12~30" 표현 불일치, 예시 18~24 | **채택** — 바는 12~30(습도 20~100) 고정, 양옆 숫자가 최저·최고 |
| Claude | 카테고리 `env` 알림함 "기타", Android 채널 기본 | **채택** — 두 파일 추가 |
| Claude | iOS FCM 미지원 | **채택** — 푸시는 Android 한정 명시 |
| Claude | payload `kind`가 data.kind 덮어씀 | **채택(주석)** — 앱은 컬럼 kind 사용 |
| Claude | 버전·CHANGELOG를 Task 9에 몰아둠 | **채택** — lib 변경 Task마다 같은 커밋 |
| Claude | Task 7 옛 문구, 테이블 존재 재확인, `updated_at` 갱신 | **채택** — `to_regclass` 확인, 앱이 `updated_at` 전송 |
| Claude | 지난 날 범위 바에 현재 적정 범위를 그림 | **기각(기록)** — Figma A14가 지난 날에도 적정 구간을 그린다. RESULTS에 "현재 기준" 차이로 기록 |
| Claude | `/env-detail` 자식 라우트면 알림 설정에서 push 시 부모가 쌓임, `firstEntry` 딥링크 유실 | **채택** — 최상위 `/temp-humid-settings`, `firstEntry`는 저장 상태로 계산 |
| Claude | `rawFrom` static 불일치, `EnvRange`를 home에 두면 my_cage가 home을 import | **채택** — `lib/shared/domain/env_thresholds.dart` |
| Codex | 편집 중 홈 세트가 바뀌면 다른 기기에 저장 | **채택** — 화면 진입 시 기기 id 고정 |
| Codex | PATCH 뒤 provider 무효화 미명시 | **채택** — `deviceSettingsProvider(id)` invalidate |
| Codex | 습도 가이드 "즉시 알림" 문구가 실제(2분)와 다름 | **보류(사용자 결정)** — Figma 문구 그대로 두고 RESULTS·기획자 질의 |
| Codex | 끄기 전에 쌓인 미발송 outbox 처리 | **기각** — outbox는 수 초 안에 비워진다. "끈 뒤 새로 생기는 알림부터"로 문서에 명시 |
| Codex | 실기기 검증이 서버 스위치 뒤로 밀림 | **부분 채택** — 보정 명령 실측(실기기 1대)을 사용자 승인 하에 Task 4 착수 전 수행 |

## 💡 직관 질문 답변
- **뺄 수 있는 것:** 보정(Task 4와 Task 3의 보정 토글). D1·Q1이 미결이라 다시 만들 가능성이 크다 → 맨 뒤로 미루고, 끄기 전송은 사용자 재확인.
- **최대 리스크:** "끔 = 0 전송"이 펌웨어 공장값 −1.5를 지워 그 기기의 모든 온도가 +1.5℃ 바뀌는 것. 판정·푸시 기준이 같이 움직이고 크레스티드는 29℃ 부근이 치명적이다.
- **먼저 프로토타입:** 실기기 1대에 REST `set_temp_offset`을 보내 거부 여부·`commands.result`·`temp_offset_c`·`t_a` 변화 시점과 −1.5 관계를 실측.
