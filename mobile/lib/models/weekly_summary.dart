class SummaryDay {
  final DateTime date;
  final String day; // Mon, Tue, ...
  final int minutes;
  final int sessions;
  final int tasksCompleted;
  final int xp;

  const SummaryDay({
    required this.date,
    required this.day,
    required this.minutes,
    required this.sessions,
    required this.tasksCompleted,
    required this.xp,
  });

  factory SummaryDay.fromJson(Map<String, dynamic> json) => SummaryDay(
        date: DateTime.parse(json['date'] as String),
        day: json['day'] as String,
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        tasksCompleted: (json['tasks_completed'] as num?)?.toInt() ?? 0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
      );
}

class SummaryItem {
  final String title;
  final DateTime? at;
  final int? minutes;

  const SummaryItem({required this.title, this.at, this.minutes});
}

/// GET /api/v1/summary/weekly
class WeeklySummary {
  final DateTime startDate;
  final DateTime endDate;
  final List<SummaryDay> days;
  final int totalMinutes;
  final int totalSessions;
  final int totalTasks;
  final int totalXp;
  final List<SummaryItem> sessions;
  final List<SummaryItem> tasks;

  const WeeklySummary({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalMinutes,
    required this.totalSessions,
    required this.totalTasks,
    required this.totalXp,
    required this.sessions,
    required this.tasks,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? {});
    DateTime? time(Object? value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

    return WeeklySummary(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      days: (json['days'] as List? ?? const [])
          .map((d) => SummaryDay.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      totalMinutes: (totals['minutes'] as num?)?.toInt() ?? 0,
      totalSessions: (totals['sessions'] as num?)?.toInt() ?? 0,
      totalTasks: (totals['tasks_completed'] as num?)?.toInt() ?? 0,
      totalXp: (totals['xp'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as List? ?? const [])
          .whereType<Map>()
          .map((s) => SummaryItem(
                title: s['task_title']?.toString() ?? 'Free focus',
                at: time(s['started_at']),
                minutes: (s['duration_minutes'] as num?)?.toInt(),
              ))
          .toList(),
      tasks: (json['tasks'] as List? ?? const [])
          .whereType<Map>()
          .map((t) => SummaryItem(
                title: t['title']?.toString() ?? '',
                at: time(t['completed_at']),
              ))
          .toList(),
    );
  }
}
