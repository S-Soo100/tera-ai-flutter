# 교차 검수 결과 (Codex + Claude)

- 대상: `docs/superpowers/plans/2026-11-10-camera-focus-notice.md` (r1, 커밋 90582cd5)
- 일시: 2026-11-10. Codex(ChatGPT 구독 CLI, 자유 관점) + Claude 서브에이전트(4렌즈, 새 컨텍스트)
- 반영본: 같은 계획서 r2

## 요약
- Codex 8건, Claude 17건 / 공통 지적 5건
- 결론: 운영 트리거 교체를 빼고, 운영자가 `app_notifications`에 직접 1행을 넣는다(Claude 3렌즈 제안, 메인이 DB에서 확인). 이에 따라 트랙을 Critical에서 Standard로 내린다.

## 🔴 2모델 공통 — 수정
1. **운영 적용 위치가 서로 다름**(헤더 "Task 1 마지막" / 사용자 결정 "Task 1 Step 6" / 실제 Task 6) → r2에서는 마이그레이션 자체가 없어 해소.
2. **마이그레이션 테스트가 약함**(`includes` 검사뿐, 기존 `assertKeepsEveryLine` 관례 미사용) → 마이그레이션 제거로 해소.
3. **ingest 계약만 고치고 재배포 단계가 없음** → 계약 변경을 범위에서 뺌(발송 경로는 SQL).
4. **구버전 앱이 route `/crecam`으로 카메라 탭을 연다는 전제가 틀림**(모르는 kind는 `safeRoute`가 `/notifications`로 보냄, `app_notification.dart:64~66`) → `/crecam` 허용 추가 삭제.
5. **읽음 처리 범위·실패 처리 불일치**(Codex: markRead 실패 시 숨김이 남아 배지와 어긋남 / Claude: "다음 진입 때 다시 뜬다"가 사실과 다름) → 실패한 id는 숨김 집합에서 다시 빼서 스낵바가 돌아오게 함. 알림함 열기도 초점 안내 전부를 읽음 처리.

## 🟡 단독 지적 — 채택/기각
| 출처 | 지적 | 판단 |
|---|---|---|
| Claude | 운영 트리거를 바꾸지 않고 `app_notifications` 직접 INSERT 가능(트리거·kind CHECK 없음) | **채택** — 메인 확인: 제약은 data object·PK·UNIQUE(user_id, dedupe_key)·FK뿐, 트리거 없음. 잃는 것은 `notification_events` 기록 하나 |
| Claude | 홈에서 `notificationsProvider`를 보면 알림 전체를 limit 없이 실시간 구독(지금은 알림함·마이페이지만) | **채택** — 메인 확인: 계정당 최대 1,099행, 중앙값 16.5. 초점 안내만 kind로 거르는 좁은 stream을 따로 둠 |
| Claude | 홈 헤더 알림 배지는 없음(마이페이지 알림 점뿐) | **채택** — 메인 확인: `profile_screen.dart:50`만 구독. 시뮬레이션 문구 수정 |
| Claude | `!offline`만으로는 실패·제한·연결 중 화면의 버튼을 가림 | **채택** — streaming·stalled일 때만 노출 |
| Claude | 카메라 0대일 때 셸 밖 `/notifications`에서 `push('/crecam')`은 셸 중복 위험 | **채택** — `go('/crecam')` |
| Claude | 기존 home·my_cage 위젯 테스트가 Supabase에 닿을 수 있음 | **채택** — 테스트에서 `focusNoticeVisibleProvider` override |
| Claude | 알림함 "모두 읽음"도 스낵바를 지움 | **채택(의도된 동작으로 명시)** |
| Claude | 위쪽 다른 표시(이름 배지·status·알약)와 겹침 확인 없음 | **채택** — 대조표 항목 추가 |
| Claude | 운영자 SQL 이메일 오타면 조용히 0행 | **채택** — `INSERT 0 1` 확인 단계 |
| Claude | 가짜 store 참조 파일 오류 | **채택** — `notification_repository_test.dart` |
| Claude | 가이드(Task 5)는 독립·저위험이라 먼저 병합 | **채택** — 순서를 맨 앞으로 |
| Codex | `node --test 폴더/`는 MODULE_NOT_FOUND | **채택** — 메인 확인: `*.test.mjs` 형태로 통과. r2에서는 node 테스트 변경 없음 |
| Codex | 운영자 SQL 접근 여부 미확정 | **유지(사용자 확인 항목)** |

## 💡 직관 질문 답변
- **삭제해도 되는 것:** 운영 트리거·ingest 계약 변경. 운영자 수동 발송이면 `app_notifications` 1행으로 충분하다.
- **최대 리스크(r1):** 모든 알림이 같이 쓰는 운영 트리거 교체 → r2에서 제거. **남은 리스크:** RLS가 걸린 상태에서 kind 필터 Realtime이 정상 수신되는지 → 프로토타입으로 먼저 확인.
- **먼저 할 것:** 운영자 본인 계정에 1행을 넣고 시뮬레이터에서 실시간 수신·노출·읽음·다른 기기 소멸을 확인한다. 가이드(Task 1)는 그와 별개로 먼저 병합한다.
