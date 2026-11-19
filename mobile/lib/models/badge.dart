/// One item of GET /api/v1/badges (named StudyBadge so it does not clash
/// with Flutter's Badge widget)
class StudyBadge {
  final int id;
  final String code;
  final String name;
  final String description;
  final String conditionType; // streak, level, tasks_completed, ...
  final int threshold;
  final int current; // the student's progress toward the threshold
  final bool earned;
  final DateTime? awardedAt;

  const StudyBadge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.conditionType,
    required this.threshold,
    required this.current,
    required this.earned,
    this.awardedAt,
  });

  double get fraction =>
      threshold <= 0 ? 1 : (current / threshold).clamp(0.0, 1.0).toDouble();

  factory StudyBadge.fromJson(Map<String, dynamic> json) => StudyBadge(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        conditionType: json['condition_type'] as String? ?? '',
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        current: (json['current'] as num?)?.toInt() ?? 0,
        earned: json['earned'] as bool? ?? false,
        awardedAt: json['awarded_at'] != null
            ? DateTime.tryParse(json['awarded_at'].toString())?.toLocal()
            : null,
      );
}
