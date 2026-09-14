# Vivanaut Identity Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱과 현재 문서의 잘못된 `vivnanaut` 식별자를 확정값 `vivanaut` 및 `com.vivanaut.app`으로 일괄 정정하고, Firebase Android 앱을 올바른 application ID로 최초 등록한다.

**Architecture:** 사용자 결정이 기록된 `CLAUDE.md`를 이름 SOT로 삼고, Dart 패키지와 각 플랫폼 식별자를 같은 논리 변경으로 맞춘다. 생성물은 직접 편집하지 않고 Flutter 도구로 재생성하며, Firebase에는 로컬 검증이 끝난 Android application ID만 등록한다.

**Tech Stack:** Flutter, Dart, Android Gradle/Kotlin, Xcode project files, Linux/Windows CMake, Firebase Console

**Spec:** `docs/superpowers/specs/2026-09-14-vivanaut-identity-migration-design.md`

## Global Constraints

- 한글 표시명은 `비바나트`, 영문 브랜드와 Dart package는 `vivanaut`다.
- Android namespace/application ID 및 iOS bundle ID는 `com.vivanaut.app`이다.
- Apple Developer/APNs/iOS Firebase 등록은 이번 범위에서 제외한다.
- 저장소명, Supabase 프로젝트, 서버 도메인, 외부 Figma URL은 변경하지 않는다.
- 과거 감사 자료와 URL의 역사적 철자는 사실 보존을 위해 일괄 치환하지 않는다.
- 앱 변경은 `0.102.0+203`으로 version bump하고 같은 커밋에 한글 패치노트를 남긴다.

---

### Task 1: 이름 SOT와 현행 문서 경로 정정

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `README.md`
- Rename: `.claude/rules/vivnanaut-caof.md` → `.claude/rules/vivanaut-caof.md`
- Rename: `docs/prd-vivnanaut-app.md` → `docs/prd-vivanaut-app.md`

**Interfaces:**
- Consumes: 사용자 확정 식별자 표
- Produces: 모든 에이전트와 후속 작업이 참조할 현재 이름 SOT 및 유효 문서 링크

- [ ] **Step 1: 현재 문서 참조를 검색한다**

Run: `rg -n 'vivnanaut-caof|prd-vivnanaut-app|Figma 파일명.*SOT|영문.*vivnanaut' CLAUDE.md AGENTS.md README.md docs --glob '!docs/design-audits/**'`

Expected: 이름 표와 두 파일 경로의 변경 대상이 출력된다.

- [ ] **Step 2: 두 현행 파일을 새 철자 경로로 이동한다**

Run: `mv .claude/rules/vivnanaut-caof.md .claude/rules/vivanaut-caof.md` 및 `mv docs/prd-vivnanaut-app.md docs/prd-vivanaut-app.md`

Expected: 기존 경로는 사라지고 새 경로가 존재한다.

- [ ] **Step 3: 현재 SOT와 링크를 정정한다**

Apply exact values: `vivanaut`, `Vivanaut`, `com.vivanaut.app`, `.claude/rules/vivanaut-caof.md`, `docs/prd-vivanaut-app.md`. Figma URL의 `/vivnanaut` 경로는 바꾸지 않고 외부 원본의 과거 파일명임을 명시한다.

- [ ] **Step 4: 문서 무결성을 검사한다**

Run: `git diff --check && test -f .claude/rules/vivanaut-caof.md && test -f docs/prd-vivanaut-app.md`

Expected: exit 0.

### Task 2: Dart 패키지와 앱 내부 브랜드 정정

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/my_cage/presentation/widgets/video_watermark.dart`
- Modify: all `lib/**/*.dart` and `test/**/*.dart` files importing `package:vivnanaut/`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1의 `vivanaut` SOT
- Produces: package name `vivanaut`으로 해석되는 모든 Dart import와 앱 내부 브랜드

- [ ] **Step 1: package import 정정 전 실패 조건을 고정한다**

Run: `rg -l 'package:vivnanaut/' lib test | wc -l`

Expected: 1개 이상의 파일이 출력되어 변경 필요성을 증명한다.

- [ ] **Step 2: 패키지명과 imports를 기계적으로 정정한다**

Replace only `name: vivnanaut` → `name: vivanaut` and `package:vivnanaut/` → `package:vivanaut/`. Set `version: 0.102.0+203` without modifying unrelated dependency choices.

- [ ] **Step 3: 앱 내부 브랜드 상수를 정정한다**

Set `VideoWatermark.brand` to `vivanaut` and update its SOT comment.

- [ ] **Step 4: 한글 패치노트를 추가한다**

Add `## [0.102.0+203] - 2026-09-15` above older versions with a `변경` section describing the corrected English name, package, and platform identifiers.

- [ ] **Step 5: Dart 패키지 상태를 재생성하고 검사한다**

Run: `flutter pub get && ! rg -n 'package:vivnanaut/' lib test && rg -n '^name: vivanaut$|^version: 0.102.0\+203$' pubspec.yaml`

Expected: pub get exit 0, old package imports 0건, 새 name/version 각 1건.

### Task 3: 플랫폼 식별자 정정

**Files:**
- Modify: `android/app/build.gradle.kts`
- Rename: `android/app/src/main/kotlin/com/vivnanaut/app/MainActivity.kt` → `android/app/src/main/kotlin/com/vivanaut/app/MainActivity.kt`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/Info.plist`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`
- Modify: `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- Modify: `macos/Runner/Configs/AppInfo.xcconfig`
- Modify: `linux/CMakeLists.txt`
- Modify: `windows/CMakeLists.txt`
- Modify: `web/index.html`
- Modify: `web/manifest.json`

**Interfaces:**
- Consumes: Task 1의 bundle/application ID와 Task 2의 binary name
- Produces: Android `com.vivanaut.app`, Apple `com.vivanaut.app` 계열, desktop/web `vivanaut`

- [ ] **Step 1: 플랫폼별 기존 식별자를 검색한다**

Run: `rg -n 'com\.vivnanaut\.app|vivnanaut\.app|BINARY_NAME.*vivnanaut|APPLICATION_ID.*vivnanaut|PRODUCT_NAME.*vivnanaut|<string>vivnanaut</string>' android ios macos linux windows web`

Expected: 정정할 플랫폼 식별자가 출력된다.

- [ ] **Step 2: Android 식별자와 Kotlin 경로를 정정한다**

Set both `namespace` and `applicationId` to `com.vivanaut.app`, move `MainActivity.kt` under `com/vivanaut/app`, and set its package declaration to `com.vivanaut.app`.

- [ ] **Step 3: Apple 로컬 식별자를 정정한다**

Set Runner bundle ID to `com.vivanaut.app`, RunnerTests to `com.vivanaut.app.RunnerTests`, bundle/product name to `vivanaut` or `Vivanaut` according to display context. Do not add push capabilities or Firebase iOS configuration.

- [ ] **Step 4: desktop/web 식별자를 정정한다**

Set Linux/Windows binary/application names to `vivanaut` and web English display strings to `Vivanaut`.

- [ ] **Step 5: live config 잔존값을 검사한다**

Run: `! rg -n 'com\.vivnanaut\.app|package:vivnanaut/|BINARY_NAME.*vivnanaut|APPLICATION_ID.*vivnanaut|vivnanaut\.app' android ios macos linux windows web lib test pubspec.yaml`

Expected: exit 0 with no old live identifiers.

### Task 4: 전체 검증과 코드 커밋

**Files:**
- Verify: entire repository

**Interfaces:**
- Consumes: Tasks 1–3 complete tree
- Produces: 빌드 가능한 식별자 정정 커밋

- [ ] **Step 1: Dart 파일을 포맷한다**

Run: `dart format lib test`

Expected: exit 0.

- [ ] **Step 2: 정적 분석과 전체 테스트를 실행한다**

Run: `flutter analyze --no-fatal-infos && flutter test`

Expected: analyzer error 0 and all tests passed.

- [ ] **Step 3: Android debug APK를 빌드한다**

Run: `flutter build apk --debug`

Expected: `build/app/outputs/flutter-apk/app-debug.apk` 생성과 exit 0.

- [ ] **Step 4: diff와 요구사항을 최종 검사한다**

Run: `git diff --check && git status --short && ! rg -n 'package:vivnanaut/|com\.vivnanaut\.app|BINARY_NAME.*vivnanaut' lib test android ios macos linux windows web pubspec.yaml`

Expected: 계획된 변경만 존재하고 old live identifiers는 0건이다.

- [ ] **Step 5: 단독 커밋한다**

Run: `git add`로 식별자 변경 파일과 `CHANGELOG.md`만 명시한 뒤 `git commit -m "refactor: correct vivanaut app identity"`.

Expected: identity migration이 다른 기능과 분리된 단일 커밋으로 남는다.

### Task 5: Firebase Android 앱 최초 등록

**Files:**
- Create: `android/app/google-services.json`
- Modify: Android Gradle files only if FlutterFire setup requires the Google Services plugin

**Interfaces:**
- Consumes: verified Android application ID `com.vivanaut.app`
- Produces: Firebase project `vivanaut-app`에 연결된 Android 앱 설정

- [ ] **Step 1: Firebase Console에서 프로젝트 앱 상태를 확인한다**

Open project `vivanaut-app` settings and confirm no conflicting Android app exists.

- [ ] **Step 2: Android 앱을 등록한다**

Register package name `com.vivanaut.app` and app nickname `비바나트 Android`. SHA certificate fields are left empty because FCM token delivery does not require them.

- [ ] **Step 3: Firebase 설정 파일을 저장한다**

Download the generated `google-services.json` and place it at `android/app/google-services.json`. Verify its `project_id` is `vivanaut-app` and package name is `com.vivanaut.app` without printing secrets.

- [ ] **Step 4: Gradle 연결과 APK 빌드를 검증한다**

Apply only the plugin configuration required by the current Flutter/Firebase setup, then run `flutter build apk --debug`.

Expected: Firebase resources merge and APK build succeed.

- [ ] **Step 5: Firebase 연결을 별도 커밋한다**

Add the Firebase config, required Gradle changes, version bump, and Korean patch note; commit as `build: connect Android app to Firebase`.

Expected: Android Firebase registration and repository configuration remain independently reviewable.
