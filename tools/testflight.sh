#!/usr/bin/env bash
# iOS 정식 앱 "비바나트"(com.vivanaut.app)를 TestFlight에 올린다.
# 지정한 ref(기본 origin/main)를 임시 작업 공간에 받아 빌드하고, App Store용으로 export한
# 산출물의 서명·푸시 entitlements·Firebase 설정을 검사한 뒤 업로드하고 임시 공간을 지운다.
# 빌드 설정은 바꾸지 않고 검사만 한다 — 팀·번들·기기군이 정식 값이 아니면 빌드 전에 멈춘다.
#
#   tools/testflight.sh                          origin/main 빌드 + 검사 + 업로드
#   tools/testflight.sh --dry-run                origin/main 빌드 + 로컬 export + 검사(업로드 없음)
#   tools/testflight.sh --dry-run --ref <ref>    병합 전 브랜치 검증용(예: origin/feat/…). 업로드는 origin/main만
#
# 전제:
# - 이 Mac의 Xcode에 조직 팀 terraai Co.,Ltd.(XYNNB47RN3)의 bss.rol20 계정이 로그인돼 있어야 한다
#   (자동 서명 -allowProvisioningUpdates가 배포 프로필을 만들거나 갱신한다).
# - 업로드에는 App Store Connect에 com.vivanaut.app 앱 레코드가 있어야 한다. 아직 만들지 않았으므로
#   (iOS 정식 출시 계획 U3) 그 전까지 실제 업로드는 실패한다. --dry-run은 앱 레코드 없이도 된다.
# 빌드 번호는 ref의 pubspec.yaml 값을 쓴다 — 이미 올린 번호면 Apple이 업로드를 거절한다.
# 업로드 뒤 App Store Connect에서 암호화 질문에 한 번 답해야 테스터에게 간다.
set -euo pipefail

# 정식 값. ref의 project.pbxproj가 이 값을 들고 있어야 한다(스크립트는 바꾸지 않는다).
readonly TEAM_ID="XYNNB47RN3"
readonly BUNDLE_ID="com.vivanaut.app"
readonly UPLOAD_REF="origin/main"

usage="사용법: tools/testflight.sh [--dry-run] [--ref <ref>]"
die() { echo "✋ $*" >&2; exit 1; }

dry_run=false
ref="$UPLOAD_REF"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --ref)
      [ $# -ge 2 ] && [ -n "$2" ] || { echo "$usage" >&2; exit 2; }
      ref="$2"; shift ;;
    --ref=*)
      ref="${1#--ref=}"
      [ -n "$ref" ] || { echo "$usage" >&2; exit 2; } ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
  shift
done

# 업로드는 origin/main만. 병합 전 브랜치는 --dry-run으로만 검증한다. 아무것도 만들기 전에 멈춘다.
if ! $dry_run && [ "$ref" != "$UPLOAD_REF" ]; then
  die "업로드는 $UPLOAD_REF 에서만 합니다 (지정한 ref: $ref). 병합 전 검증은 --dry-run --ref $ref 로 하세요."
fi

root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
main_dir="$(git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
export_options="$root/tools/ExportOptionsTestFlight.plist"
[ -f "$main_dir/.env" ] || die "$main_dir/.env 가 없습니다 — 빌드가 'No file for asset: .env'로 실패합니다."
[ -f "$export_options" ] || die "$export_options 가 없습니다."

git -C "$main_dir" fetch -q origin
git -C "$main_dir" rev-parse -q --verify "$ref^{commit}" >/dev/null \
  || die "ref '$ref' 를 찾을 수 없습니다 — origin에 push했는지 확인하세요."

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

echo "▶ 임시 작업 공간 생성($ref): $work"
# 브랜치 없이(detached) 만들어 지울 브랜치를 남기지 않는다.
git -C "$main_dir" worktree add -q --detach "$work" "$ref"
ln -s "$main_dir/.env" "$work/.env"
commit="$(git -C "$work" rev-parse --short HEAD)"

# 정식 설정 검사 — Runner 타깃(팀·번들)과 프로젝트 레벨(기기군) 설정이 각각 Debug/Release/Profile 세 벌.
pbx="$work/ios/Runner.xcodeproj/project.pbxproj"
[ -f "$pbx" ] || die "$ref($commit)에 $pbx 가 없습니다."
check_setting() {
  local line="$1" n
  n="$(grep -cF -- "$line" "$pbx" || true)"
  [ "$n" -eq 3 ] || die "$ref($commit)의 project.pbxproj에 '$line' 이 ${n}개입니다(기대 3) — 이 ref에는 정식 설정이 없습니다. iOS 정식 출시 브랜치를 먼저 병합하세요."
}
check_setting "DEVELOPMENT_TEAM = $TEAM_ID;"
check_setting "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;"
check_setting "TARGETED_DEVICE_FAMILY = 1;"

version="$(awk '/^version:/{print $2; exit}' "$work/pubspec.yaml")"
echo "▶ 빌드: $version ($BUNDLE_ID, 팀 $TEAM_ID, $ref $commit) — 로그 $log"
# flutter build ipa는 자체 export가 실패해도 0으로 끝날 수 있어, export는 아래에서 직접 한다.
(cd "$work" && flutter pub get >>"$log" 2>&1 && flutter build ipa --release >>"$log" 2>&1) \
  || { tail -30 "$log" >&2; die "빌드 실패 — 전체 로그: $log"; }

archive="$work/build/ios/archive/Runner.xcarchive"
[ -f "$archive/Info.plist" ] || die "Archive가 없습니다 ($archive) — 전체 로그: $log"
built_id="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleIdentifier' "$archive/Info.plist")"
[ "$built_id" = "$BUNDLE_ID" ] || die "Archive 번들 ID가 $built_id 입니다 (기대값 $BUNDLE_ID)."

# export_archive <destination> <exportPath>: 원본 옵션을 복사해 destination·teamID만 정해 export한다.
export_archive() {
  local destination="$1" out="$2" options
  options="$work/build/ExportOptions-$destination.plist"
  cp "$export_options" "$options"
  plutil -replace destination -string "$destination" "$options"
  plutil -replace teamID -string "$TEAM_ID" "$options"
  echo "===== xcodebuild -exportArchive (destination=$destination) =====" >>"$log"
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
    -exportPath "$out" -allowProvisioningUpdates >>"$log" 2>&1
}

echo "▶ App Store용 로컬 export"
export_dir="$work/build/export"
export_archive export "$export_dir" \
  || { grep -E "error|Error" "$log" | tail -15 >&2; die "export 실패 — 전체 로그: $log"; }

# 산출물 검사 — 업로드 모드도 이 검사를 통과해야 업로드한다.
ipa="$(find "$export_dir" -maxdepth 1 -name '*.ipa' | head -1)"
[ -n "$ipa" ] || die "export 결과에 .ipa가 없습니다 ($export_dir) — 전체 로그: $log"
check_dir="$work/build/ipa-check"
mkdir -p "$check_dir"
ditto -x -k "$ipa" "$check_dir" || die "$ipa 압축 해제 실패."
app="$check_dir/Payload/Runner.app"
[ -d "$app" ] || die "$ipa 안에 Payload/Runner.app이 없습니다."

app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist" 2>/dev/null || true)"
[ "$app_id" = "$BUNDLE_ID" ] || die "export된 앱 번들 ID가 '$app_id' 입니다 (기대값 $BUNDLE_ID) — 전체 로그: $log"

sig_team="$(codesign -dv "$app" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[ "$sig_team" = "$TEAM_ID" ] || die "서명 팀이 '$sig_team' 입니다 (기대값 $TEAM_ID) — 전체 로그: $log"

ent="$check_dir/entitlements.plist"
codesign -d --entitlements - --xml "$app" >"$ent" 2>>"$log" \
  || die "서명 entitlements를 읽지 못했습니다 — 전체 로그: $log"
ent_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$ent" 2>/dev/null || true; }
aps="$(ent_get aps-environment)"
[ "$aps" = "production" ] \
  || die "서명 entitlements의 aps-environment가 '$aps' 입니다 (기대값 production) — App ID에 Push Notifications가 켜져 있는지 확인하세요. 전체 로그: $log"
ts="$(ent_get com.apple.developer.usernotifications.time-sensitive)"
[ "$ts" = "true" ] \
  || die "서명 entitlements의 time-sensitive가 '$ts' 입니다 (기대값 true) — App ID에 Time Sensitive Notifications가 켜져 있는지 확인하세요. 전체 로그: $log"

gsi="$app/GoogleService-Info.plist"
[ -f "$gsi" ] || die "앱 안에 GoogleService-Info.plist가 없습니다 — Runner 리소스 등록을 확인하세요."
gsi_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$gsi" 2>/dev/null || true)"
[ "$gsi_id" = "$BUNDLE_ID" ] \
  || die "앱 안 GoogleService-Info.plist의 BUNDLE_ID가 '$gsi_id' 입니다 (기대값 $BUNDLE_ID) — 푸시 토큰을 받지 못합니다."

echo "▶ 산출물 검사 통과: 서명 팀 $sig_team, aps-environment $aps, time-sensitive $ts, Firebase BUNDLE_ID $gsi_id"

if $dry_run; then
  grep -E "^warning: exportArchive" "$log" | sed 's/^/  ⚠️ /' || true
  echo "✅ --dry-run: $version ($ref $commit) 빌드·export·검사 통과, 업로드는 건너뜀. 임시 작업 공간을 지웁니다."
  exit 0
fi

echo "▶ App Store Connect 업로드"
export_archive upload "$work/build/upload" \
  || { grep -E "error|Error" "$log" | tail -15 >&2; die "업로드 실패 — 전체 로그: $log"; }
grep -q "Upload succeeded" "$log" || die "업로드 성공 표시가 없습니다 — 전체 로그: $log"

grep -E "^warning: exportArchive" "$log" | sed 's/^/  ⚠️ /' || true
echo "✅ $version 업로드 완료 ($ref $commit). App Store Connect에서 처리 후 암호화 질문에 답하면 테스터에게 갑니다."
