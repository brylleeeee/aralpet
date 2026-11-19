class Progress {
  final String userName;
  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int xpToday;
  final int dailyCap;
  final int streakDays;
  final int longestStreak;
  final int minutesToday;
  final int tasksDueToday;
  final String petName;
  final String petStage; // egg, hatchling, junior, adult, elder
  final String petMood; // happy, okay, sleepy
  final int? nextStageLevel; // null when the pet is at its last stage

  const Progress({
    required this.userName,
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    this.xpToday = 0,
    this.dailyCap = 300,
    required this.streakDays,
    this.longestStreak = 0,
    required this.minutesToday,
    required this.tasksDueToday,
    required this.petName,
    required this.petStage,
    required this.petMood,
    this.nextStageLevel,
  });

  // Turns the JSON from GET /api/v1/progress into a Dart object.
  factory Progress.fromJson(Map<String, dynamic> json) {
    int toInt(Object? value, [int fallback = 0]) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

    return Progress(
      userName: json['user_name']?.toString() ?? 'Student',
      level: toInt(json['level'], 1),
      totalXp: toInt(json['total_xp']),
      xpIntoLevel: toInt(json['xp_into_level']),
      xpForNextLevel: toInt(json['xp_for_next_level'], 100),
      xpToday: toInt(json['xp_today']),
      dailyCap: toInt(json['daily_cap'], 300),
      streakDays: toInt(json['streak_days']),
      longestStreak: toInt(json['longest_streak']),
      minutesToday: toInt(json['minutes_today']),
      tasksDueToday: toInt(json['tasks_due_today']),
      petName: json['pet_name']?.toString() ?? 'Aral',
      petStage: json['pet_stage']?.toString() ?? 'egg',
      petMood: json['pet_mood']?.toString() ?? 'okay',
      nextStageLevel:
          json['next_stage_level'] == null ? null : toInt(json['next_stage_level']),
    );
  }
}
