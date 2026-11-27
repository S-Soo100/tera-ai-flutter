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
  });
}
