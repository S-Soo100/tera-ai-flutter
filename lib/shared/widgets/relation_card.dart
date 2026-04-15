import 'package:flutter/material.dart';
import '../../features/wiki/domain/graph_entity.dart';

class RelationCard extends StatelessWidget {
  final GraphRelation relation;
  final GraphEntity target;
  final VoidCallback? onTap;

  const RelationCard({
    super.key,
    required this.relation,
    required this.target,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(_iconFor(target.kind), size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relation.type.label,
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(EntityKind kind) {
    switch (kind) {
      case EntityKind.species:
        return Icons.pets;
      case EntityKind.envCond:
        return Icons.thermostat;
      case EntityKind.disease:
        return Icons.medical_services_outlined;
      case EntityKind.food:
        return Icons.restaurant;
      case EntityKind.equipment:
        return Icons.inventory_2_outlined;
      case EntityKind.unknown:
        return Icons.help_outline;
    }
  }
}
