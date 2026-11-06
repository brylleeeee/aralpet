
import '../core/api_service.dart';
import '../core/token_storage.dart';
import '../models/progress.dart';

class ProgressRepository {
  ProgressRepository()
      : _api = ApiService(TokenStorage());

  final ApiService _api;

  // GET /api/v1/progress
  // Fetch actual student progress from Laravel.
  Future<Progress> fetchProgress() async {
    final response = await _api.get('/progress');

    // Validate Laravel's JSON response.
    if (response is! Map) {
      throw const FormatException(
        'Invalid progress response from server.',
      );
    }

    final json = Map<String, dynamic>.from(response);

    // Convert real Laravel data into the Flutter model.
    return Progress.fromJson(json);
  }
}
