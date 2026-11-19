import '../core/api_service.dart';
import '../models/progress.dart';

class ProgressRepository {
  ProgressRepository(this._api);

  final ApiService _api;

  // GET /api/v1/progress
  Future<Progress> fetchProgress() async {
    final response = await _api.get('/progress');

    if (response is! Map) {
      throw ApiException('Invalid progress response from the server.');
    }

    return Progress.fromJson(Map<String, dynamic>.from(response));
  }
}
