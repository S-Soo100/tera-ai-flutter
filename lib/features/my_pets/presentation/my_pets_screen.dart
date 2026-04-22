import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';

class MyPetsScreen extends ConsumerWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 개체'),
      ),
      body: pets.isEmpty ? _buildEmptyState(context) : _buildList(context, pets),
      floatingActionButton: pets.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'my_pets_add_fab',
              onPressed: () => context.push('/my-pets/add'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 72, height: 72),
            const SizedBox(height: 16),
            Text(
              '아직 등록된 개체가 없어요',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '개체를 등록하고 맞춤 사육 가이드를 받아보세요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/my-pets/add'),
              icon: const Icon(Icons.add),
              label: const Text('개체 등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Pet> pets) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final pet = pets[index];
        return _PetCard(pet: pet);
      },
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;

  const _PetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/my-pets/${pet.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo or icon
              _buildAvatar(context),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pet.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pet.sexIcon,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: pet.sex == 'male'
                                    ? Colors.blue
                                    : pet.sex == 'female'
                                        ? Colors.pink
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        pet.speciesName,
                        if (pet.morph != null && pet.morph!.isNotEmpty) pet.morph,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (pet.adoptionDuration.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        pet.adoptionDuration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (pet.photoPath != null && pet.photoPath!.isNotEmpty) {
      final isNetwork = pet.photoPath!.startsWith('http');
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: pet.photoPath!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 56,
                  height: 56,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                errorWidget: (_, __, ___) => _buildIconAvatar(context),
              )
            : Image.file(
                File(pet.photoPath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildIconAvatar(context),
              ),
      );
    }
    return _buildIconAvatar(context);
  }

  Widget _buildIconAvatar(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/logo.png', width: 56, height: 56),
      ),
    );
  }
}
