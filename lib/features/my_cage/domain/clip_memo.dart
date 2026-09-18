class ClipMemo {
  const ClipMemo({
    required this.clipId,
    required this.text,
    required this.colorIndex,
    required this.updatedAt,
  });

  final String clipId;
  final String text;
  final int colorIndex;
  final DateTime updatedAt;
}
