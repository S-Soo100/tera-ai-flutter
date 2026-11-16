# 교차 검수 결과 (Codex + Claude) — 스토어 업데이트 안내·알림 탭 이동 계획 v1

대상: `2026-11-16-store-update-and-push-route.md` v1. 반영본은 v2(같은 파일).

## 요약
- Codex 16건, Claude 15건 / 공통 지적 6건. 반영 후 남은 사용자 결정은 계획서 §6.

## 🔴 2모델 공통 — 수정 완료
1. §1-D(6시간 안 조회 안 함) ↔ §4-2(6시간 안 복귀에 풀림) 모순 → 강제 화면이면 복귀마다 조회 + [다시 확인] 버튼.
2. builder 덮개는 Navigator 밖이라 PopScope로 뒤로가기를 못 막음(Claude: 덮개 아래 화면이 몰래 닫히고 포커스·TalkBack 샘) → 강제 화면을 `/update-required` 라우트 + redirect로 변경.
3. iOS 지원 시 `p_platform: 'android'` 고정(`push_device_repository.dart:31`, 직접 확인) → 플랫폼 값 수정 + 테스트.
4. `showVivaModal`은 취소·바깥 탭·자동 닫힘이 모두 false → [나중에] 버튼 직접 탭만 기록.
5. 예약 알림 탭이 선택보다 이동이 먼저라 다른 사육장 예약이 보임, 내 기기 아니면 엉뚱한 예약 화면 → 선택 먼저, 실패면 홈.
6. `selectNotificationDevice` 재사용 시 계정·세대 재검증 없음 / 함수가 알림 객체만 받음 → id로 일반화 + 계정 id 재확인.

## 🟡 단독 지적
| 지적 | 출처 | 판단 |
|---|---|---|
| Play 서명 유지 검증 전에 `min_build`를 올리면 직접 APK 사용자가 갇힘 | Claude | **채택** — `docs/ops/google-play-account.md`에서 서명 결정·검증 대기 확인. 운영 문서 1번 규칙 |
| 기능 없는 옛 빌드(현 고객 APK)에는 강제가 안 걸림 | Codex | **채택** — 체험 A·운영 문서에 명시 |
| 베타 번들과 정식 iOS가 같은 정책을 씀 | Codex | **채택** — `com.vivanaut.app`만 대상 |
| 새 표에 GRANT SELECT 없음 | Claude | **채택** — 프로젝트 관례(`fcm_notifications.sql:155`) |
| RLS·시드·제약 DB 검증 누락 | Codex | **채택** — 적용 후 anon SELECT·쓰기 거부 확인 |
| iOS `getToken` 전 APNs 토큰 준비 확인 | Codex | **채택** — 짧은 재시도 후 다음 동기화에 맡김 |
| iOS 로컬 탭 콜백 도착은 미확인 | Claude | **채택** — 시뮬레이터 필수 확인 |
| 로그인 직후 redirect보다 먼저 이동해 `/login`이 기록에 남음 | Claude | **채택** — 경로 조건 추가 |
| 강제 중 알림 탭 처리 규칙 없음 | Codex | **채택** — 보관 후 해제 시 처리(라우트 redirect로 이중 차단) |
| 권장 창이 열린 채 강제로 바뀔 때 규칙 없음 | Codex | **채택** — 권장 창 닫기 |
| 재조회 실패 시 강제 화면 유지/해제 미정 | Codex | **채택** — 유지 |
| 업그레이드 전 예약된 팬 알림은 payload 없음 | Codex | **채택(명시만)** — 앱 열면 재동기화로 새 payload |
| `latest_version` 빈 값·빌드 파싱 실패 처리 | Claude | **채택** |
| split-per-abi면 versionCode 가산 | Claude | **채택(확인 항목)** — aapt로 확인 |
| 오프라인으로 강제 우회 가능 | Claude | **사용자 결정으로 넘김**(추천: 캐시 안 함) |
| 서버 route 근거 마이그레이션이 최신 아님 | Claude | **채택** — 인용 교체 |
| iOS 앱 사용 중 FCM 표시에 Darwin 설정 없음 | Claude | **보류** — 체크리스트 항목(plist 생긴 뒤 확인) |
| 실기기 Android/iOS 종료·백그라운드 탭 검증 누락 | Codex | **부분 채택** — iOS는 시뮬레이터, Android 실기기는 사용자 확인 항목 |
| iOS 코드 준비를 통째로 빼자 | Claude ④ | **기각** — 사용자가 "코드만 준비"를 골랐다. 대신 반쪽이 안 되게 플랫폼 값·APNs 대기까지 포함 |

## 💡 직관 질문 답변
- 빼도 되는 것: 6시간 규칙을 단순화 가능(Claude) — 강제 시 매번·그 외 6시간으로 정리해 유지.
- 최대 리스크: Play 서명 검증 전 `min_build` 상향 → 운영 문서 규칙으로 차단.
- 먼저 프로토타입: iOS 시뮬레이터에서 ① plist 없는 Firebase 초기화 ② 로컬 알림 탭 도착 — 구현 첫 단계로 배치.
