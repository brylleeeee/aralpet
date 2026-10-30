class Progress {
  final String userName;
  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int streakDays;
  final int minutesToday;
  final int tasksDueToday;
  final String petName;
  final String petStage; // egg, baby, teen, adult
  final String petMood; // happy, okay, sad

  const Progress({
    required this.userName,
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.streakDays,
    required this.minutesToday,
    required this.tasksDueToday,
    required this.petName,
    required this.petStage,
    required this.petMood,
  });

  // Turns the JSON from the API into a Dart object.
  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      userName: json['user_name'] as String,
      level: json['level'] as int,
      totalXp: json['total_xp'] as int,
      xpIntoLevel: json['xp_into_level'] as int,
      xpForNextLevel: json['xp_for_next_level'] as int,
      streakDays: json['streak_days'] as int,
      minutesToday: json['minutes_today'] as int,
      tasksDueToday: json['tasks_due_today'] as int,
      petName: json['pet_name'] as String,
      petStage: json['pet_stage'] as String,
      petMood: json['pet_mood'] as String,
    );
  }
}