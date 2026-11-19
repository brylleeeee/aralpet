class PetStage {
  final String stage; // egg, hatchling, junior, adult, elder
  final int minLevel;
  final bool reached;

  const PetStage({required this.stage, required this.minLevel, required this.reached});

  factory PetStage.fromJson(Map<String, dynamic> json) => PetStage(
        stage: json['stage'] as String,
        minLevel: (json['min_level'] as num).toInt(),
        reached: json['reached'] as bool? ?? false,
      );
}

/// GET /api/v1/pet
class PetInfo {
  final String name;
  final String stage;
  final String mood;
  final int level;
  final String? nextStage;
  final int? nextStageLevel;
  final List<PetStage> stages;

  const PetInfo({
    required this.name,
    required this.stage,
    required this.mood,
    required this.level,
    this.nextStage,
    this.nextStageLevel,
    required this.stages,
  });

  factory PetInfo.fromJson(Map<String, dynamic> json) => PetInfo(
        name: json['name'] as String? ?? 'Aral',
        stage: json['stage'] as String? ?? 'egg',
        mood: json['mood'] as String? ?? 'okay',
        level: (json['level'] as num?)?.toInt() ?? 1,
        nextStage: json['next_stage'] as String?,
        nextStageLevel: (json['next_stage_level'] as num?)?.toInt(),
        stages: (json['stages'] as List? ?? const [])
            .map((s) => PetStage.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

/// "hatchling" -> "Hatchling"
String stageLabel(String stage) =>
    stage.isEmpty ? stage : stage[0].toUpperCase() + stage.substring(1);
