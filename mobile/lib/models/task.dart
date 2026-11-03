
class Task {
  final int id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final DateTime? completedAt;
  final int? subjectId;
  final String? subjectName;
  final DateTime? createdAt;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.priority,
    required this.status,
    this.completedAt,
    this.subjectId,
    this.subjectName,
    this.createdAt,
  });

  bool get isCompleted => status == 'completed';

  factory Task.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];

    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'pending',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      subjectId: json['subject_id'] as int?,
      subjectName: subject is Map && subject['name'] != null
          ? subject['name'].toString()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
