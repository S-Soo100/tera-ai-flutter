import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 미읽음 알림 개수. 알림 저장소가 생기기 전까지 0 고정 —
/// 뱃지 표시 로직 자체는 지금 검증 가능해야 하므로 provider로 뺀다.
///
/// 원래 `home_header_bar.dart`에 있었다 — PRD 재설계 1단계(2026-09-02)로
/// 홈 헤더에서 🔔이 빠지고 진입점이 프로필 화면으로 옮겨지면서 여기로 왔다.
final unreadNotificationCountProvider = Provider<int>((ref) => 0);
