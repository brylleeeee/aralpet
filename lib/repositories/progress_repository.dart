import '../models/progress.dart';

class ProgressRepository {
  // MOCK: later this will call GET /api/v1/progress through the API service.
  Future<Progress> fetchProgress() async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Sample JSON shaped like what the API will send back.
    final json = <String, dynamic>{
      'user_name': 'Student',
      'level': 3,
      'total_xp': 260,
      'xp_into_level': 60,
      'xp_for_next_level': 150,
      'streak_days': 4,
      'minutes_today': 35,
      'tasks_due_today': 2,
      'pet_name': 'Mochi',
      'pet_stage': 'baby',
      'pet_mood': 'happy',
    };
    return Progress.fromJson(json);
  }
}