import '../core/api_service.dart';
import '../models/progress.dart';

class ProgressRepository {
  ProgressRepository(this._api);

  final ApiService _api;

  // GET /progress
  Future<Progress> fetchProgress() async {
    final body = await _api.get('/progress');
    return Progress.fromJson((body['data'] as Map).cast<String, dynamic>());
  }
}
