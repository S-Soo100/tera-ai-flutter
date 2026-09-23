import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/webrtc_diag.dart';

/// 앱 전역 진단 버퍼(카메라 구분은 이벤트의 cameraId). 계정이 바뀌면 비운다 —
/// 다른 계정의 카메라 ID·연결 이력이 남지 않게(3층 계정 격리 규칙).
final webrtcDiagBufferProvider = Provider<WebRtcDiagBuffer>((ref) {
  final buffer = WebRtcDiagBuffer();
  ref.listen<String?>(currentUserProvider.select((u) => u?.id), (prev, next) {
    if (prev != next) buffer.clear();
  });
  return buffer;
});
