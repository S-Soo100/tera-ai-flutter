# AGENTS.md — AI 에이전트 공용 진입점 (비바나트 Flutter)

> **규칙의 단일 출처는 [`CLAUDE.md`](CLAUDE.md)다.** 이 파일은 진입 안내와 Codex 전용 설정만 둔다.
> (2026-06-13: CLAUDE.md 복사본 → 포인터로 전환. 이전 복사본은 "P0 로컬 전용·인증 없음" 같은 폐기된 상태 정보를 담고 있었음 — 복사본 드리프트의 실사례)

## 한 줄 요약

파충류 사육자 Flutter 앱 — 사육장 IoT 제어 / 카메라 라이브·영상 / 개체 관리 / 커뮤니티.
스택: Flutter + Riverpod + GoRouter + Supabase. **구조·기획 기준·서버 쓰기 경로는 [`CLAUDE.md`](CLAUDE.md)가 SOT.**

## 너가 어떤 AI인지에 따라

- **Claude (Claude Code)** → [`CLAUDE.md`](CLAUDE.md) 자동 로드. 이 파일은 보조.
- **Codex / ChatGPT (codex CLI)** → [`CLAUDE.md`](CLAUDE.md)를 읽고 그대로 따른다. 특히:
  - 코딩 규칙 (앱·서버 상태는 Riverpod / Repository 패턴 / 하드코딩 색상·문자열 금지 / CircularProgressIndicator 금지)
  - "파일을 열기 전에 알아야 하는 함정"과 "서버 쓰기 경로" 표
  - **기능별 규칙은 자동으로 실리지 않는다.** 작업할 기능의 `.claude/rules/*.md`를 CLAUDE.md "문서 색인"에서 찾아 **직접 읽고** 따른다(Claude Code는 해당 경로 파일을 열 때 자동으로 싣지만 Codex는 그렇지 않다)
  - 패키지 설치·버전 조정은 재량(사전 승인 불필요)
  - CAOF 트랙 규칙 + 상세 라우팅: [`.claude/rules/vivanaut-caof.md`](.claude/rules/vivanaut-caof.md)
  - 검증 기준: `flutter analyze` 에러 0
- **기타 도구** → CLAUDE.md + `docs/prd-vivanaut-app.md`(기획안).

Codex 전용 설정(.toml)은 `.codex/`. 규칙 본문은 CLAUDE.md가 유일하고, 아래 Codex 전용 절만 예외다.

## 변경 시 규칙

규칙 수정은 CLAUDE.md(와 `.claude/rules/`)만. 이 파일에 복사 금지 (드리프트 방지). Codex 전용 절은 이 파일에서 고친다.

## Codex 전용: 서브에이전트 모델 (2026-09-15 사용자 지정, 2026-11-21 CLAUDE.md에서 옮김)

**이 규칙은 ChatGPT/Codex 세션에만 적용한다. Claude Code 세션에는 해당 없음** — Claude는 기존 CAOF 기본(서브에이전트 모델 상속, `Agent` 도구의 model 파라미터는 지정하지 않음)을 따른다. `gpt-5.6-terra`는 Claude가 호출할 수 없는 모델이므로 Claude 세션에서 이 절을 근거로 모델을 바꾸거나 작업을 중단하지 않는다.

- (ChatGPT/Codex 한정) 이 프로젝트에서 서브에이전트를 호출할 때는 역할과 관계없이 **`gpt-5.6-terra` / reasoning effort `medium`**을 명시한다. 메인 에이전트 모델은 변경하지 않는다.
- (ChatGPT/Codex 한정) `spawn_agent`는 모델 오버라이드를 전달할 수 있도록 `fork_turns="none"` 또는 필요한 최근 턴 수를 지정하고, 작업 맥락·담당 범위·결정사항을 프롬프트에 전달한다.
- (ChatGPT/Codex 한정) 지정 모델을 사용할 수 없으면 임의로 다른 모델로 대체하지 말고 사용자에게 알린다.
- (ChatGPT/Codex 한정) 이 규칙은 기존 문서의 ‘모델 상속 기본’보다 우선하며, 서브에이전트 사용 여부는 기존 CAOF 트랙 규칙을 따른다.
