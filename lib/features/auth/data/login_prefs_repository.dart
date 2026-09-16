import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 로그인 화면 로컬 설정 — 마지막 아이디·자동 로그인.
///
/// 비밀번호는 저장하지 않는다(Figma 일부 프레임의 "비밀번호 기억하기" 라벨은
/// 채택하지 않음, 2026-09-16 계획 B3). `autoLogin`이 꺼져 있으면 앱을 다시
/// 열 때 스플래시가 세션을 끊고 로그인으로 보낸다.
abstract class LoginPrefsRepository {
  String? get lastEmail;
  bool get autoLogin;
  Future<void> save({required String email, required bool autoLogin});
}

class HiveLoginPrefsRepository implements LoginPrefsRepository {
  HiveLoginPrefsRepository(this._box);
  final Box<dynamic> _box;
  static const _emailKey = 'last_login_email';
  static const _autoKey = 'auto_login';

  @override
  String? get lastEmail => _box.get(_emailKey) as String?;

  /// 기록이 없는 기존 설치는 켜짐으로 본다(지금까지 세션이 유지되던 동작).
  @override
  bool get autoLogin => (_box.get(_autoKey) as bool?) ?? true;

  @override
  Future<void> save({required String email, required bool autoLogin}) async {
    await _box.put(_emailKey, email);
    await _box.put(_autoKey, autoLogin);
  }
}

final loginPrefsProvider = Provider<LoginPrefsRepository>(
    (ref) => HiveLoginPrefsRepository(Hive.box('app_settings')));
