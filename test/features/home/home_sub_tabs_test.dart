import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/device_mode.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/home_sub_tabs_bar.dart';

Future<ProviderContainer> _pump(WidgetTester tester, DeviceMode mode) async {
  final c = ProviderContainer(overrides: [
    currentDeviceModeProvider.overrideWith((ref) async => mode),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomeSubTabsBar())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

bool _enabled(WidgetTester tester, Key key) {
  final w = tester.widget<InkWell>(
      find.descendant(of: find.byKey(key), matching: find.byType(InkWell)));
  return w.onTap != null;
}

void main() {
  testWidgets('integrated — 두 탭 모두 활성', (tester) async {
    await _pump(tester, DeviceMode.integrated);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isTrue);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isTrue);
  });

  testWidgets('cageOnly — 타임라인 비활성', (tester) async {
    await _pump(tester, DeviceMode.cageOnly);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isTrue);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isFalse);
  });

  testWidgets('camOnly — 사육장 제어 비활성', (tester) async {
    await _pump(tester, DeviceMode.camOnly);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isFalse);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isTrue);
  });

  testWidgets('camOnly 진입 시 기본 선택은 타임라인', (tester) async {
    final c = await _pump(tester, DeviceMode.camOnly);
    expect(c.read(homeSubTabProvider), HomeSubTab.timeline);
  });

  testWidgets('활성 탭을 누르면 선택이 바뀐다', (tester) async {
    final c = await _pump(tester, DeviceMode.integrated);
    await tester.tap(find.byKey(HomeSubTabsBar.timelineKey));
    await tester.pumpAndSettle();
    expect(c.read(homeSubTabProvider), HomeSubTab.timeline);
  });

  testWidgets('모드 로딩 중에는 기본 탭을 건드리지 않는다 — 통합 세트가 타임라인으로 열리는 회귀 방지',
      (tester) async {
    // 모드가 아직 안 온 상태(loading). 폴백 DeviceMode.none이 두 탭을 다
    // 비활성으로 만들어 교정이 돌면 control → timeline으로 넘어가버린다.
    final c = ProviderContainer(overrides: [
      currentDeviceModeProvider.overrideWith((ref) => Completer<DeviceMode>()
          .future), // 영원히 pending
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: HomeSubTabsBar())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(c.read(homeSubTabProvider), HomeSubTab.control);
  });

  testWidgets('비활성 탭을 눌러도 선택이 안 바뀐다', (tester) async {
    final c = await _pump(tester, DeviceMode.cageOnly);
    await tester.tap(find.byKey(HomeSubTabsBar.timelineKey));
    await tester.pumpAndSettle();
    expect(c.read(homeSubTabProvider), HomeSubTab.control);
  });
}
