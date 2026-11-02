class Subject {
  final int id;
  final String name;
  final String? color;

  const Subject({required this.id, required this.name, this.color});

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String?,
      );
}
