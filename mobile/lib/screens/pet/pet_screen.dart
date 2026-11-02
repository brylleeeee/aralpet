import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../providers/progress_provider.dart';

class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  static const _emoji = {
    'egg': '🥚',
    'hatchling': '🐣',
    'junior': '🐥',
    'adult': '🐔',
    'elder': '🦚',
  };

  static const _moodText = {
    'happy': 'Happy: you studied today!',
    'okay': 'Okay: you studied yesterday.',
    'sleepy': 'Sleepy: study to wake me up.',
  };

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, PetInfo pet) async {
    final controller = TextEditingController(text: pet.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename your pet'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == pet.name) return;
    try {
      await ref.read(petRepositoryProvider).rename(name);
      ref.invalidate(petProvider);
      ref.invalidate(progressProvider);
      if (context.mounted) _snack(context, 'Renamed to $name');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Rename failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Pet')),
      body: pet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is ApiException ? e.message : 'Something went wrong.'),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(petProvider),
                  child: const Text('Try again')),
            ],
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(petProvider);
            await ref.read(petProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(_emoji[p.stage] ?? '🥚',
                      style: const TextStyle(fontSize: 80)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _rename(context, ref, p),
                  ),
                ],
              ),
              Center(
                child: Text(
                  '${p.stage[0].toUpperCase()}${p.stage.substring(1)} · Level ${p.level}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(_moodText[p.mood] ?? p.mood)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    p.nextEvolutionLevel == null
                        ? 'Your pet is fully grown!'
                        : 'Evolves at level ${p.nextEvolutionLevel}: '
                            '${p.xpToNextEvolution} XP to go.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
