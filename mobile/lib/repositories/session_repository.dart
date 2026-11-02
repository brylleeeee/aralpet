import '../core/api_service.dart';

class FocusSessionInfo {
  final int id;
  final String status;
  final int plannedMinutes;
  final DateTime startedAt;

  const FocusSessionInfo({
    required this.id,
    required this.status,
    required this.plannedMinutes,
    required this.startedAt,
  });

  factory FocusSessionInfo.fromJson(Map<String, dynamic> json) =>
      FocusSessionInfo(
        id: json['id'] as int,
        status: json['status'] as String,
        plannedMinutes: json['planned_minutes'] as int,
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      );
}

class SessionRepository {
  SessionRepository(this._api);

  final ApiService _api;

  // GET /sessions: newest first; used to resume an active session.
  Future<FocusSessionInfo?> fetchActive() async {
    final body = await _api.get('/sessions', query: {'page': 1});
    final list = (body['data'] as List).cast<Map<String, dynamic>>();
    for (final s in list) {
      if (s['status'] == 'active') return FocusSessionInfo.fromJson(s);
    }
    return null;
  }

  // POST /sessions
  Future<FocusSessionInfo> start(int plannedMinutes) async {
    final body =
        await _api.post('/sessions', data: {'planned_minutes': plannedMinutes});
    return FocusSessionInfo.fromJson(
        (body['data'] as Map).cast<String, dynamic>());
  }

  // PATCH /sessions/{id}/finish: the server decides the duration and XP.
  Future<Map<String, dynamic>> finish(int id) async {
    final body = await _api.patch('/sessions/$id/finish');
    return (body['data'] as Map).cast<String, dynamic>();
  }

  // PATCH /sessions/{id}/cancel
  Future<void> cancel(int id) => _api.patch('/sessions/$id/cancel');
}
