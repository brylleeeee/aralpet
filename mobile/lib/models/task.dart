String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Task {
  final int id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final String priority; // low, medium, high
  final String status; // pending, completed
  final int? subjectId;
  final String? subjectName;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.priority,
    required this.status,
    this.subjectId,
    this.subjectName,
  });

  bool get isCompleted => status == 'completed';

  factory Task.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    final due = json['due_date']?.toString();
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      // Keep only the date part so time zones can never shift the day.
      dueDate: (due != null && due.length >= 10)
          ? DateTime.tryParse(due.substring(0, 10))
          : null,
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'pending',
      subjectId: json['subject_id'] as int?,
      subjectName: subject is Map
          ? subject['name'] as String?
          : json['subject_name'] as String?,
    );
  }
}
