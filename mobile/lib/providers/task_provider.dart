import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'auth_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiServiceProvider));
});

final taskProvider = FutureProvider<List<Task>>((ref) {
  // Reload when a different account logs in.
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(taskRepositoryProvider).fetchTasks();
});