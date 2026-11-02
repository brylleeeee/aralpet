class PetInfo {
  final String name;
  final String stage; // egg, hatchling, junior, adult, elder
  final String mood; // happy, okay, sleepy
  final int level;
  final int? nextEvolutionLevel;
  final int? xpToNextEvolution;

  const PetInfo({
    required this.name,
    required this.stage,
    required this.mood,
    required this.level,
    this.nextEvolutionLevel,
    this.xpToNextEvolution,
  });

  factory PetInfo.fromJson(Map<String, dynamic> json) => PetInfo(
        name: json['name'] as String,
        stage: json['stage'] as String,
        mood: json['mood'] as String,
        level: json['level'] as int,
        nextEvolutionLevel: json['next_evolution_level'] as int?,
        xpToNextEvolution: json['xp_to_next_evolution'] as int?,
      );
}
