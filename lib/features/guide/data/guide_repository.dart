import '../domain/guide_step.dart';

class GuideRepository {
  static const List<GuideStep> _steps = [
    GuideStep(
      order: 1,
      title: '정부24 접속',
      description: '정부24(gov.kr)에 접속하여 로그인합니다',
      detail:
          '공인인증서, 간편인증(카카오/네이버/PASS 등) 모두 사용 가능합니다. 회원가입이 안 되어 있다면 먼저 가입하세요.',
    ),
    GuideStep(
      order: 2,
      title: '야생생물 사육 신고 검색',
      description: '검색창에 \'야생생물 사육 신고\'를 입력합니다',
      detail:
          '검색 결과에서 \'야생생물 사육 신고\' 민원을 선택합니다. 유사한 이름의 다른 민원과 혼동하지 않도록 주의하세요.',
    ),
    GuideStep(
      order: 3,
      title: '신고서 작성',
      description: '양식에 따라 보유 동물 정보를 입력합니다',
      detail:
          '동물의 종명(학명), 수량, 취득 일자, 취득 경위를 정확히 기입합니다. 여러 마리를 보유한 경우 종별로 각각 신고해야 합니다.',
    ),
    GuideStep(
      order: 4,
      title: '서류 첨부',
      description: '필요 서류를 스캔 또는 촬영하여 첨부합니다',
      detail:
          '신분증 사본, 취득 경위서(구매 영수증, 분양 확인서, 지인 양도 확인서 등)를 첨부합니다. 서류가 없는 경우 사유서를 작성합니다.',
    ),
    GuideStep(
      order: 5,
      title: '제출 및 확인',
      description: '신고서를 제출하고 접수 번호를 확인합니다',
      detail:
          '제출 후 접수 번호가 발급됩니다. 처리 기간은 보통 7~14일이며, 정부24 \'나의 서비스\'에서 진행 상태를 확인할 수 있습니다.',
    ),
  ];

  static final DateTime deadline = DateTime(2026, 6, 13);

  static const List<String> requiredDocuments = [
    '신분증',
    '야생생물 사육신고서 (정부24 양식)',
    '취득 경위서',
  ];

  List<GuideStep> getSteps() => _steps;

  DateTime getDeadline() => deadline;

  List<String> getRequiredDocuments() => requiredDocuments;

  int getDaysRemaining() {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    return diff.inDays;
  }
}
