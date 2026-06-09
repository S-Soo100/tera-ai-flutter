---
description: 대형 커밋 후 5종 SOT 문서를 코드 실제 상태와 대조하고 불일치를 보고 (승인 후 패치)
---

# /doc-sync — SOT 문서 동기화 점검

코드 변경(특히 도메인 모델/Repository/라우터) 이후 SOT 기획 문서가 코드 실제 상태와 어긋났는지 대조하고, 불일치 목록을 보고한다. **수정은 사용자 승인 후에만.**

## 인자
- `$ARGUMENTS`: 비교 기준 커밋/범위. 비우면 `HEAD~1..HEAD`.

## 대상 SOT 문서 (5종)
- `docs/supabase-schema.md` — DB DDL (메인 15개 + terra-server IoT 테이블)
- `docs/supabase-setup.md` — 테이블 현황 / RLS / 연동 코드
- `docs/spec.md` — 백엔드 / IA(탭) / 기능
- `docs/flutter-cloud-migration-plan.md` — Phase C/D 진행 현황
- `CLAUDE.md` — 프로젝트 개요 / Phase / feature 매핑 / 금지사항

## 절차

### 1. 변경 범위 overview (CAOF 폭주 방지)
- `git diff --stat $ARGUMENTS` (없으면 `HEAD~1`). 한 번에 다 읽지 말고 stat으로 그룹핑.
- 우선 필터: `lib/features/*/domain/`, `lib/features/*/data/`, `lib/core/router/`, `pubspec.yaml`, `assets/l10n/ko.json`

### 2. 영향 문서 매핑
| 변경 파일 패턴 | 점검할 문서 |
|----------------|-------------|
| `domain/*.dart` (모델·enum·wire 값) | supabase-schema.md (DDL) |
| `data/*repository.dart` | supabase-setup.md (테이블·RLS·연동) |
| `lib/core/router/` (라우트·탭) | spec.md §3, CLAUDE.md feature 테이블 |
| 새 feature 폴더 추가/삭제 | spec.md, CLAUDE.md, migration-plan |
| `pubspec.yaml` | CLAUDE.md 스택, migration-plan |

### 3. 대조 + 불일치 보고 (표로)
| 문서 | 항목 | 코드 현재값 | 문서 값 | 수정 필요? |
|------|------|-------------|---------|-----------|

- DDL을 클라이언트 코드에서 역추론할 땐 **불완전**함을 전제로 "Flutter 사용 컬럼 기준"으로 표기하고, 원본 소유처(예: terra-server)를 명시한다.

### 4. 승인 후 패치
- 사용자가 승인한 항목만 Edit. **사실관계만 수정**, 기획/프로세스 구조(섹션 구성·Phase 로드맵)는 보존.
- terra-server IoT 관련은 단일 진실 소스 `~/Downloads/APP_INTEGRATION.md` 우선.

## 원칙
- 수정 전 항상 보고 → 승인. 무단 패치 금지.
- SOT 정확성 > 완전성: 모르는 건 "추정"·"클라 기준"으로 명시, 과대 주장 금지.
- 문서 커밋 메시지는 `docs:` 프리픽스 + 변경 문서 나열.
