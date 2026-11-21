# git-hooks

버전 관리 가드 훅. 추적되는 `tools/git-hooks/`에 두고 `core.hooksPath`로 활성화한다.

## 활성화 (fresh clone마다 1회)

```bash
git config core.hooksPath tools/git-hooks
chmod +x tools/git-hooks/*
```

## pre-push

`lib/**` 코드 변경을 push하는데 `pubspec.yaml`의 `version:`이 안 올랐으면 push를 차단한다.

**전제 — 커밋 시 변경 규모를 판단해 버전을 올린다** (conventional commits 기준):

| 커밋 타입 | bump | 비고 |
|----------|------|------|
| `fix:` / `perf:` / `refactor:` | patch (Z+1) | |
| `feat:` | minor (Y+1, Z=0) | |
| `feat!:` / `BREAKING CHANGE` | major (X+1) | |
| (모든 경우) | 빌드번호 `+N` +1 | |

훅은 직접 bump하지 않는다(pre-push 시점엔 commit을 끼워넣을 수 없음). "버전 안 올리고 push" 사고를 막는 가드일 뿐.

- 의도적 우회: `git push --no-verify`
- docs/chore/style 등 `lib/` 무변경 push는 버전 없이 통과.

### 재설계 기준선 가드 (2026-09-18)

push하는 **브랜치**가 Figma 재설계 병합 커밋 `81a5f25`(0.111.4+280)를 포함하지 않으면 차단한다.
재설계 이전 main에서 갈라진 브랜치를 push·병합하면 화면이 구버전으로 돌아가기 때문이다
(재설계 138커밋이 별도 worktree에만 있어 main 빌드가 구화면이던 사고의 재발 방지). 태그(`archive/*` 등)는 검사하지 않는다.

- 해결: `git merge main` 또는 main 기준으로 브랜치 재생성
- 의도적 우회: `git push --no-verify`

## post-checkout

브랜치를 체크아웃했는데 위 기준선이 없으면 **경고만** 출력한다(차단 없음). 구브랜치·worktree로 앱을 빌드하기 전에 알아채기 위함.

### 버전 역행 가드 (2026-09-18)

push 후 빌드번호(`version: X.Y.Z+B`의 B)가 원격보다 **낮아지면** 차단한다. 옛 코드로 되돌리는 push는 거의 항상 pubspec 버전도 함께 되돌리기 때문이다. 해결: `git merge origin/main` 후 다시 push. 우회: `git push --no-verify`.

## 테스트 가드 — `test/regression/redesign_baseline_guard_test.dart`

재설계 핵심 파일·표지(로그인 로고, 스플래시, 폐지된 옛 위젯 부재, 버전 하한 +280)를 검사한다. 옛 브랜치 병합으로 화면이 되돌아가면 실패해 커밋(테스트 통과 필수)이 막힌다. 재설계 이전 스냅샷(`1389e8e`)에서 3건 모두 실패함을 확인했다.

## 복원 지점

`stable/redesign-2026-09-18` 태그 = 재설계 병합 + 후속 수정이 모두 반영된 확인 완료 지점. 최악의 경우 이 태그에서 브랜치를 만들어 복구한다.

## 브랜치 규칙 원문 (CLAUDE.md에서 옮김)

`CLAUDE.md`(커밋 `5675f3b2`)의 해당 문단을 문장 그대로 옮겼다(2026-11-21, CLAUDE.md 축소 2단계). 사고 경위, 보관 태그(`archive/*`) 목록, Clarity 보류 결정이 들어 있다.

**⚠️ 브랜치 규칙 (2026-09-18 사고 후 확정):** 재설계는 `81a5f25`(0.111.4+280)로 **main에 병합됐고 main이 유일한 기준**이다. 재설계 138커밋이 별도 worktree 브랜치에만 있어 main 빌드가 구화면으로 보인 사고가 있었다. ① 새 작업 브랜치·worktree는 **반드시 현재 main에서** 만든다 ② 작업 브랜치는 오래 두지 말고 끝나면 즉시 main에 병합·삭제한다(화면 확인은 main 빌드로) ③ `tools/git-hooks/pre-push`가 `81a5f25`를 포함하지 않는 브랜치 push와 **빌드번호 역행 push**를 **차단**하고, `post-checkout`이 경고한다 ④ `test/regression/redesign_baseline_guard_test.dart`가 재설계 핵심 파일·표지를 감시한다 — 화면을 의도적으로 바꿀 땐 목록을 고치되 **지워서 우회하지 말 것** ⑤ 복원 지점 태그 `stable/redesign-2026-09-18`. 정리된 옛 브랜치는 `archive/*` 태그로 보관(`codex/figma-redesign-20260915`, `feat/prd-redesign`, `feat/highlights-petcam-api`, `feat/knowledge-graph-layer`). **Clarity 분석(`archive/codex/clarity-policy`, 커밋 `9dfea3b`)은 사용자 결정으로 통째 보류** — main에 없는 재설계 이전 구현이다. **기본 SDK(`2ee69d8`)는 main에 있었으나 동의·마스킹 없이 전 빌드에서 수집 중이어서 2026-09-25 꺼 두었다**(0.134.2, `main.dart`에서 `ClarityWidget` 제거 — 패키지·`clarity_setup.dart`는 존치). 재개 시 정책 커밋은 재설계 전 화면 21개에 이벤트를 심어 충돌이 크므로 cherry-pick하지 말고, 뼈대(`core/analytics/` 신규 12파일)만 가져오고 이벤트 지점·마스킹(로그인·비밀번호·Wi-Fi 입력 포함)은 현재 화면 기준으로 다시 설계한다.

## 병렬 세션 작업 규칙 원문 (CLAUDE.md에서 옮김)

`CLAUDE.md`(커밋 `5675f3b2`)의 문단을 문장 그대로 옮겼다(2026-11-21). 도구는 `tools/worktree.sh`.

**병렬 세션 작업 규칙 (2026-09-24):** 한 폴더를 여러 세션이 공유하지 않는다. 세션마다 `tools/worktree.sh new <type>/<이름>`으로 최신 main에서 `../tera-ai-flutter-<이름>` 작업 공간을 만들고(`.env` 링크·`pub get` 자동), 끝나면 `tools/worktree.sh finish <branch>`로 main 병합·push·정리한다. 메인 폴더(`tera-ai-flutter`)는 main 확인·병합용으로 비워 둔다. **버전 충돌:** 다른 세션이 먼저 병합해 `pubspec.yaml` 버전·`CHANGELOG.md`가 충돌하면, 병합 직전에 main을 받아 **main보다 한 칸 위 버전으로 다시 올리고** CHANGELOG는 두 항목을 모두 살린다(pre-push가 빌드번호 역행을 막는다). 작업 공간이 남아 있으면 `tools/worktree.sh list`로 확인.
