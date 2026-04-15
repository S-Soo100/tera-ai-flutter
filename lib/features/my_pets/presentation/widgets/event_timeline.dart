import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/pet_event.dart';
import '../my_pets_providers.dart';

class EventTimeline extends ConsumerWidget {
  final String petId;

  const EventTimeline({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(petEventsProvider(petId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('event_timeline'.tr(), style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'event_add'.tr(),
                  onPressed: () => _showAddEventSheet(context, ref),
                ),
              ],
            ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'event_empty'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._buildGroupedEvents(context, events, colorScheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedEvents(
    BuildContext context,
    List<PetEvent> events,
    ColorScheme colorScheme,
  ) {
    final grouped = <String, List<PetEvent>>{};
    final dateFormat = DateFormat('yyyy.MM.dd');

    for (final event in events) {
      final key = dateFormat.format(event.eventDate);
      grouped.putIfAbsent(key, () => []).add(event);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            entry.key,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
      for (final event in entry.value) {
        widgets.add(_EventTile(event: event, petId: petId));
      }
    }
    return widgets;
  }

  void _showAddEventSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddEventSheet(petId: petId),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final PetEvent event;
  final String petId;

  const _EventTile({required this.event, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = PetEventType.color(event.type, colorScheme);
    final timeFormat = DateFormat('HH:mm');

    final parts = <String>[timeFormat.format(event.eventDate)];
    if (event.type == PetEventType.weight && event.value != null) {
      parts.add('${event.value}g');
    }
    if (event.title != null && event.title!.isNotEmpty) {
      parts.add(event.title!);
    }
    if (event.note != null && event.note!.isNotEmpty) {
      parts.add(event.note!);
    }
    final subtitle = parts.join('  ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(PetEventType.icon(event.type), color: typeColor),
      title: Text(PetEventType.label(event.type)),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () async {
          await ref.read(petEventsProvider(petId).notifier).delete(event.id);
        },
      ),
    );
  }
}

class AddEventSheet extends ConsumerStatefulWidget {
  final String petId;

  const AddEventSheet({super.key, required this.petId});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  String _selectedType = PetEventType.feeding;
  final _valueController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _eventDate = DateTime.now();

  @override
  void dispose() {
    _valueController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    double? value;
    if (_selectedType == PetEventType.weight) {
      value = double.tryParse(_valueController.text.trim());
      if (value == null || value <= 0) return;
    }

    final event = PetEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      petId: widget.petId,
      type: _selectedType,
      value: value,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      eventDate: _eventDate,
    );

    await ref.read(petEventsProvider(widget.petId).notifier).add(event);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('event_add'.tr(), style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          // 타입 선택 칩
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: PetEventType.all.map((type) {
              final selected = _selectedType == type;
              return ChoiceChip(
                label: Text(PetEventType.label(type)),
                avatar: Icon(PetEventType.icon(type), size: 18),
                selected: selected,
                onSelected: (_) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 체중 입력 (weight 타입일 때만)
          if (_selectedType == PetEventType.weight)
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'pet_weight'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),

          // 제목 입력 (feeding, health_check, note)
          if (_selectedType != PetEventType.weight &&
              _selectedType != PetEventType.shedding) ...[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'event_title'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 메모
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'event_note'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 날짜 선택
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _eventDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() => _eventDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _eventDate.hour,
                      _eventDate.minute,
                    ));
              }
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(DateFormat('yyyy.MM.dd').format(_eventDate)),
          ),
          const SizedBox(height: 16),

          // 저장
          FilledButton(
            onPressed: _save,
            child: Text('pet_save'.tr()),
          ),
        ],
      ),
    );
  }
}
