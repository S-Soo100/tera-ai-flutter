import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationTestTranslations extends AssetLoader {
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final json = jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return json is Map<String, Object?> ? json : {};
  }
}

Future<void> initializeNotificationLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
}

Widget localizedNotificationHost(Widget Function(BuildContext) builder) =>
    EasyLocalization(
      supportedLocales: const [Locale('ko')],
      startLocale: const Locale('ko'),
      path: 'assets/l10n',
      assetLoader: NotificationTestTranslations(),
      child: Builder(builder: builder),
    );
