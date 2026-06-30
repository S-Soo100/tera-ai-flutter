# AGENTS.md — AI 에이전트 공용 진입점 (Tera AI Flutter)

> **규칙의 단일 출처는 [`CLAUDE.md`](CLAUDE.md)다.** 이 파일은 진입 안내만 한다.
> (2026-06-13: CLAUDE.md 복사본 → 포인터로 전환. 이전 복사본은 "P0 로컬 전용·인증 없음" 같은 폐기된 상태 정보를 담고 있었음 — 복사본 드리프트의 실사례)

## 한 줄 요약

파충류 사육자 올인원 Flutter 앱 — 백색목록 검색 / 모프 계산기 / 게코캠 / 사육장 IoT.
스택: Flutter + Riverpod + GoRouter + Supabase. **현재 Phase·구현 상태는 [`CLAUDE.md`](CLAUDE.md) "프로젝트 개요"가 SOT.**

## 너가 어떤 AI인지에 따라

- **Claude (Claude Code)** → [`CLAUDE.md`](CLAUDE.md) 자동 로드. 이 파일은 보조.
- **Codex / ChatGPT (codex CLI)** → [`CLAUDE.md`](CLAUDE.md)를 읽고 그대로 따른다. 특히:
  - 코딩 규칙 (Riverpod만 / Repository 패턴 / 하드코딩 색상·문자열 금지)
  - 금지 사항 섹션 (dio 금지, 새 패키지는 사용자 승인, CircularProgressIndicator 금지 등)
  - CAOF 트랙 규칙 + 상세 라우팅: [`.claude/rules/tera-ai-caof.md`](.claude/rules/tera-ai-caof.md)
  - 검증 기준: `flutter analyze` 에러 0
- **기타 도구** → CLAUDE.md + `docs/spec.md`.

Codex 전용 설정(.toml)은 `.codex/`. 규칙 본문은 CLAUDE.md가 유일.

## 변경 시 규칙

규칙 수정은 CLAUDE.md만. 이 파일에 복사 금지 (드리프트 방지).
