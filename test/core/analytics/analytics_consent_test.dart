import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_consent.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/core/analytics/analytics_recorder.dart';

class MemoryConsentRepository implements AnalyticsConsentRepository {
  final values = <String, bool>{};
  Completer<void>? pending;
  bool fail = false;
  @override
  bool load(String accountId) => values[accountId] ?? false;
  @override
  Future<void> save(String accountId, bool consent) async {
    await pending?.future;
    if (fail) throw StateError('storage');
    values[accountId] = consent;
  }
}

class PausedRecorder extends AnalyticsRecorder {
  int pauses = 0;
  @override
  void suspend() {
    pauses++;
    super.suspend();
  }
}

void main() {
  late MemoryConsentRepository repo;
  late PausedRecorder recorder;
  late ProviderContainer container;
  setUp(() {
    repo = MemoryConsentRepository();
    recorder = PausedRecorder();
    container = ProviderContainer(overrides: [
      analyticsConsentRepositoryProvider.overrideWithValue(repo),
      analyticsRecorderProvider.overrideWithValue(recorder),
    ]);
  });
  tearDown(() => container.dispose());
  test('default false, account isolated and restored without auth dependencies',
      () {
    final controller = container.read(analyticsConsentProvider.notifier);
    expect(container.read(analyticsConsentProvider).granted, isFalse);
    repo.values['a'] = true;
    controller.selectAccount('a');
    expect(container.read(analyticsConsentProvider).granted, isTrue);
    controller.selectAccount('b');
    expect(container.read(analyticsConsentProvider).granted, isFalse);
  });
  test('on requires saved success; off closes gate before await', () async {
    final controller = container.read(analyticsConsentProvider.notifier);
    controller.selectAccount('a');
    repo.pending = Completer<void>();
    final save = controller.setGranted(true);
    expect(container.read(analyticsConsentProvider).granted, isFalse);
    repo.pending!.complete();
    await save;
    expect(container.read(analyticsConsentProvider).granted, isTrue);
    repo.pending = Completer<void>();
    final pauses = recorder.pauses;
    final revoke = controller.setGranted(false);
    expect(recorder.pauses, greaterThan(pauses));
    expect(container.read(analyticsConsentProvider).granted, isFalse);
    repo.pending!.complete();
    await revoke;
  });
  test(
      'write failure cannot grant, old account pending save cannot grant new account',
      () async {
    final controller = container.read(analyticsConsentProvider.notifier);
    controller.selectAccount('a');
    repo.fail = true;
    await controller.setGranted(true);
    expect(container.read(analyticsConsentProvider).granted, isFalse);
    expect(container.read(analyticsConsentProvider).saveFailed, isTrue);
    repo.fail = false;
    repo.pending = Completer<void>();
    final old = controller.setGranted(true);
    controller.selectAccount('b');
    repo.pending!.complete();
    await old;
    expect(container.read(analyticsConsentProvider).accountId, 'b');
    expect(container.read(analyticsConsentProvider).granted, isFalse);
  });

  test('older grant completion cannot unblock a newer pending withdrawal',
      () async {
    final controller = container.read(analyticsConsentProvider.notifier);
    controller.selectAccount('a');
    final first = Completer<void>();
    repo.pending = first;
    final grant = controller.setGranted(true);
    await Future<void>.delayed(Duration.zero);
    controller.selectAccount('b');
    controller.selectAccount('a');
    final second = Completer<void>();
    repo.pending = second;
    final revoke = controller.setGranted(false);
    first.complete();
    await grant;
    controller.selectAccount('b');
    controller.selectAccount('a');
    expect(container.read(analyticsConsentProvider).granted, isFalse);
    second.complete();
    await revoke;
    expect(repo.values['a'], isFalse);
  });
}
