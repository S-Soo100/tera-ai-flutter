# 마이페이지 재설계 — 서버 의존 항목 요청 (2026-09-16)

앱은 Figma 마이페이지 섹션(`1142:8859`) 7화면을 구현했다(0.111.0+276). 아래 셋은
서버 쪽이 붙어야 실제로 동작한다. 앱은 각 항목의 "지금 동작"대로 안전하게
실패한다.

| # | 항목 | 앱 구현 | 지금 동작 | 서버 요청 |
|---|---|---|---|---|
| C2 | 사육 경험 비공개 | `user_profiles.experience_hidden` 읽기/쓰기 — 응답에 키가 있을 때만 | 컬럼 없음 → 체크가 저장되지 않음(400 방지) | 앱 팀 마이그레이션 [`supabase/drafts/20260916_user_profiles_experience_hidden.sql`](../../supabase/drafts/20260916_user_profiles_experience_hidden.sql) 검토·적용 |
| C4 | 알림 종류별 on/off·수신 동의 | 화면 + Hive 로컬 저장(`notif_pref_*`) | 기기 안에서만 유지, 발송을 막지 못함 | 테이블 [`supabase/drafts/20260916_notification_preferences.sql`](../../supabase/drafts/20260916_notification_preferences.sql) + `dispatch-push`가 발송 전 조회. 적용되면 앱 저장처를 서버로 교체 |
| C6 | 회원 탈퇴 | `functions.invoke('delete-account')` → 성공 시 로그아웃 | 함수 없음 → "회원 탈퇴 처리가 아직 준비되지 않았습니다" 스낵바 | Edge Function `delete-account`(service role): ① 기기 `unlink`(MQTT 계정 회수, terra-server) ② 앱 팀 테이블 CASCADE ③ `auth.admin.deleteUser`. 이관훈님과 순서 합의 필요 |

비밀번호 변경(C5)은 서버 변경 없이 `signInWithPassword`(현재 비밀번호 검증) →
`updateUser(password)`로 동작한다. 버전 정보의 최신 판정(C7)은 원격 설정이 없어
현재 버전 표시만 한다.
