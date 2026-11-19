import '../core/api_service.dart';
import '../models/subject.dart';

class SubjectRepository {
  SubjectRepository(this._api);

  final ApiService _api;

  Subject _one(dynamic response) {
    if (response is! Map || response['data'] is! Map) {
      throw ApiException('Invalid subject response from the server.');
    }
    return Subject.fromJson(Map<String, dynamic>.from(response['data'] as Map));
  }

  // GET /subjects
  Future<List<Subject>> fetchSubjects() async {
    final response = await _api.get('/subjects');
    final list = response is Map ? response['data'] : null;
    if (list is! List) {
      throw ApiException('Invalid subject response from the server.');
    }
    return list
        .map((s) => Subject.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
  }

  // POST /subjects
  Future<Subject> createSubject({required String name, required String color}) async =>
      _one(await _api.post('/subjects', data: {'name': name, 'color': color}));

  // PUT /subjects/{id}
  Future<Subject> updateSubject(int id, {required String name, required String color}) async =>
      _one(await _api.put('/subjects/$id', data: {'name': name, 'color': color}));

  // DELETE /subjects/{id}  (its tasks are kept, without a subject)
  Future<void> deleteSubject(int id) async {
    await _api.delete('/subjects/$id');
  }
}
