import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/clip_memo_repository.dart';
import 'package:vivanaut/features/my_cage/domain/clip_memo.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_memo_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_card.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_memo_editor.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? decoded =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : {};
  }
}

class _Repository implements ClipMemoRepository {
  @override
  Future<ClipMemo?> read(String account, String clip) async => null;
  @override
  Future<void> save(String account, String clip, String text) async {}
  @override
  Future<void> remove(String account, String clip) async {}
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_MEMO')) {
    test('opt-in memo visual capture', () {}, skip: 'CAPTURE_MEMO=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  testWidgets('localized memo dialog and six measured card colors',
      (tester) async {
    final boundary = GlobalKey();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> pump(Size size, bool dialog) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          startLocale: const Locale('ko'),
          path: 'assets/l10n',
          assetLoader: const _Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                      overrides: [
                        clipMemoAccountProvider.overrideWithValue('a'),
                        clipMemoRepositoryProvider
                            .overrideWith((ref) async => _Repository()),
                      ],
                      child: MaterialApp(
                          theme: AppTheme.light,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          builder: (context, child) =>
                              RepaintBoundary(key: boundary, child: child!),
                          home: Scaffold(
                              body: dialog
                                  ? ClipMemoEditor(
                                      memoKey: (ownerId: 'a', clipId: 'c'),
                                      saveBookmark: () async => true)
                                  : Center(
                                      child: Wrap(
                                          spacing: 8,
                                          runSpacing: 20,
                                          children: [
                                          for (var color = 0;
                                              color < 6;
                                              color++)
                                            ClipMemoCard(
                                                memo: ClipMemo(
                                                    clipId: 'c',
                                                    text:
                                                        '눈 귀여워~\n점프하는 순간을 기억해요',
                                                    colorIndex: color,
                                                    updatedAt:
                                                        DateTime.utc(2026)),
                                                memoKey: (
                                                  ownerId: 'a',
                                                  clipId: 'c'
                                                )),
                                        ]))))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/private/tmp/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await pump(const Size(393, 852), true);
    final modal = find.descendant(
        of: find.byType(Dialog), matching: find.byType(Material));
    expect(tester.getSize(modal.first), const Size(345, 298));
    await capture('memo-portrait');
    await pump(const Size(852, 393), true);
    expect(tester.getSize(modal.first), const Size(595, 205));
    await capture('memo-landscape');
    await pump(const Size(393, 852), false);
    await capture('memo-six-colors');
  });
}
