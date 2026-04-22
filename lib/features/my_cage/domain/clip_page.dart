import 'clip.dart';

class ClipPage {
  final List<Clip> items;
  final DateTime? nextCursor;
  final bool hasMore;

  const ClipPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}
