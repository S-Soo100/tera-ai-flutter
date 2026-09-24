import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/storage/safe_hive.dart';
import 'features/my_cage/data/favorite_clip_repository.dart';
import 'features/my_cage/data/video_cache_repository.dart';
import 'features/my_pets/data/pet_repository.dart';
import 'features/notification/data/push_messaging_service.dart';
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
            // 이 화면은 배경이 #121212로 고정이라 어두운 brandNavy를 쓰면
            // 아이콘이 보이지 않는다. 경고 상황이므로 warning을 쓴다.
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warning,
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

  // 앱 전체는 세로 고정. 모든 화면이 세로 폭을 전제로 짜여 있다.
  // 영상 재생만 예외로 가로를 켰다가 나갈 때 여기로 되돌린다
  // (`MotionClipPlayerScreen`). 전역을 안 잠그면 가로로 본 뒤 화면을 닫았을 때
  // 홈이 가로로 남는다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Hive.initFlutter();
  await PetRepository.init();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await PushMessagingService.initialize();
  await openUntypedBoxSafely('app_settings');
  await VideoCacheRepository.init();
  await FavoriteClipRepository.init();

  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ko'),
      // Clarity 세션 리플레이는 2026-09-25 사용자 결정으로 꺼 두었다 — 동의·마스킹
      // 정책(archive/codex/clarity-policy)이 재설계 이전 화면 기준이라 현재 구조에
      // 맞춰 다시 설계하기 전까지 수집하지 않는다. 재개 시 `ClarityWidget`으로
      // `App`을 감싸고 `core/analytics/clarity_setup.dart`의 설정을 넘긴다.
      child: const ProviderScope(child: App()),
    ),
  );
}
