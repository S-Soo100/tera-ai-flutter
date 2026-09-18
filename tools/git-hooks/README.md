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
