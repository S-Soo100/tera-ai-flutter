## 비바나트 CAOF 사례

트랙 기준·라우팅·실패 제한·보고 형식은 글로벌 `~/.claude/CLAUDE.md` 그대로다(파일 4개 이상·새 시스템·외부 의존성이면 Critical, 판단 기준은 줄 수가 아니라 실패 시 되돌리기 비용). 이 파일은 이 프로젝트에서 헷갈리기 쉬운 사례와 역할 매핑만 적고, 기준을 바꾸지 않는다. 원본: `/Users/baek/ideaBank/frameworks/claude-agent-orchestration.md`.

### 역할 매핑 (에이전트 분리는 Critical 트랙만)
- **Designer**: 메인 Claude — 분석·설계·Phase 전환 판단
- **Implementer**: `flutter-dev` — Dart/Flutter 구현 (Critical에서 투입, 모델은 상속)
- Standard는 메인이 겸임한다(분석서 → 합의 → 직접 구현).
- 사용자가 "CAOF 끄기"라고 하면 그 세션에서 끈다.

### 트랙 사례
- **Critical**: 새 feature(새 탭·새 화면·새 feature 폴더), Phase 전환, 새 RLS 정책·소셜 로그인 도입. 기존 기능이라도 파일 4개 이상에 걸치면 Critical이다 — 동작이 바뀌지 않는 정리·삭제도 같다(2026-11-21 사용자 결정으로 글로벌 기준에 맞춤).
- **Standard**: 기존 feature 수정·개선(2~3 파일), 새 위젯, Provider·Repository 추가나 로직 수정, GoRouter 경로 변경(딥링크 영향), Repository 데이터 수정(종 정보·CareInfo — 정확성 검증 필요), 기존 RLS·인증 수정, 버그 수정(진단 먼저).
- **Trivial**: 오타·상수·스타일·레이아웃 수정, ko.json 문자열 수정·키 추가.
- 패키지 추가·버전 조정은 트랙과 별개로 재량이다(사전 승인 불필요, 빌드 확인).

### Critical에서 이 프로젝트가 더하는 단계
- 새 feature: 기획안(`docs/prd-vivanaut-app.md`)과 CLAUDE.md "기획·디자인 기준" 대조 → 설계(파일 구조 + Provider + Repository + 라우트) → 사용자 승인 → `flutter-dev` 구현 → `flutter analyze` + 자체 검수.
- Phase 전환: 영향 범위 전수 조사 → 마이그레이션 계획서 → 사용자 승인 → 단계별 구현.

### 분석할 때 필수 확인 (메인 Claude)
- **규칙 파일**: Standard 이상 분석서를 쓰기 전에 CLAUDE.md "문서 색인"에서 관련 `.claude/rules/*.md`를 직접 읽는다(경로 규칙은 그 파일을 열 때만 실린다).
- **데이터 정확성**: 파충류 사육 정보(온도·습도·먹이)는 생명과 직결된다. 데이터를 고칠 때는 출처를 확인하고, 온습도·안심존·목표값에 임의 수치나 기본값을 채우지 않는다.
- **서버 계약**: terra-server IoT 작업 전 `~/Downloads/APP_INTEGRATION.md`(레포 밖. §3.2 표는 toggle만 적혀 있어 불완전)와 CLAUDE.md "서버 쓰기 경로"를 확인한다.
- **현재 경계**: Supabase 인증·유저 CRUD, terra-server 사육장 IoT, 4탭 UI가 운영 중이다. onboarding은 기획 확정 전 구현하지 않는다.
- **Riverpod**: 새 Provider를 추가하면 기존 Provider와의 의존 관계와 순환을 확인하고, StateNotifier와 Notifier 선택을 주변 코드와 맞춘다.
- **구현 뒤**: `flutter analyze` 에러 0, 새 화면이면 GoRouter 등록과 네비게이션 테스트.
