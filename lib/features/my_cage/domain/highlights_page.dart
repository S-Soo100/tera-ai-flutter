import 'action_type.dart';
import 'clip.dart';

enum HighlightSource {
  human, // wire: human
  vlm, // wire: vlm
  ;

  factory HighlightSource.fromWire(String wire) {
    switch (wire) {
      case 'human':
        return HighlightSource.human;
      case 'vlm':
        return HighlightSource.vlm;
      default:
        return HighlightSource.vlm;
    }
  }

  String toWire() {
    switch (this) {
      case HighlightSource.human:
        return 'human';
      case HighlightSource.vlm:
        return 'vlm';
    }
  }
}

class HighlightItem {
  final Clip clip;
  final ActionType highlightAction;
  final HighlightSource highlightSource;

  const HighlightItem({
    required this.clip,
    required this.highlightAction,
    required this.highlightSource,
  });

  factory HighlightItem.fromJson(Map<String, dynamic> json) {
    return HighlightItem(
      clip: Clip.fromJson(json),
      highlightAction:
          ActionType.fromWire(json['highlight_action'] as String),
      highlightSource:
          HighlightSource.fromWire(json['highlight_source'] as String),
    );
  }
}

class HighlightsPage {
  final List<HighlightItem> items;
  final DateTime? nextCursor;

  const HighlightsPage({
    required this.items,
    this.nextCursor,
  });

  static const empty = HighlightsPage(items: [], nextCursor: null);

  bool get hasMore => nextCursor != null;

  factory HighlightsPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List;
    final nextCursorRaw = json['next_cursor'] as String?;
    return HighlightsPage(
      items: itemsRaw
          .map((e) => HighlightItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor:
          nextCursorRaw != null ? DateTime.parse(nextCursorRaw) : null,
    );
  }
}
