import 'dart:async';

import '../data/push_messaging_service.dart';

/// 맥락별로 묻는 알림 주제(Figma 권한 요청 1179:4464 — 프리팝업 2종).
/// 한꺼번에 물으면 뭔지 모르고 거절하므로 필요한 시점에 나눠 묻는다.
enum PushTopic {
  /// 카메라 연결 + 영상 1개 이상 + 카메라 탭 진입 시.
  highlight,

  /// 커뮤니티에 게시물을 올린 뒤. 댓글·좋아요 두 알림을 함께 켜고 끈다.
  community,
}

/// 프리팝업 선택을 시스템 권한 상태에 따라 처리한다(Figma 요청 시나리오).
///
/// | 선택 | 시스템 권한 | 결과 |
/// |---|---|---|
/// | 받기 | 아직 안 물음 | 주제 켬 + 시스템 팝업 |
/// | 받기 | 허용됨·미지원(iOS) | 주제만 켬 |
/// | 받기 | 거절됨 | 주제 켬 + 재요청, 막혀 있으면 앱 설정(retry) |
/// | 받지 않기 | 허용됨·미지원(iOS) | 주제 끔 + "수신 거부 완료" 안내 |
/// | 받지 않기 | 안 물음·거절됨 | 주제 끔, 팝업만 닫힘 |
class PushConsentFlow {
  PushConsentFlow({
    required this.currentPermission,
    required this.requestPermission,
    required this.setTopic,
    required this.isAsked,
    required this.markAsked,
  });

  final Future<PushPermission> Function() currentPermission;
  final Future<void> Function({bool retry}) requestPermission;
  final Future<void> Function(PushTopic topic, bool on) setTopic;
  final bool Function(PushTopic topic) isAsked;
  final Future<void> Function(PushTopic topic) markAsked;

  final _claimed = <PushTopic>{};

  /// 아직 안 물은 주제면 "물음"으로 기록하고 true. 연속 rebuild가 같은
  /// 팝업을 두 번 띄우지 않도록 메모리에서 먼저 막는다.
  bool claim(PushTopic topic) {
    if (_claimed.contains(topic) || isAsked(topic)) return false;
    _claimed.add(topic);
    unawaited(markAsked(topic));
    return true;
  }

  /// 선택을 적용한다. "수신 거부 완료" 안내를 띄워야 하면 true.
  Future<bool> resolve(PushTopic topic, {required bool accept}) async {
    final permission = await currentPermission();
    await setTopic(topic, accept);
    if (!accept) {
      return permission == PushPermission.authorized ||
          permission == PushPermission.unavailable;
    }
    if (permission == PushPermission.notDetermined) {
      await requestPermission();
    } else if (permission == PushPermission.denied) {
      await requestPermission(retry: true);
    }
    return false;
  }
}
