
import '../core/api_service.dart';
import '../models/task.dart';

// Result returned by Laravel after completing a task.
class TaskCompletionResult {
  const TaskCompletionResult({
    required this.xpEarned,
    required this.alreadyCompleted,
  });

  final int xpEarned;
  final bool alreadyCompleted;
}

class TaskRepository {
  TaskRepository(this._api);

  final ApiService _api;

  // Retrieve tasks with optional filters.
  Future<List<Task>> fetchTasks({
    String? status,
    int? subjectId,
    String? due,
  }) async {
    final query = <String, dynamic>{};

    if (status != null && status != 'all') {
      query['status'] = status;
    }

    if (subjectId != null) {
      query['subject_id'] = subjectId;
    }

    if (due != null && due != 'all') {
      query['due'] = due;
    }

    // The API sends 15 tasks per page; load every page.
    final tasks = <Task>[];
    var page = 1;
    var lastPage = 1;

    do {
      final response = await _api.get(
        '/tasks',
        query: {...query, 'page': page},
      );

      if (response is! Map || response['data'] is! List) {
        throw ApiException(
          'Invalid task response from the server.',
        );
      }

      tasks.addAll(
        (response['data'] as List).map(
          (item) => Task.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      final meta = response['meta'];
      lastPage = meta is Map && meta['last_page'] is num
          ? (meta['last_page'] as num).toInt()
          : page;
      page++;
    } while (page <= lastPage && page <= 50);

    return tasks;
  }

  // Create a new task.
  Future<Task> createTask({
    required String title,
    String? notes,
    DateTime? dueDate,
    String priority = 'medium',
    int? subjectId,
  }) async {
    final response = await _api.post(
      '/tasks',
      data: {
        'title': title,
        'notes': notes,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'priority': priority,
        'subject_id': subjectId,
      },
    );

    if (response is! Map || response['data'] is! Map) {
      throw ApiException(
        'Invalid task response from the server.',
      );
    }

    return Task.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // Update an existing task.
  Future<Task> updateTask({
    required int id,
    required String title,
    String? notes,
    DateTime? dueDate,
    String priority = 'medium',
    int? subjectId,
  }) async {
    final response = await _api.put(
      '/tasks/$id',
      data: {
        'title': title,
        'notes': notes,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'priority': priority,
        'subject_id': subjectId,
      },
    );

    if (response is! Map || response['data'] is! Map) {
      throw ApiException(
        'Invalid task response from the server.',
      );
    }

    return Task.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // Delete an existing task.
  Future<void> deleteTask(int id) async {
    await _api.delete('/tasks/$id');
  }

  // Complete a task and receive the XP awarded by Laravel.
  Future<TaskCompletionResult> completeTask(int id) async {
    final response = await _api.post(
      '/tasks/$id/complete',
    );

    if (response is! Map ||
        response['xp_earned'] is! num ||
        response['already_completed'] is! bool) {
      throw ApiException(
        'Invalid completion response from the server.',
      );
    }

    return TaskCompletionResult(
      xpEarned: (response['xp_earned'] as num).toInt(),
      alreadyCompleted:
          response['already_completed'] as bool,
    );
  }
}
