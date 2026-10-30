import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/pet_view.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/xp_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your progress.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(progressProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(progressProvider.future),
          child: _DashboardContent(progress: p),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hi, ${progress.userName}!',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: StreakChip(days: progress.streakDays),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: XpBar(
              level: progress.level,
              current: progress.xpIntoLevel,
              target: progress.xpForNextLevel,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/pet'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PetView(
                    stage: progress.petStage,
                    mood: progress.petMood,
                    size: 56,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(progress.petName,
                            style: text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Stage: ${progress.petStage}'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timer,
                label: 'Focus today',
                value: '${progress.minutesToday} min',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_box,
                label: 'Tasks due today',
                value: '${progress.tasksDueToday}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/focus'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start a focus session'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}