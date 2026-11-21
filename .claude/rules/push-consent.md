---
paths:
  - "lib/features/notification/**"
  - "lib/features/profile/presentation/notification_settings_screen.dart"
  - "lib/features/my_cage/presentation/crecam_screen.dart"
  - "lib/features/my_cage/presentation/device_add_flow_screen.dart"
  - "lib/features/community/presentation/compose_screen.dart"
  - "lib/features/auth/**"
---
# 알림 권한 규칙

경위·시점 전문: `docs/contracts/push-consent.md`.

- 로그인 직후 일괄 시트는 폐지했다. 분기는 `PushConsentFlow`, 팝업은 `push_pre_popup.dart`가 맡는다.
- 묻는 시점은 주제별로 다르다: 하이라이트(카메라 탭이 보이고 카메라 + 클립 1개 이상, `CrecamScreen`), 커뮤니티(게시 성공 직후, `compose_screen`), 사육장(기기 등록 결과 직후, `device_add_flow_screen`).
- 주제별 1회만 묻는다(Hive `push_prompt_asked_<topic>`). "받지 않기"는 해당 토글을 끈다.
- 사육장 주제는 토글이 없다. 시스템 권한이 미요청·거절일 때만 묻고(`canAsk`), "받지 않기"는 닫기만 한다.
- 토글이 있는 주제는 iOS(FCM 미지원 `unavailable`)에서도 팝업을 띄우고 토글만 바꾼다(사용자 결정).
- 휴대폰 글자를 키우면 제목은 줄마다 축소, 본문은 어절 단위 줄바꿈(`keepAllWords`).
- 알림 설정 화면은 시스템 권한이 denied/notDetermined면 상단 안내 + "알림 허용" 버튼 하나를 띄우고(팝업 가능하면 팝업, 막혔으면 앱 설정 — `requestPushPermission(retry:true)`), 기능 토글 3개를 흐리게·조작 불가로 둔다(저장값 유지). 앱 복귀 시 권한을 다시 조회한다(`PushLifecycleObserver`).
