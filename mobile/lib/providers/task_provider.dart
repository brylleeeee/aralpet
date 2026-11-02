import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'auth_provider.dart';

final taskRepositoryProvider =
    Provider((ref) => TaskRepository(ref.watch(apiServiceProvider)));

enum TaskFilter {
  all('All', null),
  today('Today', 'today'),
  week('This week', 'week'),
  overdue('Overdue', 'overdue');

  const TaskFilter(this.label, this.query);
  final String label;
  final String? query; // value of the ?due= parameter
}

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void select(TaskFilter filter) => state = filter;
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

final tasksProvider = FutureProvider<List<Task>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  return ref.watch(taskRepositoryProvider).fetchTasks(due: filter.query);
});

final subjectsProvider = FutureProvider<List<Subject>>((ref) {
  return ref.watch(taskRepositoryProvider).fetchSubjects();
});
