---
name: testflight
description: iOS 베타("비바나트 베타", com.vivanaut.beta)를 TestFlight에 올린다. 최신 origin/main을 임시 작업 공간에서 빌드해 App Store Connect에 업로드하고 정리한다. 트리거 — "TestFlight 올려", "테플 올려줘", "iOS 베타 올려", "아이폰 테스트 빌드 올려". 빌드만 확인하려면 --dry-run. 업로드는 외부 전송이라 사용자가 요청했을 때만 실행한다.
---

# TestFlight 업로드

`tools/testflight.sh`가 전부 한다. 이 스킬은 실행 전 확인, 실행, 결과 보고를 맡는다.

## 1. 실행 전 확인

- **올라갈 코드는 origin/main이다.** 로컬에만 있는 커밋이나 작업 공간 브랜치는 들어가지 않는다. 사용자가 기대하는 변경이 origin/main에 있는지 `git log origin/main -5 --oneline`으로 확인하고, 없으면 먼저 병합·push할지 묻는다.
- **빌드 번호**: `git show origin/main:pubspec.yaml | grep ^version:`의 `+` 뒤 숫자가 마지막으로 올린 번호보다 커야 한다. 마지막 번호는 메모리 `project_apple_developer_team`에 있다. 같거나 작으면 Apple이 업로드를 거절하니, 실행하지 말고 main 버전을 먼저 올려야 한다고 알린다.
- Xcode에 베타 팀(XYNNB47RN3, bss.rol20) 계정이 로그인돼 있어야 한다. 사용자의 비밀번호를 대신 입력하지 않는다.

## 2. 실행

빌드·업로드에 5~10분 걸리므로 백그라운드로 실행하고 완료 알림을 기다린다.

```bash
tools/testflight.sh            # 빌드 + 업로드
tools/testflight.sh --dry-run  # 빌드까지만
```

실패해도 임시 작업 공간은 스크립트가 지운다. 전체 로그는 main 폴더의 `build/testflight/<시각>.log`에 남는다.

## 3. 결과 보고

- 성공: 버전(빌드 번호), main 커밋, 업로드 경고(`⚠️` 줄)를 전한다. 그리고 메모리 `project_apple_developer_team`의 마지막 업로드 번호를 갱신한다.
- 사용자가 할 일을 안내한다.
  1. App Store Connect → 비바나트 베타 → TestFlight에서 처리(5~30분)를 기다린다.
  2. "규정 준수 정보 누락"이 뜨면 **관리**에서 암호화 유형으로 "Apple의 운영 체제 내 암호화를 대체하거나 이와 병행하여 사용하는 표준 암호화 알고리즘"(Flutter BoringSSL·WebRTC DTLS/SRTP)을 고르고, 프랑스 배포는 "아니요"로 답한다.
  3. 내부 테스팅 그룹이 자동 배포면 테스터의 TestFlight 앱에 바로 뜬다.

## 실패했을 때

| 증상 | 원인 | 조치 |
|---|---|---|
| `팀 ID/번들 ID 교체 개수가 3이 아닙니다` | project.pbxproj 구조 변경 | 스크립트의 교체 대상과 개수 검사를 현재 구조에 맞게 고친다 |
| 빌드 실패 `No profiles` / `no devices` | 팀에 등록 기기가 없거나 프로필 갱신 실패 | developer.apple.com Devices에 기기가 있는지 확인 |
| 업로드 실패 — 인증·계정 오류 | Xcode 로그인 만료 | 사용자에게 Xcode Settings → Apple Accounts에서 다시 로그인을 요청 |
| 업로드 실패 — 빌드 번호 중복 | 이미 올린 번호 | main 버전을 올린 뒤 다시 실행 |
