enum LickTargetType {
  air, // wire: air
  dish, // wire: dish
  floor, // wire: floor
  wall, // wire: wall
  object, // wire: object
  other, // wire: other (fallback)
  ;

  factory LickTargetType.fromWire(String wire) {
    switch (wire) {
      case 'air':
        return LickTargetType.air;
      case 'dish':
        return LickTargetType.dish;
      case 'floor':
        return LickTargetType.floor;
      case 'wall':
        return LickTargetType.wall;
      case 'object':
        return LickTargetType.object;
      default:
        return LickTargetType.other;
    }
  }

  String toWire() {
    switch (this) {
      case LickTargetType.air:
        return 'air';
      case LickTargetType.dish:
        return 'dish';
      case LickTargetType.floor:
        return 'floor';
      case LickTargetType.wall:
        return 'wall';
      case LickTargetType.object:
        return 'object';
      case LickTargetType.other:
        return 'other';
    }
  }

  String get localizationKey => 'behavior_lick_target_${toWire()}';
}
