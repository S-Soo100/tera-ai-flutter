## Tera AI CAOF 라우팅

이 프로젝트는 CAOF를 따른다. 원본: `/Users/baek/ideaBank/frameworks/claude-agent-orchestration.md`

### 역할 매핑 (에이전트 분리는 Critical 트랙만 — CAOF v1.3)
- **Designer**: 메인 Claude -- 분석/설계/Phase 전환 판단
- **Implementer**: flutter-dev -- Dart/Flutter 구현 (Critical에서 투입, 모델은 상속 기본)
- Standard는 메인이 역할 겸임 (분석서 → 합의 → 직접 구현)

### 적용 트리거
Tera AI 프로젝트 내 코드 변경 요청 시 CAOF 트랙을 판단한다.

### 라우팅 트리

```
Tera AI 요청 수신
├─ 버그/에러/안 돼/크래시 → 메인 Claude 원인 분석 → 직접 수정 (Standard, 진단 먼저)
├─ 새 feature 추가 (새 탭, 새 화면) → Critical 트랙 (풀 GATE)
│   ① 기획서(docs/spec.md) 대조 확인
│   ② 메인 Claude 설계 (파일 구조 + Provider + Repository + 라우트)
│   ③ 사용자 승인
│   ④ flutter-dev 구현
│   ⑤ flutter analyze + 자체 검수
├─ Phase 전환 (P0→P1, P1→P2) → Critical 트랙
│   ① 영향 범위 전수 조사
│   ② 마이그레이션 계획서
│   ③ 사용자 승인
│   ④ flutter-dev 단계별 구현
├─ 새 패키지 도입/버전 조정 → 자유 재량 (사전승인 불필요, 2026-07-08). 되돌리기 비용 사안별 — 대개 Trivial~Standard
├─ 기존 feature 수정/개선 (2~3 파일) → Standard 트랙
│   ① 메인 Claude 변경 범위 분석 + 수정 방향
│   ② 사용자 합의
│   ③ 메인 Claude 직접 구현
├─ Provider/Repository 추가 (기존 feature 내) → Standard
├─ 오타/상수/스타일/문자열 수정 → Trivial (메인 직접)
├─ ko.json 문자열 키 추가 → Trivial
├─ RLS/인증 관련 → Supabase 실연동 완료. 기존 RLS/인증 수정 = Standard, 새 RLS 정책·소셜 로그인 도입 = Critical
└─ 단순 질문 → 메인 Claude 직접
```

### Tera AI 특화 되돌리기 비용 판단

| 변경 유형 | 되돌리기 비용 | 최소 트랙 |
|----------|-------------|----------|
| ko.json 문자열 수정 | < 1분 | Trivial |
| 위젯 스타일/레이아웃 | < 5분 | Trivial |
| Provider 로직 수정 | < 30분 | Standard |
| Repository 데이터 수정 (종 정보, CareInfo) | 중간 (데이터 정확성 검증 필요) | Standard |
| GoRouter 경로 변경 | 중간 (딥링크 영향) | Standard |
| D-day 계산 로직 | 높음 (사용자가 잘못된 날짜를 믿을 수 있음) | Standard |
| 새 feature 폴더 추가 | 높음 (구조 결정) | Critical |
| pubspec.yaml 패키지 추가/버전 | 낮음~중간 (빌드 확인) | 자유 재량 |
| Phase 전환 | 매우 높음 | Critical |

### Designer 분석 시 필수 확인 (메인 Claude)

**데이터 정확성:**
- 파충류 사육 정보(온도, 습도, 먹이)는 생명과 직결. 데이터 수정 시 반드시 출처 확인.
- D-day 계산: DateTime(2026, 6, 13) 기준. timezone, 0시 기준 등 엣지케이스.

**Phase 경계 (2026-06-09 갱신):**
- P0 "로컬 전용/인증 없음" 제약은 **해제됨** — Supabase 인증·유저 CRUD + terra-server 사육장 IoT 실연동 완료.
- 현재 유효 경계: Phase C/D(게코캠 마이그레이션 petcam-lab + 5탭 UI 안정화) + terra-server IoT 기능 확장. 소셜 로그인(Apple/Google/Kakao)·FCM은 후속.
- 미구현 placeholder(onboarding/profile/notification)는 기획 확정 전 구현 금지. auth는 Email 인증 구현 완료(예외).
- terra-server IoT 작업 전 단일 진실 소스 `~/Downloads/APP_INTEGRATION.md` 확인.

**Riverpod 패턴:**
- 새 Provider 추가 시 기존 Provider와 의존 관계 확인
- StateNotifier vs Notifier(Riverpod 2.0) 선택 일관성

### Designer 겸임 보완 (메인 Claude)

Standard 이상 트랙에서:
1. 구현 후 flutter analyze 에러 0 확인
2. Riverpod Provider 의존 관계 순환 없는지 확인
3. 새 화면이면 GoRouter 등록 + 네비게이션 테스트
