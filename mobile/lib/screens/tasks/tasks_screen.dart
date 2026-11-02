import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';
import '../../models/task.dart';
import '../../providers/pet_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/task_provider.dart';
import 'task_form.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Task? task}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskForm(task: task),
    );
    if (saved == true) {
      ref.invalidate(tasksProvider);
      ref.invalidate(progressProvider);
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, Task task) async {
    try {
      final result = await ref.read(taskRepositoryProvider).complete(task.id);
      ref.invalidate(tasksProvider);
      ref.invalidate(progressProvider);
      ref.invalidate(petProvider);
      if (context.mounted) {
        final xp = result['xp_awarded'];
        _snack(context,
            xp == 0 ? 'Task completed (daily XP cap reached)' : '+$xp XP');
      }
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(taskRepositoryProvider).delete(task.id);
      ref.invalidate(tasksProvider);
      ref.invalidate(progressProvider);
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Subjects',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => context.push('/subjects'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final f in TaskFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: f == filter,
                      onSelected: (_) =>
                          ref.read(taskFilterProvider.notifier).select(f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e is ApiException ? e.message : 'Something went wrong.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: () => ref.invalidate(tasksProvider),
                          child: const Text('Try again')),
                    ],
                  ),
                ),
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tasksProvider);
                  await ref.read(tasksProvider.future);
                },
                child: list.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No tasks here yet. Tap "Add task".')),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final t = list[i];
                          return _TaskTile(
                            task: t,
                            onToggle: () => _complete(context, ref, t),
                            onEdit: () => _openForm(context, ref, task: t),
                            onDelete: () => _delete(context, ref, t),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (task.subjectName != null) task.subjectName!,
      if (task.dueDate != null) 'Due ${formatDate(task.dueDate!)}',
      '${task.priority[0].toUpperCase()}${task.priority.substring(1)} priority',
    ];
    final now = DateTime.now();
    final overdue = !task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime(now.year, now.month, now.day));

    return ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: task.isCompleted ? null : (_) => onToggle(),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(parts.join(' · '),
          style: TextStyle(color: overdue ? scheme.error : null)),
      onTap: task.isCompleted ? null : onEdit,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => [
          if (!task.isCompleted)
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
