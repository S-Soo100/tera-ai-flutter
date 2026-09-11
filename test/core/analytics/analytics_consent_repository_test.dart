import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivnanaut/core/analytics/analytics_consent.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('analytics_consent');
    Hive.init(dir.path);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test('missing storage fails closed; typed values persist per account',
      () async {
    const repo = HiveAnalyticsConsentRepository();
    expect(repo.load('a'), isFalse);
    await expectLater(repo.save('a', true), throwsStateError);
    await Hive.openBox<Object?>(HiveAnalyticsConsentRepository.boxName);
    await repo.save('a', true);
    expect(repo.load('a'), isTrue);
    expect(repo.load('b'), isFalse);
    await repo.save('a', false);
    expect(repo.load('a'), isFalse);
    await Hive.close();
    await Hive.openBox<Object?>(HiveAnalyticsConsentRepository.boxName);
    expect(repo.load('a'), isFalse);
  });
}
