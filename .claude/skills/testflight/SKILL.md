---
name: testflight
description: iOS 정식 앱 "비바나트"(com.vivanaut.app)를 TestFlight에 올린다. origin/main을 임시 작업 공간에서 빌드해 정식 설정·서명·푸시 entitlements를 검사하고 App Store Connect에 업로드한 뒤 정리한다. 병합 전 브랜치는 --dry-run --ref로 검증만 한다. 트리거 — "TestFlight 올려", "테플 올려줘", "iOS 베타 올려", "아이폰 테스트 빌드 올려". 빌드만 확인하려면 --dry-run. 업로드는 외부 전송이라 사용자가 요청했을 때만 실행한다.
---

# TestFlight 업로드

`tools/testflight.sh`가 전부 한다. 이 스킬은 실행 전 확인, 실행, 결과 보고를 맡는다.

> **2026-11-24 사용자 결정: TestFlight도 정식 앱으로 올린다.** main이 정식 값(팀 `XYNNB47RN3`·번들 `com.vivanaut.app`·iPhone 전용)을 들고 있고, `com.vivanaut.beta`("비바나트 베타")는 은퇴했다(마지막 빌드 552).
> 스크립트는 빌드 설정을 바꾸지 않고 **검사만** 한다. 정식 값이 아닌 ref면 빌드 전에 멈춘다.
> **App Store Connect에 `com.vivanaut.app` 앱 레코드를 만들기 전까지(iOS 정식 출시 계획 U3) 실제 업로드는 실패한다.** `--dry-run`은 앱 레코드 없이 된다.

## 1. 실행 전 확인

- **올라갈 코드는 origin/main이다.** 업로드는 `origin/main`에서만 된다(다른 ref로 업로드하면 스크립트가 바로 멈춘다). 로컬에만 있는 커밋이나 작업 공간 브랜치는 들어가지 않는다. 사용자가 기대하는 변경이 origin/main에 있는지 `git log origin/main -5 --oneline`으로 확인하고, 없으면 먼저 병합·push할지 묻는다.
- **병합 전 검증**: iOS 빌드 설정·서명에 영향을 주는 브랜치는 push한 뒤 `tools/testflight.sh --dry-run --ref origin/<브랜치>`로 빌드·export·산출물 검사를 통과시키고 병합한다.
- **빌드 번호**: `git show origin/main:pubspec.yaml | grep ^version:`의 `+` 뒤 숫자가 마지막으로 올린 번호보다 커야 한다. 마지막 번호는 메모리 `project_apple_developer_team`에 있다. 같거나 작으면 Apple이 업로드를 거절하니, 실행하지 말고 main 버전을 먼저 올려야 한다고 알린다.
- Xcode에 조직 팀 terraai Co.,Ltd.(XYNNB47RN3)의 bss.rol20 계정이 로그인돼 있어야 한다. 사용자의 비밀번호를 대신 입력하지 않는다.

## 2. 실행

빌드·export·업로드에 5~15분 걸리므로 백그라운드로 실행하고 완료 알림을 기다린다.

```bash
tools/testflight.sh                                  # origin/main 빌드 + 검사 + 업로드
tools/testflight.sh --dry-run                        # origin/main 빌드 + 로컬 export + 검사
tools/testflight.sh --dry-run --ref origin/<브랜치>   # 병합 전 브랜치 검증(업로드 불가)
```

스크립트가 하는 일:
1. ref의 `project.pbxproj`에서 `DEVELOPMENT_TEAM = XYNNB47RN3;`·`PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app;`·`TARGETED_DEVICE_FAMILY = 1;`가 각 3개인지 검사.
2. `flutter build ipa --release` 뒤 archive 번들 ID 검사.
3. `xcodebuild -exportArchive`(destination `export`, 자동 서명)로 로컬 .ipa를 만들고 `Payload/Runner.app`을 검사 — 번들 ID, 서명 팀, entitlements `aps-environment = production`·`com.apple.developer.usernotifications.time-sensitive = true`, 앱 안 `GoogleService-Info.plist`의 `BUNDLE_ID = com.vivanaut.app`. (`flutter build ipa`는 자체 export가 실패해도 0으로 끝날 수 있어 믿지 않는다.)
4. 업로드 모드만: 검사 통과 뒤 destination `upload`로 다시 export해 업로드, 로그에서 `Upload succeeded` 확인.

실패해도 임시 작업 공간은 스크립트가 지운다. 전체 로그는 main 폴더의 `build/testflight/<시각>.log`에 남는다.

## 3. 결과 보고

- 성공: 버전(빌드 번호), ref와 커밋, 산출물 검사 줄(`▶ 산출물 검사 통과: …`), 업로드 경고(`⚠️` 줄)를 전한다. 업로드했으면 메모리 `project_apple_developer_team`의 마지막 업로드 번호를 갱신한다.
- 업로드 뒤 사용자가 할 일을 안내한다.
  1. App Store Connect → 비바나트 → TestFlight에서 처리(5~30분)를 기다린다.
  2. "규정 준수 정보 누락"이 뜨면 **관리**에서 암호화 유형으로 "Apple의 운영 체제 내 암호화를 대체하거나 이와 병행하여 사용하는 표준 암호화 알고리즘"(Flutter BoringSSL·WebRTC DTLS/SRTP)을 고르고, 프랑스 배포는 "아니요"로 답한다.
  3. 내부 테스팅 그룹이 자동 배포면 테스터의 TestFlight 앱에 바로 뜬다.

## 실패했을 때

| 증상 | 원인 | 조치 |
|---|---|---|
| `업로드는 origin/main 에서만 합니다` | 업로드 모드에 다른 ref를 줬다 | 병합 전 검증이면 `--dry-run`을 붙인다. 올릴 거면 먼저 main에 병합·push |
| `ref '…' 를 찾을 수 없습니다` | 브랜치를 push하지 않았거나 이름 오타 | `git push` 뒤 `origin/<브랜치>`로 다시 실행 |
| `project.pbxproj에 '…' 이 N개입니다(기대 3)` | 그 ref에 정식 설정(팀·번들·iPhone 전용)이 없거나 pbxproj 구조가 바뀜 | 정식 설정 브랜치를 병합한다. 구조가 바뀐 거면 검사 개수를 현재 구조에 맞게 고친다. **스크립트에서 값을 바꿔 끼우지 않는다** |
| 빌드 실패 `No profiles` / `no devices` | 팀에 등록 기기가 없거나 프로필 갱신 실패 | developer.apple.com Devices에 기기가 있는지 확인 |
| `export 실패` — 계정·프로필·기능 오류 | Xcode 로그인 만료, 또는 App ID 기능과 entitlements 불일치 | Xcode Settings → Apple Accounts 재로그인 요청. 기능 오류면 developer.apple.com App ID에 Push Notifications·Time Sensitive Notifications가 켜져 있는지 확인 |
| `서명 팀이 '…' 입니다` | 다른 팀으로 서명됨 | Xcode에 로그인된 계정·팀을 확인 |
| `aps-environment가 '…' 입니다` / `time-sensitive가 '…' 입니다` | App ID 기능 누락 또는 배포 프로필에 기능 미반영 | App ID 기능 확인 뒤 다시 실행(자동 서명이 프로필을 다시 만든다) |
| `GoogleService-Info.plist가 없습니다` / `BUNDLE_ID가 '…'` | plist 리소스 등록 누락 또는 다른 번들용 plist | `ios/Runner/GoogleService-Info.plist`와 Runner 리소스 등록 확인. 틀리면 푸시 토큰을 못 받는다 |
| 업로드 실패 — 앱을 찾을 수 없음 | App Store Connect에 com.vivanaut.app 앱 레코드가 없다(U3 전) | 앱 레코드를 만든 뒤 다시 실행 |
| 업로드 실패 — 인증·계정 오류 | Xcode 로그인 만료 | 사용자에게 Xcode Settings → Apple Accounts에서 다시 로그인을 요청 |
| 업로드 실패 — 빌드 번호 중복 | 이미 올린 번호 | main 버전을 올린 뒤 다시 실행 |
