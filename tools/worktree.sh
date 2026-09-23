#!/usr/bin/env bash
# 세션별 작업 공간(git worktree) 관리 — 여러 Claude/사람 세션이 같은 폴더를
# 공유하면 한쪽의 reset/checkout이 다른 쪽 미커밋 작업을 지운다(2026-07-08 사고).
# 세션마다 최신 main에서 별도 폴더+브랜치를 만들고, 끝나면 main에 병합 후 지운다.
#
#   tools/worktree.sh new <branch>     최신 main에서 ../tera-ai-flutter-<이름> 생성
#   tools/worktree.sh finish <branch>  main에 --no-ff 병합·push 후 폴더·브랜치 삭제
#   tools/worktree.sh list             현재 작업 공간 목록
#
# <branch> 예: fix/realtime-resilience → 폴더 ../tera-ai-flutter-realtime-resilience
set -euo pipefail

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
main_dir="$(git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

dir_for() { echo "$(dirname "$main_dir")/$(basename "$main_dir")-${1##*/}"; }

cmd="${1:-list}"
case "$cmd" in
  new)
    branch="${2:?브랜치 이름이 필요합니다 (예: fix/xxx)}"
    dir="$(dir_for "$branch")"
    git -C "$main_dir" fetch -q origin main
    # main 폴더가 main이 아니어도 원격 최신 main에서 분기한다.
    git -C "$main_dir" worktree add --no-track -b "$branch" "$dir" origin/main
    # .env는 gitignore라 worktree에 없다 — 없으면 빌드가 'No file for asset: .env'로 실패.
    [ -f "$main_dir/.env" ] && ln -s "$main_dir/.env" "$dir/.env"
    (cd "$dir" && flutter pub get >/dev/null)
    echo "✅ $dir  (branch $branch, base $(git -C "$dir" rev-parse --short HEAD))"
    ;;
  finish)
    branch="${2:?브랜치 이름이 필요합니다}"
    dir="$(dir_for "$branch")"
    if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
      echo "✋ $dir 에 커밋 안 된 변경이 있습니다. 먼저 커밋하세요." >&2; exit 1
    fi
    git -C "$main_dir" checkout -q main
    git -C "$main_dir" pull -q --ff-only origin main
    git -C "$main_dir" merge --no-ff "$branch" -m "merge: $branch"
    git -C "$main_dir" push -q origin main
    [ -L "$dir/.env" ] && rm "$dir/.env"
    git -C "$main_dir" worktree remove "$dir"
    git -C "$main_dir" branch -d "$branch"
    echo "✅ $branch → main 병합·push, 작업 공간 삭제"
    ;;
  list)
    git -C "$main_dir" worktree list
    ;;
  *)
    echo "사용법: tools/worktree.sh new|finish <branch> | list" >&2; exit 2
    ;;
esac
