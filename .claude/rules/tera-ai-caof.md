## Tera AI CAOF 라우팅

이 프로젝트는 CAOF를 따른다. 원본: `/Users/baek/ideaBank/frameworks/claude-agent-orchestration.md`

### 역할 매핑
- **Designer**: 메인 Claude (opus) -- 분석/설계/Phase 전환 판단
- **Implementer**: flutter-dev (sonnet) -- Dart/Flutter 구현

### 적용 트리거
Tera AI 프로젝트 내 코드 변경 요청 시 CAOF 트랙을 판단한다.

### 라우팅 트리

```
Tera AI 요청 수신
├─ 버그/에러/안 돼/크래시 → 메인 Claude 원인 분석 → flutter-dev 수정 (Standard)
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
├─ 새 패키지 도입 → Critical (pubspec.yaml 변경 = 되돌리기 비용 높음)
├─ 기존 feature 수정/개선 (2~3 파일) → Standard 트랙
│   ① 메인 Claude 변경 범위 분석 + 수정 방향
│   ② 사용자 합의
│   ③ flutter-dev 구현
├─ Provider/Repository 추가 (기존 feature 내) → Standard
├─ 오타/상수/스타일/문자열 수정 → Trivial (flutter-dev 직행)
├─ ko.json 문자열 키 추가 → Trivial
├─ RLS/인증 관련 (P2 예정) → 현재 Phase에서 구현 금지, 보고만
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
| pubspec.yaml 패키지 추가 | 높음 (빌드 영향) | Critical |
| Phase 전환 | 매우 높음 | Critical |

### Designer 분석 시 필수 확인 (메인 Claude)

**데이터 정확성:**
- 파충류 사육 정보(온도, 습도, 먹이)는 생명과 직결. 데이터 수정 시 반드시 출처 확인.
- D-day 계산: DateTime(2026, 6, 13) 기준. timezone, 0시 기준 등 엣지케이스.

**Phase 경계:**
- P0에서 P1/P2 기능을 구현하려는 시도를 차단. placeholder는 placeholder로 유지.
- "나중에 Supabase로 교체할 거니까 미리..." → 지금은 로컬 전용. Repository 인터페이스만 깔끔하게.

**Riverpod 패턴:**
- 새 Provider 추가 시 기존 Provider와 의존 관계 확인
- StateNotifier vs Notifier(Riverpod 2.0) 선택 일관성

### Designer 겸임 보완 (메인 Claude)

Standard 이상 트랙에서:
1. 구현 후 flutter analyze 에러 0 확인
2. Riverpod Provider 의존 관계 순환 없는지 확인
3. 새 화면이면 GoRouter 등록 + 네비게이션 테스트
