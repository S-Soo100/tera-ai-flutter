import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/env_alert_prefs_repository.dart';

/// 온습도 이탈 알림 수신 설정(계정 단위, v4 D2). autoDispose — 화면을 벗어나면
/// 버리고 다시 들어올 때 서버 값을 읽는다(다른 기기에서 바꾼 값 반영).
///
/// 계정 id만 select-watch한다(CLAUDE.md 인증 provider stale 방지) — 계정이
/// 바뀌면 그 계정 행을 다시 읽는다. 로그아웃 상태는 [EnvAlertPrefs.allOn].
final envAlertPrefsProvider =
    AsyncNotifierProvider.autoDispose<EnvAlertPrefsNotifier, EnvAlertPrefs>(
  EnvAlertPrefsNotifier.new,
);

class EnvAlertPrefsNotifier extends AutoDisposeAsyncNotifier<EnvAlertPrefs> {
  String? _userId;

  /// build가 다시 돌 때마다 오른다(계정 전환·재조회). 저장 응답이 돌아왔을 때
  /// 세대가 바뀌었으면 그 응답은 지금 상태에 손대지 않는다.
  int _gen = 0;
  bool _disposed = false;

  @override
  Future<EnvAlertPrefs> build() async {
    _gen++;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    _userId = userId;
    if (userId == null) return EnvAlertPrefs.allOn;
    return ref.watch(envAlertPrefsRepositoryProvider(userId)).load();
  }

  /// 온도 이탈 알림 켜기/끄기. 낙관적으로 먼저 바꾸고, 실패하면 이 필드만
  /// 원래대로 되돌린 뒤 예외를 다시 던진다(화면이 안내를 띄운다).
  Future<void> setTemp(bool on) => _set(
        read: (p) => p.temp,
        write: (p, v) => p.copyWith(temp: v),
        save: (repo) => repo.setTemp(on),
        on: on,
      );

  /// 습도 이탈 알림 켜기/끄기. 규칙은 [setTemp]와 같다.
  Future<void> setHumid(bool on) => _set(
        read: (p) => p.humid,
        write: (p, v) => p.copyWith(humid: v),
        save: (repo) => repo.setHumid(on),
        on: on,
      );

  Future<void> _set({
    required bool Function(EnvAlertPrefs) read,
    required EnvAlertPrefs Function(EnvAlertPrefs, bool) write,
    required Future<void> Function(EnvAlertPrefsRepository) save,
    required bool on,
  }) async {
    final userId = _userId;
    final current = state.valueOrNull;
    if (userId == null) throw StateError('env alert prefs: signed out');
    if (current == null) throw StateError('env alert prefs: not loaded');

    final previous = read(current);
    final gen = _gen;
    // 저장소는 계정 id로 고정해 꺼낸다 — 응답 전에 계정이 바뀌어도 이 쓰기는
    // 시작한 계정 행으로만 간다.
    final repo = ref.read(envAlertPrefsRepositoryProvider(userId));
    state = AsyncData(write(current, on));
    try {
      await save(repo);
    } catch (_) {
      // 원복은 이 필드만 — 동시에 바꾼 다른 토글의 결과를 덮지 않는다.
      final latest = state.valueOrNull;
      if (!_disposed && gen == _gen && latest != null) {
        state = AsyncData(write(latest, previous));
      }
      rethrow;
    }
  }
}
