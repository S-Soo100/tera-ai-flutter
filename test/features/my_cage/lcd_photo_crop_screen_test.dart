import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_photo_codec.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_photo_crop_screen.dart';

import 'lcd_fixtures.dart';

void main() {
  setUpAll(initLcdTestStrings);

  testWidgets('공통 헤더·CTA 배치, 사진을 읽기 전엔 완료가 막히고 뒤로는 취소', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LcdPhotoPick? result;
    await tester.pumpWidget(ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const KoStrings(),
        child: Builder(
          builder: (c) => MaterialApp(
            theme: AppTheme.light,
            locale: c.locale,
            supportedLocales: c.supportedLocales,
            localizationsDelegates: c.localizationDelegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 62, bottom: 34)),
                child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async => result = await showLcdPhotoCrop(
                        context,
                        img.encodeJpg(img.Image(width: 50, height: 40))),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('사진 자르기'), findsOneWidget);
    expect(tester.getRect(find.text('사진 자르기')).center.dy, 62 + 22);
    expect(tester.getRect(find.byKey(LcdPhotoCropScreen.doneKey)),
        const Rect.fromLTWH(12, 852 - 34 - 66 - 56, 369, 56));
    expect(
        tester
            .widget<FilledButton>(find.byKey(LcdPhotoCropScreen.doneKey))
            .onPressed,
        isNull,
        reason: '사진을 읽는 중');
    await tester.tap(find.byTooltip('뒤로'));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(LcdPhotoCropScreen), findsNothing);
    expect(result, isA<LcdPhotoCancelled>());
  });
}
