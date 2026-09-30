// UX-05 (2026-10-01): 오프라인 안내는 화면을 덮지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/shared/widgets/offline_banner.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('안내 아래 화면은 보이고 눌리며, 안내를 누르면 재확인', (tester) async {
    var taps = 0;
    var retries = 0;
    final input = TextEditingController(text: '작성 중');
    await tester.pumpWidget(EasyLocalization(
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
                builder: (context, child) => Stack(children: [
                      child!,
                      Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: OfflineBanner(onRetry: () => retries++)),
                    ]),
                home: Scaffold(
                    body: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: input),
                  TextButton(
                      onPressed: () => taps++, child: const Text('탭 이동')),
                ])))))));
    await tester.pumpAndSettle();
    expect(find.text('인터넷 연결 없음'), findsOneWidget);
    expect(find.text('작성 중'), findsOneWidget);
    await tester.tap(find.text('탭 이동'));
    expect(taps, 1);
    await tester.tap(find.byKey(OfflineBanner.retryKey));
    expect(retries, 1);
  });
}
