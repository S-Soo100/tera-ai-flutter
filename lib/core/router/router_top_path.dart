import 'package:go_router/go_router.dart';

/// 지금 맨 위에 보이는 화면의 경로.
///
/// 주소(`routeInformationProvider`)는 `push`를 반영하지 않는다(go_router
/// `optionURLReflectsImperativeAPIs` 기본 false) — 예약 화면을 push해 열어도
/// `/home`으로 남는다. "이미 그 화면이면 다시 열지 않기" 같은 판단은 실제 화면
/// 스택으로 해야 한다. 첫 경로를 읽기 전(스택 비어 있음)은 [fallback].
String routerTopPath(GoRouter router, {String fallback = '/splash'}) =>
    router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation ??
    fallback;

/// 알림(서버 푸시·로컬 알림)을 눌러 [route]로 옮겨도 되는가.
///
/// - 강제 업데이트 중이면 옮기지 않는다 — `push`가 redirect된 업데이트 화면을
///   한 장 더 쌓았다(코드 리뷰 2026-11-18). 화면 쪽 정리(`_SinglePage`)는 다른
///   경로로 쌓일 때를 위한 안전망으로만 둔다.
/// - 이미 그 화면이 맨 위면 다시 열지 않는다([routerTopPath]).
bool shouldOpenFromNotification(GoRouter router, String route,
        {required bool updateRequired}) =>
    !updateRequired && routerTopPath(router) != route;
