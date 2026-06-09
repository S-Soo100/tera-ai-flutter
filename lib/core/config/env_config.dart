import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경 변수 접근점.
/// dotenv.load()는 main.dart에서 앱 초기화 시 이미 호출됨.
class EnvConfig {
  EnvConfig._();

  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  /// terra-server (IoT: 페어링, 디바이스, 명령). 현재 앱과 동일한 Supabase 프로젝트를 공유한다.
  static String get terraServerUrl =>
      dotenv.env['TERRA_SERVER_URL'] ?? 'https://api.terra-server.uk';
}
