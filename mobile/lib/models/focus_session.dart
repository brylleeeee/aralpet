class FocusSession {
  final int id;
  final int? taskId;
  final String? taskTitle;
  final String status; // active, finished, cancelled
  final int plannedMinutes;
  final int? durationMinutes; // computed by the server
  final DateTime startedAt;
  final DateTime? endedAt;

  const FocusSession({
    required this.id,
    this.taskId,
    this.taskTitle,
    required this.status,
    required this.plannedMinutes,
    this.durationMinutes,
    required this.startedAt,
    this.endedAt,
  });

  bool get isActive => status == 'active';

  // When the countdown of an active session reaches zero.
  DateTime get endsAt => startedAt.add(Duration(minutes: plannedMinutes));

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: (json['id'] as num).toInt(),
      taskId: (json['task_id'] as num?)?.toInt(),
      taskTitle: json['task_title'] as String?,
      status: json['status'] as String? ?? 'active',
      plannedMinutes: (json['planned_minutes'] as num).toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      // Server times are UTC; convert to the phone's time.
      startedAt: DateTime.parse(json['started_at'].toString()).toLocal(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())?.toLocal()
          : null,
    );
  }
}

/// What PATCH /sessions/{id}/finish returns.
class SessionResult {
  final FocusSession session;
  final bool qualifies;
  final int xpAwarded;
  final bool capped;
  final bool leveledUp;
  final bool petEvolved;
  final List<String> newBadges; // badge names
  final int level;
  final String petStage;

  const SessionResult({
    required this.session,
    required this.qualifies,
    required this.xpAwarded,
    required this.capped,
    required this.leveledUp,
    required this.petEvolved,
    required this.newBadges,
    required this.level,
    required this.petStage,
  });

  factory SessionResult.fromJson(Map<String, dynamic> json) {
    final progress = Map<String, dynamic>.from(json['progress'] as Map? ?? {});
    final badges = json['new_badges'] as List? ?? const [];

    return SessionResult(
      session: FocusSession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      qualifies: json['qualifies'] as bool? ?? false,
      xpAwarded: (json['xp_awarded'] as num?)?.toInt() ?? 0,
      capped: json['capped'] as bool? ?? false,
      leveledUp: json['leveled_up'] as bool? ?? false,
      petEvolved: json['pet_evolved'] as bool? ?? false,
      newBadges: badges
          .whereType<Map>()
          .map((badge) => badge['name'].toString())
          .toList(),
      level: (progress['level'] as num?)?.toInt() ?? 1,
      petStage: progress['pet_stage']?.toString() ?? 'egg',
    );
  }
}
