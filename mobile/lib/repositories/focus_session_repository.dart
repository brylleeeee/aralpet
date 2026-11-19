import '../core/api_service.dart';
import '../models/focus_session.dart';

/// Thrown when the student already has a running session on the server.
class ActiveSessionExists implements Exception {
  ActiveSessionExists(this.session);

  final FocusSession session;
}

class FocusSessionRepository {
  FocusSessionRepository(this._api);

  final ApiService _api;

  // The running session, if any (e.g. after the app was closed).
  Future<FocusSession?> fetchActive() async {
    final response = await _api.get('/sessions', query: {'status': 'active'});
    final list = response is Map ? response['data'] : null;

    if (list is! List || list.isEmpty) return null;

    return FocusSession.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  // POST /sessions. The server records the start time.
  Future<FocusSession> start({required int plannedMinutes, int? taskId}) async {
    try {
      final response = await _api.post('/sessions', data: {
        'planned_minutes': plannedMinutes,
        'task_id': taskId,
      });

      return FocusSession.fromJson(
        Map<String, dynamic>.from((response as Map)['data'] as Map),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        final active = await fetchActive();
        if (active != null) throw ActiveSessionExists(active);
      }
      rethrow;
    }
  }

  // PATCH /sessions/{id}/finish. No duration is sent; the server computes it.
  Future<SessionResult> finish(int id) async {
    final response = await _api.patch('/sessions/$id/finish');

    if (response is! Map || response['data'] is! Map) {
      throw ApiException('Invalid session response from the server.');
    }

    return SessionResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // PATCH /sessions/{id}/cancel. Gives no XP.
  Future<void> cancel(int id) async {
    await _api.patch('/sessions/$id/cancel');
  }
}
