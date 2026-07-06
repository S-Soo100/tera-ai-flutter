import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 온라인 여부 스트림. connectivity_plus의 네트워크 인터페이스 상태 기반
/// (모든 결과가 none이면 offline). 실제 인터넷 도달성이 아니라 인터페이스
/// 유무만 감지한다 — 비행기모드·Wi-Fi 끊김 등 "연결 없음"을 잡는다.
///
/// 초기/로딩 구간엔 App builder에서 `?? true`로 online 취급해 앱 시작 시
/// 오버레이가 깜빡이는 것을 막는다. 재시도는 `ref.invalidate`로 재구독.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_online);
});

bool _online(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
