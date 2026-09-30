// UX-04 (2026-10-01): 글쓰기 중 뒤로 가면 확인하고, 계속 작성하면 입력이 남는다.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/community/presentation/clip_select_screen.dart';
import 'package:vivanaut/features/community/presentation/compose_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

final _draft = ComposeDraft(FavoriteClip(
    clipId: 'c1',
    cameraId: 'cam',
    startedAt: DateTime(2026, 9, 30),
    durationSec: 12,
    filePath: '',
    sizeBytes: 0,
    favoritedAt: DateTime(2026, 9, 30),
    ownerId: 'u'));

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => const []),
        motionThumbnailProvider.overrideWith((ref, id) async => null),
      ],
      child: EasyLocalization(
          supportedLocales: const [Locale('ko')],
          startLocale: const Locale('ko'),
          path: 'assets/l10n',
          assetLoader: const _Strings(),
          child: Builder(
              builder: (c) => MaterialApp(
                  theme: AppTheme.light,
                  locale: c.locale,
                  supportedLocales: c.supportedLocales,
                  localizationsDelegates: c.localizationDelegates,
                  home: Builder(
                      builder: (c) => Scaffold(
                          body: TextButton(
                              onPressed: () => Navigator.of(c).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ComposeScreen(draft: _draft))),
                              child: const Text('open')))))))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('입력이 없으면 확인 없이 나간다', (tester) async {
    await _open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsNothing);
  });

  testWidgets('캡션이 있으면 확인 — 계속 작성은 유지, 나가기는 닫힘', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField).first, '우리 크레 밥 먹는 중');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('작성 중인 글이 있어요'), findsOneWidget);
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('우리 크레 밥 먹는 중'), findsOneWidget);

    // 시스템 뒤로 가기도 같은 확인을 거친다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose_exit_leave')));
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsNothing);
  });
}
