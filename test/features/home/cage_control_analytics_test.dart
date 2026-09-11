import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';
import 'package:vivnanaut/features/home/domain/mist_duration.dart';
import 'package:vivnanaut/features/home/presentation/cage_control_actions.dart';
import 'package:vivnanaut/features/my_cage/domain/device_command.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';

class _Analytics extends AnalyticsRecorder {
  final events = <AnalyticsEvent>[];
  @override
  int epoch = 1;
  @override
  void record(AnalyticsEvent event, {int? epoch}) {
    if (epoch == null || epoch == this.epoch) events.add(event);
  }
}

class _Sender extends ModuleCommandSender {
  final result = Completer<DeviceCommand>();
  CommandAction? action;
  Map<String, Object?>? payload;
  @override
  Future<DeviceCommand> send(String deviceId, CommandAction action,
      {Map<String, Object?>? payload, int? ttlSec}) {
    this.action = action;
    this.payload = payload;
    return result.future;
  }
}

void main() {
  for (final mist in [false, true]) {
    testWidgets('${mist ? '분무' : '절대 팬 끄기'} 요청과 실패를 분리하고 명령을 보존한다',
        (tester) async {
      final analytics = _Analytics();
      final sender = _Sender();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          analyticsRecorderProvider.overrideWithValue(analytics),
          moduleCommandSenderProvider.overrideWith(() => sender),
        ],
        child: MaterialApp(
            home: Scaffold(body: Consumer(builder: (context, ref, _) {
          return TextButton(
              onPressed: () {
                if (mist) {
                  mistOnce(context, ref, 'private-device',
                      MistDuration.threeSeconds);
                } else {
                  sendCageCommand(
                      context, ref, 'private-device', CommandAction.fanOff);
                }
              },
              child: const Text('send'));
        }))),
      ));
      expect(analytics.events, isEmpty);
      await tester.tap(find.text('send'));
      await tester.pump();
      expect(analytics.events, [AnalyticsEvent.controlRequested]);
      expect(sender.action, mist ? CommandAction.mist : CommandAction.fanOff);
      expect(sender.payload, mist ? {'duration_ms': 3000} : null);
      sender.result.completeError(StateError('private error details'));
      await tester.pump();
      expect(analytics.events,
          [AnalyticsEvent.controlRequested, AnalyticsEvent.controlFailed]);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('제어 요청 후 동의 경계가 바뀌면 늦은 실패를 새 기록에 넣지 않는다', (tester) async {
    final analytics = _Analytics();
    final sender = _Sender();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          analyticsRecorderProvider.overrideWithValue(analytics),
          moduleCommandSenderProvider.overrideWith(() => sender),
        ],
        child: MaterialApp(
            home: Scaffold(body: Consumer(builder: (context, ref, _) {
          return TextButton(
              onPressed: () =>
                  sendCageCommand(context, ref, 'device', CommandAction.fanOff),
              child: const Text('send'));
        })))));
    await tester.tap(find.text('send'));
    await tester.pump();
    analytics.epoch++;
    sender.result.completeError(StateError('late failure'));
    await tester.pump();
    expect(analytics.events, [AnalyticsEvent.controlRequested]);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('서버 접수 결과는 기기 ACK 없이 accepted로만 기록한다', (tester) async {
    final analytics = _Analytics();
    final sender = _Sender();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          analyticsRecorderProvider.overrideWithValue(analytics),
          moduleCommandSenderProvider.overrideWith(() => sender),
        ],
        child: MaterialApp(
            home: Scaffold(body: Consumer(builder: (context, ref, _) {
          return TextButton(
              onPressed: () =>
                  sendCageCommand(context, ref, 'device', CommandAction.fanOff),
              child: const Text('send'));
        })))));
    await tester.tap(find.text('send'));
    await tester.pump();
    // Existing behavior skips ACK observation after leaving the control screen.
    await tester.pumpWidget(const SizedBox());
    sender.result.complete(const DeviceCommand(
      id: 'private-command',
      deviceId: 'device',
      issuedBy: 'private-account',
      action: CommandAction.fanOff,
      payload: null,
      status: CommandStatus.sent,
      result: null,
      issuedAt: null,
      ackedAt: null,
    ));
    await tester.pump();
    expect(analytics.events,
        [AnalyticsEvent.controlRequested, AnalyticsEvent.controlAccepted]);
  });
}
