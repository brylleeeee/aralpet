int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

/// A row of GET /admin/users
class AdminUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? course;
  final int? yearLevel;
  final bool isActive;
  final int level;
  final int totalXp;
  final int streakDays;
  final String? lastActiveOn;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.course,
    this.yearLevel,
    required this.isActive,
    required this.level,
    required this.totalXp,
    required this.streakDays,
    this.lastActiveOn,
  });

  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? 'student',
        course: json['course'] as String?,
        yearLevel: json['year_level'] == null ? null : _int(json['year_level']),
        isActive: json['is_active'] as bool? ?? true,
        level: _int(json['level'], 1),
        totalXp: _int(json['total_xp']),
        streakDays: _int(json['streak_days']),
        lastActiveOn: json['last_active_on'] as String?,
      );
}

class AdminUserPage {
  final List<AdminUser> users;
  final int currentPage;
  final int lastPage;
  final int total;

  const AdminUserPage({
    required this.users,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

/// GET /admin/reports
class AdminReport {
  final String period; // week or month
  final DateTime startDate;
  final DateTime endDate;
  final int totalStudents;
  final int newStudents;
  final int activeStudents;
  final int sessions;
  final int totalMinutes;
  final int tasksCompleted;
  final int xpAwarded;
  final int badgesAwarded;
  final List<MapEntry<String, int>> badges; // badge name -> times awarded

  const AdminReport({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalStudents,
    required this.newStudents,
    required this.activeStudents,
    required this.sessions,
    required this.totalMinutes,
    required this.tasksCompleted,
    required this.xpAwarded,
    required this.badgesAwarded,
    required this.badges,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
        period: json['period']?.toString() ?? 'week',
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        totalStudents: _int(json['total_students']),
        newStudents: _int(json['new_students']),
        activeStudents: _int(json['active_students']),
        sessions: _int(json['sessions']),
        totalMinutes: _int(json['total_minutes']),
        tasksCompleted: _int(json['tasks_completed']),
        xpAwarded: _int(json['xp_awarded']),
        badgesAwarded: _int(json['badges_awarded']),
        badges: (json['badges'] as List? ?? const [])
            .whereType<Map>()
            .map((b) => MapEntry(b['name'].toString(), _int(b['count'])))
            .toList(),
      );
}

/// A row of GET /admin/badges
class AdminBadge {
  final int id;
  final String code;
  final String name;
  final String description;
  final String conditionType;
  final int threshold;
  final bool isActive;
  final int awardedCount;

  const AdminBadge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.conditionType,
    required this.threshold,
    required this.isActive,
    required this.awardedCount,
  });

  factory AdminBadge.fromJson(Map<String, dynamic> json) => AdminBadge(
        id: _int(json['id']),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        conditionType: json['condition_type']?.toString() ?? '',
        threshold: _int(json['threshold'], 1),
        isActive: json['is_active'] as bool? ?? true,
        awardedCount: _int(json['awarded_count']),
      );

  Map<String, dynamic> toJson({bool? active}) => {
        'code': code,
        'name': name,
        'description': description,
        'condition_type': conditionType,
        'threshold': threshold,
        'is_active': active ?? isActive,
      };
}

/// A row of GET /admin/settings
class XpRule {
  final String key;
  final String label;
  final int value;
  final int min;
  final int max;

  const XpRule({
    required this.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
  });

  factory XpRule.fromJson(Map<String, dynamic> json) => XpRule(
        key: json['key'].toString(),
        label: json['label']?.toString() ?? json['key'].toString(),
        value: _int(json['value']),
        min: _int(json['min']),
        max: _int(json['max'], 100000),
      );
}

/// Readable names for badge condition types.
const conditionLabels = {
  'sessions_completed': 'Focus sessions completed',
  'streak': 'Day streak',
  'tasks_completed': 'Tasks completed',
  'focus_minutes': 'Focus minutes',
  'level': 'Level reached',
};
