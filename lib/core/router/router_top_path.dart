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
