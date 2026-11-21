# 알림 권한 프리팝업 계약

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

## 알림 권한 프리팝업 (2026-09-18)

**알림 권한 프리팝업 (2026-09-18, Figma 권한 요청 `1179:4464`):** 로그인 직후 일괄 시트는 폐지. `PushConsentFlow`(`notification/domain/push_consent_flow.dart`)가 선택×시스템 권한 분기를, `push_pre_popup.dart`가 팝업을 맡는다. 시점 = 하이라이트: 카메라 탭이 보이고 카메라+클립 1개 이상(`CrecamScreen._maybeAskHighlightPush`) / 커뮤니티: 게시 성공 직후(`compose_screen`). / **사육장(사용자 추가, Figma 밖): 사육장 기기 등록 결과 직후**(`device_add_flow_screen`, 합류 확인 뒤) — 토글이 없어 시스템 권한이 미요청·거절일 때만 묻고(`canAsk`), 받지 않기는 닫기만. 주제별 1회(Hive `push_prompt_asked_<topic>`), 받지 않기=해당 토글 끔. iOS(FCM 미지원 `unavailable`)도 팝업은 뜨고 토글만 바꾼다(사용자 결정). 휴대폰 글자를 키우면 제목은 줄마다 축소, 본문은 어절 단위 줄바꿈(`keepAllWords`). **기기 알림 꺼짐 안내(Figma 밖, 사용자 결정):** 알림 설정 화면은 시스템 권한 denied/notDetermined면 상단 안내+"알림 허용" 버튼 하나(문구 통일 — 팝업 가능하면 팝업, 막혔으면 앱 설정, `requestPushPermission(retry:true)`)을 띄우고 기능 토글 3개를 흐리게·조작 불가로 둔다(저장값 유지, 복귀 시 `PushLifecycleObserver`가 권한 재조회).
