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
