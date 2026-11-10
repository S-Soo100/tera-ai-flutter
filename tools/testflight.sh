#!/usr/bin/env bash
# iOS 베타를 TestFlight에 올린다 — 최신 origin/main을 임시 작업 공간에 받아
# 팀 ID·번들 ID만 베타 값으로 바꿔 빌드하고 App Store Connect에 업로드한 뒤 지운다.
# 바꾼 설정은 임시 공간에만 있고 main에는 절대 들어가지 않는다.
#
#   tools/testflight.sh            빌드 + 업로드
#   tools/testflight.sh --dry-run  빌드까지만(업로드 없음)
#
# 전제: 이 Mac의 Xcode에 베타 팀 계정(bss.rol20)이 로그인돼 있어야 한다.
# 빌드 번호는 main의 pubspec.yaml 값을 쓴다 — 이미 올린 번호면 Apple이 업로드를 거절한다.
# 업로드 뒤 App Store Connect에서 암호화 질문에 한 번 답해야 테스터에게 간다.
set -euo pipefail

# 베타 팀(개인 멤버십). 법인 팀으로 옮기면 이 두 값만 바꾼다.
TEAM_ID="${TESTFLIGHT_TEAM_ID:-XYNNB47RN3}"
BUNDLE_ID="${TESTFLIGHT_BUNDLE_ID:-com.vivanaut.beta}"

dry_run=false
case "${1:-}" in
  --dry-run) dry_run=true ;;
  "") ;;
  *) echo "사용법: tools/testflight.sh [--dry-run]" >&2; exit 2 ;;
esac

die() { echo "✋ $*" >&2; exit 1; }

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
main_dir="$(git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
export_options="$root/tools/ExportOptionsTestFlight.plist"
[ -f "$main_dir/.env" ] || die "$main_dir/.env 가 없습니다 — 빌드가 'No file for asset: .env'로 실패합니다."
[ -f "$export_options" ] || die "$export_options 가 없습니다."

stamp="$(date +%Y%m%d-%H%M%S)"
work="$(dirname "$main_dir")/$(basename "$main_dir")-testflight-$stamp"
log_dir="$main_dir/build/testflight"
log="$log_dir/$stamp.log"
mkdir -p "$log_dir"

# 실패·중단해도 임시 작업 공간은 지운다. 로그는 build/testflight/에 남긴다.
cleanup() {
  [ -L "$work/.env" ] && rm "$work/.env"
  if [ -d "$work" ]; then
    git -C "$main_dir" worktree remove --force "$work" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

echo "▶ 최신 origin/main으로 임시 작업 공간 생성: $work"
git -C "$main_dir" fetch -q origin main
# 브랜치 없이(detached) 만들어 지울 브랜치를 남기지 않는다.
git -C "$main_dir" worktree add -q --detach "$work" origin/main
ln -s "$main_dir/.env" "$work/.env"
commit="$(git -C "$work" rev-parse --short HEAD)"

pbx="$work/ios/Runner.xcodeproj/project.pbxproj"
sed -i '' -E \
  -e "s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = $TEAM_ID;/" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = com\.vivanaut\.app;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/" \
  "$pbx"
# Runner 타깃 설정이 Debug/Release/Profile 세 벌이라 각각 3개여야 한다.
[ "$(grep -c "DEVELOPMENT_TEAM = $TEAM_ID;" "$pbx")" -eq 3 ] || die "팀 ID 교체 개수가 3이 아닙니다 — project.pbxproj 구조가 바뀌었는지 확인하세요."
[ "$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$pbx")" -eq 3 ] || die "번들 ID 교체 개수가 3이 아닙니다 — project.pbxproj 구조가 바뀌었는지 확인하세요."

version="$(awk '/^version:/{print $2; exit}' "$work/pubspec.yaml")"
echo "▶ 빌드: $version ($BUNDLE_ID, 팀 $TEAM_ID, main $commit) — 로그 $log"
(cd "$work" && flutter pub get >>"$log" 2>&1 && flutter build ipa --release >>"$log" 2>&1) \
  || { tail -30 "$log" >&2; die "빌드 실패 — 전체 로그: $log"; }

archive="$work/build/ios/archive/Runner.xcarchive"
built_id="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleIdentifier' "$archive/Info.plist")"
[ "$built_id" = "$BUNDLE_ID" ] || die "Archive 번들 ID가 $built_id 입니다 (기대값 $BUNDLE_ID)."

if $dry_run; then
  echo "✅ --dry-run: $version 빌드 성공, 업로드는 건너뜀. 임시 작업 공간을 지웁니다."
  exit 0
fi

echo "▶ App Store Connect 업로드"
options="$work/build/ExportOptionsTestFlight.plist"
cp "$export_options" "$options"
plutil -replace teamID -string "$TEAM_ID" "$options"
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
  -exportPath "$work/build/upload" -allowProvisioningUpdates >>"$log" 2>&1 \
  || { grep -E "error|Error" "$log" | tail -15 >&2; die "업로드 실패 — 전체 로그: $log"; }
grep -q "Upload succeeded" "$log" || die "업로드 성공 표시가 없습니다 — 전체 로그: $log"

grep -E "^warning: exportArchive" "$log" | sed 's/^/  ⚠️ /' || true
echo "✅ $version 업로드 완료 (main $commit). App Store Connect에서 처리 후 암호화 질문에 답하면 테스터에게 갑니다."
