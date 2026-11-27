import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS 정식 출시 빌드 설정 감시(2026-11-24 계획 `ios-official-release` Task 1).
///
/// main은 정식 값(조직 팀 XYNNB47RN3·번들 com.vivanaut.app·iPhone 전용)을 그대로
/// 들고 있고, TestFlight도 이 값으로 올린다. 다른 팀·번들·기기군이 섞이면
/// 서명이나 심사에서 조용히 어긋나므로 설정 블록 단위로 검사한다.

const String kPbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';
const String kInfoPlistPath = 'ios/Runner/Info.plist';

/// Runner 타깃 설정 3벌(Profile·Debug·Release). 팀·번들·entitlements는 여기에만.
const List<String> kRunnerTargetConfigIds = [
  '249021D4217E4FDB00AE95B9', // Profile
  '97C147061CF9000F007C117D', // Debug
  '97C147071CF9000F007C117D', // Release
];

/// 프로젝트 레벨 설정 3벌(Profile·Debug·Release). 기기군·최소 iOS는 여기에.
const List<String> kProjectLevelConfigIds = [
  '249021D3217E4FDB00AE95B9', // Profile
  '97C147031CF9000F007C117D', // Debug
  '97C147041CF9000F007C117D', // Release
];

/// RunnerTests 타깃 설정 3벌(Debug·Release·Profile). 푸시 entitlements가 들어가면 안 된다.
const List<String> kRunnerTestsConfigIds = [
  '331C8088294A63A400263BE5', // Debug
  '331C8089294A63A400263BE5', // Release
  '331C808A294A63A400263BE5', // Profile
];

const String kEntitlementsPath = 'ios/Runner/Runner.entitlements';
const String kFirebasePlistPath = 'ios/Runner/GoogleService-Info.plist';

/// pbxproj의 XCBuildConfiguration 섹션에서 [configId] 항목
/// (`<id> /* Debug|Release|Profile */ = { … };`)의 `{ … }` 블록 문자열을 돌려준다.
/// 항목이 없으면 [StateError] — id가 바뀌었으면 조용히 통과하지 않고 실패한다.
String buildSettingsBlock(String pbx, String configId) {
  const sectionBegin = '/* Begin XCBuildConfiguration section */';
  const sectionEnd = '/* End XCBuildConfiguration section */';
  final begin = pbx.indexOf(sectionBegin);
  final end = pbx.indexOf(sectionEnd);
  if (begin < 0 || end < 0 || end < begin) {
    throw StateError('XCBuildConfiguration 섹션을 찾지 못했습니다');
  }
  final section = pbx.substring(begin + sectionBegin.length, end);

  final header = RegExp(
    '^\\t\\t${RegExp.escape(configId)} /\\* [^*]+ \\*/ = \\{',
    multiLine: true,
  ).firstMatch(section);
  if (header == null) {
    throw StateError('빌드 설정 $configId 를 찾지 못했습니다');
  }
  // 항목은 탭 2개 들여쓰기 `};`로 닫힌다(안쪽 buildSettings는 탭 3개).
  final close = section.indexOf('\n\t\t};', header.end);
  if (close < 0) {
    throw StateError('빌드 설정 $configId 의 끝을 찾지 못했습니다');
  }
  return section.substring(header.end - 1, close + '\n\t\t}'.length);
}

void main() {
  late String pbx;
  late String infoPlist;

  setUpAll(() {
    pbx = File(kPbxprojPath).readAsStringSync();
    infoPlist = File(kInfoPlistPath).readAsStringSync();
  });

  group('iOS 정식 출시 설정', () {
    test('Runner 타깃 3벌: 정식 팀·번들', () {
      for (final id in kRunnerTargetConfigIds) {
        final block = buildSettingsBlock(pbx, id);
        expect(block, contains('DEVELOPMENT_TEAM = XYNNB47RN3;'),
            reason: '$id: 조직 팀(terraai Co.,Ltd.)이어야 합니다');
        expect(block, contains('PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app;'),
            reason: '$id: 정식 번들이어야 합니다');
      }
      expect(pbx, isNot(contains('8NDUMK7C65')),
          reason: '다른 Apple 계정의 무료 팀 id가 남아 있습니다');
      expect(pbx, isNot(contains('"Tera Ai"')),
          reason: '옛 브랜드 표시 이름이 남아 있습니다');
    });

    test('프로젝트 레벨 3벌: iPhone 전용', () {
      for (final id in kProjectLevelConfigIds) {
        expect(buildSettingsBlock(pbx, id),
            contains('TARGETED_DEVICE_FAMILY = 1;'),
            reason: '$id: iPhone 전용(1)이어야 합니다');
      }
      // 타깃 레벨에서 기기군을 다시 덮어쓰지 않는다.
      for (final id in kRunnerTargetConfigIds) {
        expect(buildSettingsBlock(pbx, id),
            isNot(contains('TARGETED_DEVICE_FAMILY')),
            reason: '$id: Runner 타깃이 기기군을 덮어쓰고 있습니다');
      }
    });

    test('ATS: 로컬 네트워크만 예외', () {
      expect(infoPlist, isNot(contains('NSAllowsArbitraryLoads')),
          reason: '모든 HTTP 허용 키는 심사 질문 거리만 남깁니다');
      expect(infoPlist, contains('NSAllowsLocalNetworking'),
          reason: '로컬 네트워크(기기 직접 통신) 예외는 유지합니다');
    });

    // Task 2 — iOS 푸시(Xcode Signing & Capabilities에서 추가한 결과).
    test('푸시 entitlements는 Runner에만', () {
      const line = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';
      for (final id in kRunnerTargetConfigIds) {
        expect(buildSettingsBlock(pbx, id), contains(line),
            reason: '$id: Runner 타깃에 entitlements가 연결돼야 합니다');
      }
      for (final id in [...kRunnerTestsConfigIds, ...kProjectLevelConfigIds]) {
        expect(buildSettingsBlock(pbx, id),
            isNot(contains('CODE_SIGN_ENTITLEMENTS')),
            reason: '$id: Runner 타깃 밖에는 entitlements를 두지 않습니다');
      }
      final ent = File(kEntitlementsPath);
      expect(ent.existsSync(), isTrue, reason: '$kEntitlementsPath 가 없습니다');
      final text = ent.readAsStringSync();
      expect(text, contains('aps-environment'));
      expect(text,
          contains('com.apple.developer.usernotifications.time-sensitive'));
    });

    test('원격 알림 백그라운드 모드', () {
      expect(infoPlist, contains('UIBackgroundModes'));
      expect(infoPlist, contains('<string>remote-notification</string>'));
    });

    test('Firebase plist가 정식 번들용이고 앱 리소스에 등록', () {
      final plist = File(kFirebasePlistPath);
      expect(plist.existsSync(), isTrue, reason: '$kFirebasePlistPath 가 없습니다');
      expect(
          RegExp(r'<key>BUNDLE_ID</key>\s*<string>com\.vivanaut\.app</string>')
              .hasMatch(plist.readAsStringSync()),
          isTrue,
          reason: 'Firebase plist BUNDLE_ID가 com.vivanaut.app이어야 합니다');
      expect(pbx, contains('GoogleService-Info.plist in Resources'),
          reason: 'Runner 타깃 Copy Bundle Resources에 들어가야 앱에 포함됩니다');
      // 파일 참조는 Runner 그룹(path = Runner) 안에 있어야 ios/Runner/ 파일을 가리킨다.
      // 프로젝트 맨 위에 붙으면 ios/ 사본을 가리키게 된다(2026-11-27 실제로 발생).
      final runnerGroup = RegExp(
        r'97C146F01CF9000F007C117D /\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \(([^)]*)\)',
      ).firstMatch(pbx);
      expect(runnerGroup, isNotNull, reason: 'Runner 그룹을 찾지 못했습니다');
      expect(runnerGroup!.group(1), contains('GoogleService-Info.plist'),
          reason: 'GoogleService-Info.plist 참조가 Runner 그룹 밖에 있습니다');
      expect(File('ios/GoogleService-Info.plist').existsSync(), isFalse,
          reason: 'ios/ 아래에 사본이 남아 있습니다');
    });
  });
}
