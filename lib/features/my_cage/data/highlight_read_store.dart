import 'package:hive/hive.dart';

typedef HighlightReadKey = ({String ownerId, String cameraId, String batchId});

class HighlightReadStore {
  const HighlightReadStore();
  String _key(HighlightReadKey key) =>
      'highlight_read/${Uri.encodeComponent(key.ownerId)}/${Uri.encodeComponent(key.cameraId)}/${Uri.encodeComponent(key.batchId)}';
  bool read(HighlightReadKey key) =>
      Hive.isBoxOpen('app_settings') &&
      Hive.box('app_settings').get(_key(key)) == true;
  Future<void> markRead(HighlightReadKey key) async {
    if (key.ownerId.isEmpty) return;
    await Hive.box('app_settings').put(_key(key), true);
  }
}
