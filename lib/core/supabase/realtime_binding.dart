import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/connectivity_provider.dart';
import 'resilient_channel.dart';

/// provider 수명에 묶인 [ResilientChannel]을 만들고 시작한다.
///
/// 상태 콜백 외에 두 신호에서도 즉시 다시 구독한다 — 폰 망이 끊겼다 돌아올 때
/// (`connectivityProvider` false→true), 앱이 백그라운드에서 돌아올 때. 둘 다
/// 소켓이 죽었을 가능성이 가장 높은 순간이고, 라이브러리 재접속이 조용히 실패해도
/// 여기서 복구된다(2026-09-24 S21+ 실측).
ResilientChannel bindResilientChannel(
  Ref ref, {
  required SupabaseClient supabase,
  required String name,
  required RealtimeChannel Function(RealtimeChannel channel) configure,
  VoidCallback? onRejoined,
}) {
  final rc = ResilientChannel(
    name: name,
    build: () => configure(supabase.channel(name)),
    remove: (c) async => supabase.removeChannel(c),
    onRejoined: onRejoined,
  )..start();

  ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
    if (prev?.valueOrNull == false && next.valueOrNull == true) {
      unawaited(rc.restart('network-back'));
    }
  });
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(rc.restart('resume')),
  );

  ref.onDispose(() {
    lifecycle.dispose();
    rc.dispose();
  });
  return rc;
}
