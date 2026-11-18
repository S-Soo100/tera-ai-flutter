import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/router/router_top_path.dart';

void main() {
  late GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      GoRoute(path: '/env-detail', builder: (_, __) => const Text('env')),
      GoRoute(
          path: '/community-player/:id',
          builder: (_, s) => Text('player ${s.pathParameters['id']}')),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('push한 화면이 맨 위면 주소(/home)가 아니라 그 화면을 돌려준다',
      (tester) async {
    await pump(tester);
    expect(routerTopPath(router), '/home');

    router.push('/env-detail');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home',
        reason: '주소는 push를 반영하지 않는다 — 그래서 헬퍼가 필요하다');
    expect(routerTopPath(router), '/env-detail');
  });

  testWidgets('경로 변수는 채워진 실제 경로로 돌려준다', (tester) async {
    await pump(tester);
    const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
    router.push('/community-player/$id');
    await tester.pumpAndSettle();
    expect(routerTopPath(router), '/community-player/$id');
  });

  testWidgets('알림 이동: 강제 업데이트 중이면 이동하지 않는다(코드 리뷰 2026-11-18)',
      (tester) async {
    await pump(tester);
    expect(shouldOpenFromNotification(router, '/env-detail',
            updateRequired: true),
        isFalse,
        reason: 'push가 redirect된 업데이트 화면을 한 장 더 쌓는다');
    expect(shouldOpenFromNotification(router, '/env-detail',
            updateRequired: false),
        isTrue);
  });

  testWidgets('알림 이동: 이미 맨 위 화면이면 다시 열지 않는다', (tester) async {
    await pump(tester);
    router.push('/env-detail');
    await tester.pumpAndSettle();
    expect(shouldOpenFromNotification(router, '/env-detail',
            updateRequired: false),
        isFalse);
    expect(shouldOpenFromNotification(router, '/home', updateRequired: false),
        isTrue);
  });
}
