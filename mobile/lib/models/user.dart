class User {
  final int id;
  final String name;
  final String email;
  final String role; // student or admin
  final String? course;
  final int? yearLevel;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.course,
    this.yearLevel,
    required this.isActive,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'student',
      course: json['course'] as String?,
      yearLevel: json['year_level'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}