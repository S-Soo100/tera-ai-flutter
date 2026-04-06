import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/domain/species.dart';
import '../../home/presentation/home_providers.dart';

final speciesDetailProvider = Provider.family<Species?, String>((ref, id) {
  final repo = ref.watch(speciesRepositoryProvider);
  return repo.getById(id);
});
