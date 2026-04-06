import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../home/domain/care_info.dart';

class CareInfoCard extends StatelessWidget {
  final CareInfo careInfo;

  const CareInfoCard({super.key, required this.careInfo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'care_info_title'.tr()),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'care_hot_zone'.tr(),
              value: '${careInfo.hotZone}°C',
            ),
            _InfoRow(
              label: 'care_cool_zone'.tr(),
              value: '${careInfo.coolZone}°C',
            ),
            _InfoRow(
              label: 'care_night'.tr(),
              value: '${careInfo.night}°C',
            ),
            _InfoRow(
              label: 'care_humidity'.tr(),
              value: careInfo.isAquatic
                  ? 'care_humidity_aquatic'.tr()
                  : '${careInfo.humidity}%',
            ),
            _InfoRow(
              label: 'care_enclosure'.tr(),
              value: careInfo.enclosure,
            ),
            _ChipRow(
              label: 'care_substrate'.tr(),
              items: careInfo.substrate,
            ),
            _ChipRow(
              label: 'care_essentials'.tr(),
              items: careInfo.essentials,
            ),
            const Divider(),
            _SectionHeader(title: 'care_diet_title'.tr()),
            const SizedBox(height: 8),
            _ChipRow(
              label: 'care_main_diet'.tr(),
              items: careInfo.mainDiet,
            ),
            if (careInfo.supplement.isNotEmpty)
              _ChipRow(
                label: 'care_supplement'.tr(),
                items: careInfo.supplement,
              ),
            Text(
              'care_feeding_frequency'
                  .tr(namedArgs: {'frequency': careInfo.feedingFrequency}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(),
            _SectionHeader(title: 'care_mistakes_title'.tr()),
            const SizedBox(height: 8),
            ...careInfo.commonMistakes.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> items;

  const _ChipRow({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items
                .map((item) => Chip(
                      label: Text(item),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
