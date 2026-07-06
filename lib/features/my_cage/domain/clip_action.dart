/// motion_clips 행동 분류 카테고리. behavior 라벨링 enum과 동일 값 재사용.
/// 실제 분류는 백엔드 VLM이 채운다(현재 앱 데이터 0 → 전부 미분류).
const List<String> kClipActions = [
  'moving',
  'shedding',
  'eating_paste',
  'eating_prey',
  'drinking',
  'hand_feeding',
  'unseen',
];

/// action 코드 → i18n 키. `'clip_action_$action'`. 알 수 없는 값은 그대로.
String clipActionKey(String action) => 'clip_action_$action';
