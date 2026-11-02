import '../core/api_service.dart';
import '../models/subject.dart';
import '../models/task.dart';

class TaskRepository {
  TaskRepository(this._api);

  final ApiService _api;

  List<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : body;
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  // GET /tasks?due=today|week|overdue&page=N (follows the pages)
  Future<List<Task>> fetchTasks({String? due}) async {
    final tasks = <Task>[];
    var page = 1;
    var lastPage = 1;
    do {
      final body = await _api.get('/tasks', query: {
        if (due != null) 'due': due,
        'page': page,
      });
      tasks.addAll(_list(body).map(Task.fromJson));
      final meta = body is Map ? body['meta'] : null;
      lastPage = meta is Map ? (meta['last_page'] as int? ?? 1) : 1;
      page++;
    } while (page <= lastPage && page <= 10);
    return tasks;
  }

  // GET /subjects
  Future<List<Subject>> fetchSubjects() async {
    final body = await _api.get('/subjects');
    return _list(body).map(Subject.fromJson).toList();
  }

  // POST /subjects
  Future<void> createSubject({required String name, required String color}) =>
      _api.post('/subjects', data: {'name': name, 'color': color});

  // PUT /subjects/{id}
  Future<void> updateSubject(int id,
          {required String name, required String color}) =>
      _api.put('/subjects/$id', data: {'name': name, 'color': color});

  // DELETE /subjects/{id}: its tasks stay, just without a subject
  Future<void> deleteSubject(int id) => _api.delete('/subjects/$id');

  Map<String, dynamic> _payload({
    required String title,
    String? notes,
    DateTime? dueDate,
    required String priority,
    int? subjectId,
  }) =>
      {
        'title': title,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'due_date': dueDate == null ? null : formatDate(dueDate),
        'priority': priority,
        'subject_id': subjectId,
      };

  // POST /tasks
  Future<void> create({
    required String title,
    String? notes,
    DateTime? dueDate,
    required String priority,
    int? subjectId,
  }) =>
      _api.post('/tasks',
          data: _payload(
              title: title,
              notes: notes,
              dueDate: dueDate,
              priority: priority,
              subjectId: subjectId));

  // PUT /tasks/{id}
  Future<void> update(
    int id, {
    required String title,
    String? notes,
    DateTime? dueDate,
    required String priority,
    int? subjectId,
  }) =>
      _api.put('/tasks/$id',
          data: _payload(
              title: title,
              notes: notes,
              dueDate: dueDate,
              priority: priority,
              subjectId: subjectId));

  // DELETE /tasks/{id}
  Future<void> delete(int id) => _api.delete('/tasks/$id');

  // PATCH /tasks/{id}/complete: returns the XP result from the server
  Future<Map<String, dynamic>> complete(int id) async {
    final body = await _api.patch('/tasks/$id/complete');
    return (body['data'] as Map).cast<String, dynamic>();
  }
}
