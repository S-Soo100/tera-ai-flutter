enum ActionType {
  eatingPaste, // wire: eating_paste
  drinking, // wire: drinking
  moving, // wire: moving
  unknown, // wire: unknown (fallback)
  eatingPrey, // wire: eating_prey
  defecating, // wire: defecating
  shedding, // wire: shedding
  basking, // wire: basking
  unseen, // wire: unseen
  ;

  factory ActionType.fromWire(String wire) {
    switch (wire) {
      case 'eating_paste':
        return ActionType.eatingPaste;
      case 'drinking':
        return ActionType.drinking;
      case 'moving':
        return ActionType.moving;
      case 'eating_prey':
        return ActionType.eatingPrey;
      case 'defecating':
        return ActionType.defecating;
      case 'shedding':
        return ActionType.shedding;
      case 'basking':
        return ActionType.basking;
      case 'unseen':
        return ActionType.unseen;
      default:
        return ActionType.unknown;
    }
  }

  String toWire() {
    switch (this) {
      case ActionType.eatingPaste:
        return 'eating_paste';
      case ActionType.drinking:
        return 'drinking';
      case ActionType.moving:
        return 'moving';
      case ActionType.unknown:
        return 'unknown';
      case ActionType.eatingPrey:
        return 'eating_prey';
      case ActionType.defecating:
        return 'defecating';
      case ActionType.shedding:
        return 'shedding';
      case ActionType.basking:
        return 'basking';
      case ActionType.unseen:
        return 'unseen';
    }
  }

  String get localizationKey => 'behavior_action_${toWire()}';
}
