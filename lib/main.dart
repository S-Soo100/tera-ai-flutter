import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/storage/safe_hive.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/my_cage/data/video_cache_repository.dart';
import 'features/my_pets/data/pet_repository.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Container(
        color: const Color(0xFF121212),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF4CAF50),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFE0E0E0),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '앱을 다시 시작해 주세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF9E9E9E),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  };

  await Hive.initFlutter();
  await PetRepository.init();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await ChatRepository.init();
  await openUntypedBoxSafely('app_settings');
  await VideoCacheRepository.init();

  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ko'),
      child: const ProviderScope(
        child: App(),
      ),
    ),
  );
}
