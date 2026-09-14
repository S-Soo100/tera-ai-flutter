# Vivanaut 앱 식별자 정정 설계

> 작성일: 2026-09-14
> 상태: 사용자 설계 승인 / 구현 계획 작성 전
> 선행 관계: Android FCM 도입 전에 완료
> 사용자 결정: 올바른 영문명은 `vivanaut`이며 기존 `vivnanaut`는 오기다.

## 1. 목적

현재 저장소의 영문 브랜드, Dart 패키지명, Android application ID와 iOS bundle ID에는 `vivnanaut`가 사용된다. 사용자가 2026-09-14에 올바른 영문명을 `vivanaut`로 확정했으므로, 출시 식별자와 현재 문서의 단일 진실 소스(SOT)를 같은 철자로 정정한다.

이번 변경은 Android 앱을 Firebase에 등록하기 전에 완료한다. Chrome에서 확인한 Firebase 프로젝트는 이름과 ID가 모두 `vivanaut-app`이고 아직 등록된 앱이 없으므로, 이 프로젝트를 그대로 사용해 정정된 Android application ID `com.vivanaut.app`을 최초 등록할 수 있다.

## 2. 확정 식별자

| 용도 | 확정값 |
|---|---|
| 한글 표시명 | 비바나트 |
| 영문 브랜드 | `vivanaut` |
| 앱 내부 영문 표시 | `Vivanaut` |
| Dart 패키지명 | `vivanaut` |
| Android namespace | `com.vivanaut.app` |
| Android application ID | `com.vivanaut.app` |
| iOS bundle ID | `com.vivanaut.app` |
| Apple 테스트 bundle ID | `com.vivanaut.app.RunnerTests` |
| Firebase 프로젝트 ID | `vivanaut-app` |
| Linux/Windows 실행 파일명 | `vivanaut` |

저장소 디렉터리명 `tera-ai-flutter`, Supabase 프로젝트, `api.tera-ai.uk` 등의 서버 도메인은 이번 변경 범위가 아니다.

## 3. 변경 범위

### 3.1 현재 규칙과 문서

- `CLAUDE.md`의 이름 표를 확정값으로 바꾸고, Figma 파일명이 이름의 SOT라는 기존 설명을 폐기한다. 새 SOT는 2026-09-14 사용자 직접 결정이다.
- `README.md`와 현행 기획 문서에서 제품 영문명을 정정한다.
- 현행 PRD 파일을 `docs/prd-vivnanaut-app.md`에서 `docs/prd-vivanaut-app.md`로 바꾸고 현재 문서의 링크를 함께 갱신한다.
- CAOF 규칙 파일을 `.claude/rules/vivnanaut-caof.md`에서 `.claude/rules/vivanaut-caof.md`로 바꾸고 진입 링크를 갱신한다.
- 과거 결정의 원문, 감사 산출물, 외부 URL의 경로 문자열은 사실 보존을 위해 무조건 치환하지 않는다. 현재 규칙으로 오인될 수 있는 설명에는 오기였다는 주석을 추가한다.

### 3.2 Dart 패키지

- `pubspec.yaml`의 `name`을 `vivanaut`로 바꾼다.
- `lib/`와 `test/`의 `package:vivnanaut/...` import를 전부 `package:vivanaut/...`로 바꾼다.
- `.dart_tool/`, `build/` 등 생성물은 직접 편집하지 않고 `flutter pub get`과 빌드 과정에서 재생성한다.
- `pubspec.yaml`에는 사용자의 진행 중 변경이 있으므로 파일 전체를 교체하지 않고 패키지명과 필요한 버전 변경만 최소 패치한다.

### 3.3 Android

- `android/app/build.gradle.kts`의 `namespace`와 `applicationId`를 `com.vivanaut.app`으로 바꾼다.
- `MainActivity.kt`를 `android/app/src/main/kotlin/com/vivanaut/app/`로 이동하고 package 선언을 정정한다.
- 한글 런처 표시명 `비바나트`는 유지한다.
- 이름 정정 완료 후 Firebase 프로젝트 `vivanaut-app`에 Android 앱 `com.vivanaut.app`을 등록한다. 이전 ID로 Firebase 앱을 만들지 않는다.

### 3.4 Apple 플랫폼

- iOS Xcode 프로젝트의 Runner 및 RunnerTests bundle ID와 `Info.plist`의 영문 bundle name을 정정한다.
- macOS 프로젝트의 bundle ID, 제품명, scheme 내 식별자를 정정한다.
- Apple Developer 계정, APNs 키, Push Notifications capability와 iOS용 Firebase 앱 등록은 후속 FCM 단계로 미룬다.
- 로컬 프로젝트의 bundle ID 정정은 지금 수행해 이후 Apple 등록 시 잘못된 ID가 다시 사용되지 않게 한다.

### 3.5 데스크톱·웹과 앱 내 표시

- Linux 및 Windows의 binary/application 식별자를 `vivanaut`로 정정한다.
- Web manifest와 HTML에 이전 영문명이 존재하면 `Vivanaut` 또는 `vivanaut`로 정정한다.
- 앱 내부 워터마크, 데모 식별자, 테마 설명 등 실행 코드에 남은 `vivnanaut`를 문맥에 맞게 정정한다.
- 한국어 사용자 표시명과 번역 키 구조는 바꾸지 않는다.

## 4. 실행 순서

1. SOT 표와 현재 문서 파일명을 먼저 정정한다.
2. Dart 패키지명과 모든 package import를 한 작업 단위로 정정한다.
3. Android namespace, application ID, Kotlin 경로를 정정한다.
4. iOS, macOS, Linux, Windows, Web 식별자를 정정한다.
5. 실행 코드와 현재 문서에서 옛 철자가 재유입되지 않았는지 제한된 범위의 검색 검사를 수행한다.
6. `flutter pub get`, 포맷, 정적 분석, 전체 테스트, Android debug 빌드를 실행한다.
7. 정정된 Android application ID로 Firebase 앱을 등록한다.

식별자가 절반만 바뀐 상태는 컴파일과 Firebase 등록을 모두 혼란스럽게 하므로, 1~4는 한 기능 변경으로 완료하고 검증한다.

## 5. 데이터 및 사용자 영향

Android application ID와 Apple bundle ID는 OS에서 앱을 구분하는 키다. 기존 ID로 설치된 빌드와 정정된 빌드는 서로 다른 앱으로 취급되므로 Hive, secure storage, 알림 권한 같은 로컬 앱 데이터가 자동 승계되지 않는다. 아직 정식 출시 전이라는 전제에서 이 동작을 수용한다.

Supabase 계정과 서버 데이터는 Supabase Auth 사용자 UUID를 기준으로 하므로 bundle ID 변경만으로 삭제되거나 변경되지 않는다. 사용자는 새 ID의 앱에서 동일한 계정으로 다시 로그인할 수 있다. 서버 API 주소와 DB 스키마도 이번 변경의 영향을 받지 않는다.

## 6. FCM 선행 조건

이 정정은 Android FCM 구현의 선행 작업이다. Firebase 설정 파일과 FCM 토큰은 Firebase에 등록한 application ID에 종속되므로, 이름 정정 전에 `com.vivnanaut.app`으로 Android 앱을 등록하거나 설정 파일을 생성하지 않는다.

정정과 검증이 끝난 뒤 `vivanaut-app` Firebase 프로젝트에 `com.vivanaut.app`을 등록하고 Android-first FCM 기획을 진행한다. iOS FCM은 Apple Developer 계정 생성 이후 같은 공통 Supabase 알림 인프라에 연결한다.

## 7. 검증 기준

- `pubspec.yaml`의 패키지명이 `vivanaut`다.
- live source/config 범위에 `package:vivnanaut`, `com.vivnanaut.app`, `BINARY_NAME "vivnanaut"`가 남지 않는다.
- 현재 SOT 문서는 `vivanaut`를 올바른 영문명으로 선언한다.
- Android namespace와 application ID가 모두 `com.vivanaut.app`이다.
- iOS/macOS bundle ID가 `com.vivanaut.app` 계열이다.
- `flutter analyze`에서 오류가 없다.
- `flutter test`가 통과한다.
- `flutter build apk --debug`가 성공한다.
- Firebase Android 앱 등록값이 `com.vivanaut.app`이다.

## 8. 범위 밖

- 저장소 이름 변경
- 서버 도메인 변경
- Supabase 프로젝트 이름 변경
- 외부 Figma 파일의 표시명 변경
- Apple Developer 계정 생성과 APNs 설정
- FCM 알림 기능 자체의 구현
- 과거 Git 커밋이나 보관 문서의 역사적 문자열 일괄 재작성

## 9. 롤백

Firebase Android 앱 등록 전 실패하면 코드와 문서 커밋을 되돌리고 원인을 수정한다. Firebase 등록 후에는 application ID를 다시 흔들지 않고, 앱 코드가 Firebase 등록값과 일치하도록 수정한다. 정정 작업은 다른 기능 변경과 섞지 않은 단독 커밋으로 남겨 롤백 범위를 명확히 한다.
