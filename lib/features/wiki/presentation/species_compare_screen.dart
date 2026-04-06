import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/care_info_repository.dart';
import '../domain/care_info_detail.dart';
import 'wiki_providers.dart';

class SpeciesCompareScreen extends ConsumerWidget {
  const SpeciesCompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesIds = CareInfoRepository.featuredSpeciesIds;
    final asyncValues = speciesIds.map((id) => ref.watch(careInfoProvider(id)));

    // Check if any is loading or errored
    final isLoading = asyncValues.any((v) => v.isLoading);
    final firstError = asyncValues
        .where((v) => v.hasError)
        .map((v) => v.error)
        .firstOrNull;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('종 비교')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (firstError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('종 비교')),
        body: Center(child: Text('데이터를 불러올 수 없습니다: $firstError')),
      );
    }

    final infos = asyncValues.map((v) => v.value!).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('종 비교')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            columnSpacing: 20,
            columns: [
              const DataColumn(label: Text('항목')),
              ...infos.map((info) => DataColumn(
                    label: Text(
                      info.speciesNameKo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
            ],
            rows: _buildRows(infos),
          ),
        ),
      ),
    );
  }

  List<DataRow> _buildRows(List<CareInfoDetail> infos) {
    return [
      _row('난이도', infos.map((i) => i.difficulty)),
      _row('수명', infos.map((i) => i.lifespan)),
      _row('크기', infos.map((i) => i.adultSize)),
      _row('핫존', infos.map((i) => '${i.hotZone.display}${i.tempUnit}')),
      _row('쿨존', infos.map((i) => '${i.coolZone.display}${i.tempUnit}')),
      _row('야간', infos.map((i) => '${i.night.display}${i.tempUnit}')),
      _row('습도',
          infos.map((i) => '${i.humidityMin}~${i.humidityMax}%')),
      _row('사육장 크기', infos.map((i) => i.minSize)),
      _row('주식', infos.map((i) => i.mainDiet.join(', '))),
      _row('급여 주기', infos.map((i) => i.feedingFrequency)),
    ];
  }

  DataRow _row(String label, Iterable<String> values) {
    return DataRow(cells: [
      DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      ...values.map((v) => DataCell(Text(v))),
    ]);
  }
}
