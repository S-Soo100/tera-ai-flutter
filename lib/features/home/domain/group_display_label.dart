import '../../my_cage/domain/enclosure.dart';

String groupDisplayLabel(
    {required String? groupId,
    required String individualName,
    required Iterable<Enclosure> groups}) {
  if (groupId == null) return individualName;
  for (final group in groups) {
    if (group.id == groupId) return group.name;
  }
  return individualName;
}
