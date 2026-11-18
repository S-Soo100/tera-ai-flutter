import '../../../core/router/tab_branches.dart';
import 'local_notification_target.dart';
import 'notification_open_target.dart';

/// 알림 탭으로 화면을 옮겨도 되는 경로인가. 스플래시·로그인/가입 흐름·강제
/// 업데이트 화면에서는 보관만 한다 — 로그인 직후 redirect보다 먼저 옮기면
/// `/login`이 기록에 남고, 강제 업데이트 중에는 redirect가 어차피 막는다.
bool canOpenLocalTapAt(String path) {
  bool under(String p) => path == p || path.startsWith('$p/');
  if (under('/splash') || under(kUpdateRequiredPath)) return false;
  return !kAuthFlowPaths.any(under);
}

/// 로컬 알림(예약·팬 타이머) 탭 처리(2026-11-16, 계획 §1-E·F·G).
///
/// 탭은 [hold]로 보관하고 [flush]가 조건이 맞을 때 처리한다 — 로그인 사용자가
/// 있고 [canOpenLocalTapAt]인 경로. 호출한 쪽(관찰자)이 경로·계정이 바뀔 때마다
/// [flush]를 부른다. 처리는 기기 선택(최대 [timeout]) → 이동 순서라 다른 사육장
/// 예약이 잠깐 보이지 않는다. 선택을 기다리는 동안 계정이 바뀌었거나
/// [dispose]됐으면 선택·이동 없이 버린다.
class LocalTapRouter {
  LocalTapRouter({
    required String? Function() currentUserId,
    required String Function() currentPath,
    required Future<Iterable<String>> Function() myDeviceIds,
    required void Function(String deviceId) select,
    required void Function(String route) open,
    Duration timeout = const Duration(seconds: 5),
  })  : _currentUserId = currentUserId,
        _currentPath = currentPath,
        _myDeviceIds = myDeviceIds,
        _select = select,
        _open = open,
        _timeout = timeout;

  final String? Function() _currentUserId;
  final String Function() _currentPath;
  final Future<Iterable<String>> Function() _myDeviceIds;
  final void Function(String deviceId) _select;
  final void Function(String route) _open;
  final Duration _timeout;

  DeviceNotificationTarget? _pending;
  bool _busy = false;
  bool _disposed = false;

  bool get hasPending => _pending != null;

  /// 가장 최근 탭만 남긴다 — 여러 알림을 연달아 눌렀으면 마지막이 의도다.
  void hold(DeviceNotificationTarget target) {
    if (!_disposed) _pending = target;
  }

  /// 처리 중이면 바로 돌아온다 — 진행 중 처리가 끝나면 남은 탭을 이어서 본다.
  Future<void> flush() async {
    if (_disposed || _busy) return;
    final target = _pending;
    if (target == null) return;
    final userId = _currentUserId();
    if (userId == null || !canOpenLocalTapAt(_currentPath())) return;
    _pending = null;
    _busy = true;
    try {
      bool stillValid() => !_disposed && _currentUserId() == userId;
      final selected = await selectNotificationDevice(target.deviceId,
          myDeviceIds: _myDeviceIds,
          select: (id) {
            if (stillValid()) _select(id);
          },
          timeout: _timeout);
      if (!stillValid()) return;
      _open(target.routeAfterSelect(selected: selected));
    } finally {
      _busy = false;
    }
    if (_pending != null) await flush();
  }

  void dispose() {
    _disposed = true;
    _pending = null;
  }
}
